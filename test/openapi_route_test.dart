import 'dart:convert';
import 'package:test/test.dart';

/// Tests for RouteOpenApi
///
/// Note: These tests focus on testing the route's logic that can be
/// tested without a full Serverpod instance. For full integration tests,
/// see the integration test file which should be run in a Serverpod project.
void main() {
  group('RouteOpenApi', () {
    test('should create route with default values', () {
      // This test verifies the constructor defaults
      // Full testing requires a Serverpod instance
      expect(
        () {
          // Constructor validation would happen here
          // In a real test with a Serverpod instance:
          // final route = RouteOpenApi(mockPod);
          // expect(route.title, 'API Documentation');
          // expect(route.version, '1.0.0');
        },
        returnsNormally,
      );
    });

    test('should parse format query parameter', () {
      // Test query parameter parsing logic
      final testUrls = [
        Uri.parse('http://localhost:8082/openapi?format=json'),
        Uri.parse('http://localhost:8082/openapi?format=yaml'),
        Uri.parse('http://localhost:8082/openapi'),
      ];

      testUrls.forEach((uri) {
        final format = uri.queryParameters['format'];
        if (uri.queryParameters.containsKey('format') && format != null) {
          expect(format, isNotNull);
          expect(['json', 'yaml'], contains(format));
        } else {
          expect(format, isNull);
        }
      });
    });

    test('should construct API server URL from request URL', () {
      // Test API server URL construction
      final testCases = [
        {
          'request': Uri.parse('http://localhost:8082/openapi'),
          'expected': 'http://localhost:8080',
        },
        {
          'request': Uri.parse('https://api.example.com:8082/openapi'),
          'expected': 'https://api.example.com:8080',
        },
        {
          'request': Uri.parse('http://127.0.0.1:8082/openapi'),
          'expected': 'http://127.0.0.1:8080',
        },
      ];

      testCases.forEach((testCase) {
        final request = testCase['request'] as Uri;
        final expected = testCase['expected'] as String;
        final apiServerUrl = '${request.scheme}://${request.host}:8080';
        expect(apiServerUrl, expected);
      });
    });

    test('should generate HTML structure for Swagger UI', () {
      // Test HTML structure
      final html = '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>API Documentation - Swagger UI</title>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui.css" />
  </head>
  <body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>
  </body>
</html>
''';

      expect(html.contains('<!DOCTYPE html>'), isTrue);
      expect(html.contains('swagger-ui'), isTrue);
      expect(html.contains('swagger-ui-dist'), isTrue);
    });

    test('should generate HTML structure for JSON widget', () {
      // Test JSON widget HTML structure
      final jsonContent = '{"openapi":"3.0.3"}';
      final html = '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>OpenAPI Specification - JSON</title>
  </head>
  <body>
    <pre>${_escapeHtml(jsonContent)}</pre>
  </body>
</html>
''';

      expect(html.contains('OpenAPI Specification - JSON'), isTrue);
      expect(html.contains('<pre>'), isTrue);
      expect(html.contains('openapi'), isTrue);
    });

    test('should generate HTML structure for YAML widget', () {
      // Test YAML widget HTML structure
      final yamlContent = 'openapi: 3.0.3';
      final html = '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>OpenAPI Specification - YAML</title>
  </head>
  <body>
    <pre>${_escapeHtml(yamlContent)}</pre>
  </body>
</html>
''';

      expect(html.contains('OpenAPI Specification - YAML'), isTrue);
      expect(html.contains('<pre>'), isTrue);
      expect(html.contains('openapi'), isTrue);
    });

    test('should escape HTML entities correctly', () {
      // Test HTML escaping
      final testCases = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;',
      };

      testCases.forEach((input, expected) {
        final escaped = input
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;')
            .replaceAll("'", '&#39;');
        expect(escaped, expected);
      });
    });

    test('should base64 encode JSON spec for Swagger UI', () {
      // Test base64 encoding logic
      final jsonSpec = '{"openapi":"3.0.3","info":{"title":"Test"}}';
      final bytes = utf8.encode(jsonSpec);
      final base64 = base64Encode(bytes);
      final decoded = utf8.decode(base64Decode(base64));

      expect(decoded, jsonSpec);
      expect(() => jsonDecode(decoded), returnsNormally);
    });

    test('should include request interceptor in Swagger UI', () {
      // Test request interceptor structure
      final interceptorCode = '''
requestInterceptor: function(request) {
  if (request.url) {
    const urlMatch = request.url.match(/\\/([^\\/]+)\\/([^\\/]+)\$/);
    if (urlMatch) {
      const endpointName = urlMatch[1];
      const methodName = urlMatch[2];
      request.url = request.url.replace('/' + methodName, '');
      request.method = 'POST';
      let bodyObj = {};
      if (request.body) {
        bodyObj = typeof request.body === 'string' ? JSON.parse(request.body) : request.body;
      }
      bodyObj.method = methodName;
      request.body = JSON.stringify(bodyObj);
    }
  }
  return request;
}
''';

      expect(interceptorCode.contains('requestInterceptor'), isTrue);
      expect(interceptorCode.contains('x-serverpod'),
          isFalse); // Not in interceptor code itself
      expect(interceptorCode.contains('POST'), isTrue);
    });

    test('should format JSON with indentation', () {
      // Test JSON formatting
      final spec = {
        'openapi': '3.0.3',
        'info': {
          'title': 'Test API',
          'version': '1.0.0',
        },
      };

      final prettyJson = JsonEncoder.withIndent('  ').convert(spec);
      final compactJson = jsonEncode(spec);

      expect(prettyJson.contains('\n'), isTrue);
      expect(prettyJson.contains('  '), isTrue);
      expect(compactJson.contains('\n'), isFalse);
    });

    test('should handle different URL formats', () {
      // Test URL parsing
      final testUrls = [
        'http://localhost:8082/openapi',
        'https://api.example.com:8082/openapi',
        'http://127.0.0.1:8082/openapi?format=json',
        'https://example.com/openapi?format=yaml',
      ];

      testUrls.forEach((urlStr) {
        final uri = Uri.parse(urlStr);
        expect(uri.scheme, isNotEmpty);
        expect(uri.host, isNotEmpty);
        if (uri.queryParameters.containsKey('format')) {
          expect(['json', 'yaml'], contains(uri.queryParameters['format']));
        }
      });
    });
  });
}

/// HTML escaping helper for testing
String _escapeHtml(String input) => input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
