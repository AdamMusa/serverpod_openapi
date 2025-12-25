import 'dart:convert';
import 'package:serverpod/serverpod.dart';
import '../../openapi/openapi_generator.dart';

/// Web route that serves the OpenAPI specification
class RouteOpenApi extends WidgetRoute {
  final Serverpod pod;
  final String title;
  final String version;
  final String? description;

  RouteOpenApi(
    this.pod, {
    this.title = 'API Documentation',
    this.version = '1.0.0',
    this.description,
  });

  @override
  Future<WebWidget> build(Session session, Request request) async {
    final format = request.url.queryParameters['format'];
    // Serverpod API server runs on port 8080 (different from web server on 8082)
    final apiServerUrl = '${request.url.scheme}://${request.url.host}:8080';

    final generator = OpenApiGenerator(
      pod: pod,
      title: title,
      version: version,
      serverUrl: apiServerUrl, // Use API server URL for actual calls
      description: description,
    );

    // Serve raw JSON or YAML if format is specified
    if (format == 'yaml') {
      return _OpenApiYamlWidget(generator.toYaml());
    } else if (format == 'json') {
      return _OpenApiJsonWidget(generator.toJson(pretty: true));
    }

    // Default: serve Swagger UI with embedded spec
    return _SwaggerUIWidget(generator.toJson(pretty: false));
  }
}

class _OpenApiJsonWidget extends WebWidget {
  final String jsonContent;

  _OpenApiJsonWidget(this.jsonContent);

  @override
  String toString() => toHtml();

  String toHtml() {
    return '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenAPI Specification - JSON</title>
    <style>
      body {
        margin: 0;
        padding: 20px;
        background: #1e1e1e;
        color: #d4d4d4;
        font-family: 'Courier New', monospace;
        font-size: 14px;
      }
      pre {
        background: #252526;
        padding: 20px;
        border-radius: 4px;
        overflow-x: auto;
        white-space: pre-wrap;
        word-wrap: break-word;
      }
    </style>
  </head>
  <body>
    <pre>${_escapeHtml(jsonContent)}</pre>
  </body>
</html>
''';
  }

  String _escapeHtml(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

class _SwaggerUIWidget extends WebWidget {
  final String jsonSpec;

  _SwaggerUIWidget(this.jsonSpec);

  @override
  String toString() => toHtml();

  String toHtml() {
    // Use base64 encoding to safely embed JSON in HTML
    // This avoids all escaping issues
    final base64Spec = base64Encode(utf8.encode(jsonSpec));
    final escapedBase64 = base64Spec.replaceAll("'", "\\'");

    return '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API Documentation - Swagger UI</title>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui.css" />
    <style>
      html {
        box-sizing: border-box;
        overflow: -moz-scrollbars-vertical;
        overflow-y: scroll;
      }
      *, *:before, *:after {
        box-sizing: inherit;
      }
      body {
        margin:0;
        background: #fafafa;
      }
    </style>
  </head>
  <body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-standalone-preset.js"></script>
    <script>
      window.onload = function() {
        // Decode base64 encoded JSON spec
        let spec;
        try {
          const base64Spec = '${escapedBase64}';
          const jsonString = atob(base64Spec);
          spec = JSON.parse(jsonString);
        } catch (e) {
          console.error('Failed to parse OpenAPI spec:', e);
          document.getElementById('swagger-ui').innerHTML = '<div style="padding: 20px; color: red;">Error loading API specification: ' + e.message + '</div>';
          return;
        }
        
        // Spec is already in the correct format with semantic HTTP methods
        // Paths are /endpointName/methodName with GET, POST, PATCH, DELETE
        const ui = SwaggerUIBundle({
          spec: spec,
          dom_id: '#swagger-ui',
          deepLinking: true,
          presets: [
            SwaggerUIBundle.presets.apis,
            SwaggerUIStandalonePreset
          ],
          plugins: [
            SwaggerUIBundle.plugins.DownloadUrl
          ],
          layout: "StandaloneLayout",
          tryItOutEnabled: true,
          requestInterceptor: function(request) {
            // Transform Swagger UI request to match Serverpod's actual structure
            // Serverpod always uses POST /endpointName with {"method": "methodName", ...params} in body
            // So we need to:
            // 1. Change /endpointName/methodName to /endpointName
            // 2. Always use POST method (Serverpod requirement)
            // 3. Ensure method is in request body
            if (request.url) {
              const urlMatch = request.url.match(/\\/([^\\/]+)\\/([^\\/]+)\$/);
              if (urlMatch) {
                const endpointName = urlMatch[1];
                const methodName = urlMatch[2];
                const originalMethod = request.method || 'GET';
                
                // Transform URL: remove method name from path
                request.url = request.url.replace('/' + methodName, '');
                
                // Always use POST method (Serverpod requirement)
                request.method = 'POST';
                
                // Handle request body
                let bodyObj = {};
                
                // If there's an existing body, parse it
                if (request.body) {
                  try {
                    bodyObj = typeof request.body === 'string' ? JSON.parse(request.body) : request.body;
                  } catch (e) {
                    // If parsing fails, start with empty object
                    bodyObj = {};
                  }
                }
                
                // For GET/HEAD requests, parameters might be in query string
                // We need to move them to the body
                if ((originalMethod === 'GET' || originalMethod === 'HEAD') && request.url.includes('?')) {
                  try {
                    const urlObj = new URL(request.url);
                    urlObj.searchParams.forEach((value, key) => {
                      // Try to parse as number or boolean, otherwise keep as string
                      if (value === 'true' || value === 'false') {
                        bodyObj[key] = value === 'true';
                      } else if (!isNaN(value) && value !== '') {
                        bodyObj[key] = Number(value);
                      } else {
                        bodyObj[key] = value;
                      }
                    });
                    // Remove query string from URL
                    request.url = request.url.split('?')[0];
                  } catch (e) {
                    // If URL parsing fails, just remove query string
                    request.url = request.url.split('?')[0];
                  }
                }
                
                // Always ensure method is in body
                bodyObj.method = methodName;
                
                // Set the body
                request.body = JSON.stringify(bodyObj);
                
                // Ensure Content-Type is set
                if (!request.headers) {
                  request.headers = {};
                }
                request.headers['Content-Type'] = 'application/json';
              }
            }
            return request;
          }
        });
      };
    </script>
  </body>
</html>
''';
  }
}

class _OpenApiYamlWidget extends WebWidget {
  final String yamlContent;

  _OpenApiYamlWidget(this.yamlContent);

  @override
  String toString() => toHtml();

  String toHtml() {
    return '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenAPI Specification - YAML</title>
    <style>
      body {
        margin: 0;
        padding: 20px;
        background: #1e1e1e;
        color: #d4d4d4;
        font-family: 'Courier New', monospace;
        font-size: 14px;
      }
      pre {
        background: #252526;
        padding: 20px;
        border-radius: 4px;
        overflow-x: auto;
        white-space: pre-wrap;
        word-wrap: break-word;
      }
    </style>
  </head>
  <body>
    <pre>${_escapeHtml(yamlContent)}</pre>
  </body>
</html>
''';
  }

  String _escapeHtml(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
