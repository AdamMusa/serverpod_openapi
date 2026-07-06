import 'dart:async';
import 'dart:convert';
import 'package:serverpod/serverpod.dart';
import '../../openapi/openapi_annotations.dart';
import '../../openapi/openapi_generator.dart';

/// Web route that serves the OpenAPI specification
class RouteOpenApi extends WidgetRoute {
  final Serverpod pod;
  final String title;
  final String version;
  final String? description;
  final Map<String, OpenApiMethod> operationMetadata;

  RouteOpenApi(
    this.pod, {
    this.title = 'API Documentation',
    this.version = '1.0.0',
    this.description,
    this.operationMetadata = const {},
  });

  @override
  Future<WebWidget> build(Session session, Request request) async {
    final generator = _createGenerator();

    // Default: serve Swagger UI with embedded spec
    return _SwaggerUIWidget(generator.toJson(pretty: false));
  }

  @override
  FutureOr<Result> handleCall(Session session, Request req) async {
    final format = req.url.queryParameters['format'];
    final generator = _createGenerator();

    if (format == 'json') {
      return _rawResponse(
        generator.toJson(pretty: true),
        mimeType: MimeType.json,
      );
    } else if (format == 'yaml') {
      return _rawResponse(
        generator.toYaml(),
        mimeType: const MimeType('text', 'yaml'),
      );
    }

    return super.handleCall(session, req);
  }

  OpenApiGenerator _createGenerator() {
    final apiServerUrl = _publicApiServerUrl();

    return OpenApiGenerator(
      pod: pod,
      title: title,
      version: version,
      serverUrl: apiServerUrl, // Use API server URL for actual calls
      description: description,
      operationMetadata: operationMetadata,
    );
  }

  String _publicApiServerUrl() {
    final apiServer = pod.config.apiServer;
    return Uri(
      scheme: apiServer.publicScheme,
      host: apiServer.publicHost,
      port: _isDefaultPort(
        apiServer.publicScheme,
        apiServer.publicPort,
      )
          ? null
          : apiServer.publicPort,
    ).toString();
  }

  bool _isDefaultPort(String scheme, int port) {
    return (scheme == 'http' && port == 80) ||
        (scheme == 'https' && port == 443);
  }

  Response _rawResponse(String content, {required MimeType mimeType}) {
    final headers = Headers.build(
      (mh) => mh.cacheControl = CacheControlHeader(
        noCache: true,
        privateCache: true,
      ),
    );

    return Response.ok(
      body: Body.fromString(content, mimeType: mimeType),
      headers: headers,
    );
  }
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
          const base64Spec = '$escapedBase64';
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
              const urlWithoutQuery = request.url.split('?')[0];
              const queryString = request.url.includes('?') ? '?' + request.url.split('?').slice(1).join('?') : '';
              const urlMatch = urlWithoutQuery.match(/\\/([^\\/]+)\\/([^\\/]+)\$/);
              if (urlMatch) {
                const methodName = urlMatch[2];
                
                // Transform URL: remove method name from path
                request.url = urlWithoutQuery.replace('/' + methodName, '') + queryString;
                
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
                
                // Semantic OpenAPI requests may carry parameters in the query string.
                // We need to move them to the body
                if (request.url.includes('?')) {
                  try {
                    const urlObj = new URL(request.url);
                    urlObj.searchParams.forEach((value, key) => {
                      // Try to parse as JSON, number, or boolean, otherwise keep as string
                      if (value === 'true' || value === 'false') {
                        bodyObj[key] = value === 'true';
                      } else if ((value.startsWith('{') && value.endsWith('}')) || (value.startsWith('[') && value.endsWith(']'))) {
                        try {
                          bodyObj[key] = JSON.parse(value);
                        } catch (e) {
                          bodyObj[key] = value;
                        }
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
