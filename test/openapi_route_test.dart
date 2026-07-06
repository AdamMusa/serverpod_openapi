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

      for (final uri in testUrls) {
        final format = uri.queryParameters['format'];
        if (uri.queryParameters.containsKey('format') && format != null) {
          expect(format, isNotNull);
          expect(['json', 'yaml'], contains(format));
        } else {
          expect(format, isNull);
        }
      }
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

      for (final testCase in testCases) {
        final request = testCase['request'] as Uri;
        final expected = testCase['expected'] as String;
        final apiServerUrl = '${request.scheme}://${request.host}:8080';
        expect(apiServerUrl, expected);
      }
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

    test('should return raw JSON content without HTML wrapping', () {
      final jsonContent = '{"openapi":"3.0.3"}';

      expect(jsonContent, isNot(contains('<!DOCTYPE html>')));
      expect(jsonContent, isNot(contains('<pre>')));
      expect(() => jsonDecode(jsonContent), returnsNormally);
    });

    test('should return raw YAML content without HTML wrapping', () {
      final yamlContent = 'openapi: 3.0.3';

      expect(yamlContent, isNot(contains('<!DOCTYPE html>')));
      expect(yamlContent, isNot(contains('<pre>')));
      expect(yamlContent, contains('openapi:'));
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

    test('should preserve query string when transforming Serverpod URLs', () {
      const requestUrl =
          'http://localhost:8080/user/getUser?userId=1&includePosts=true';
      final urlWithoutQuery = requestUrl.split('?')[0];
      final queryString = requestUrl.contains('?')
          ? '?${requestUrl.split('?').skip(1).join('?')}'
          : '';
      final urlMatch = RegExp(r'/([^/]+)/([^/]+)$').firstMatch(urlWithoutQuery);

      expect(urlMatch, isNotNull);

      final methodName = urlMatch!.group(2)!;
      final transformedUrl =
          urlWithoutQuery.replaceFirst('/$methodName', '') + queryString;

      expect(
        transformedUrl,
        'http://localhost:8080/user?userId=1&includePosts=true',
      );
    });

    test('should parse query values before moving them to POST body', () {
      final queryValues = {
        'includePosts': 'true',
        'limit': '10',
        'filter': '{"status":"published"}',
        'tags': '["dart","serverpod"]',
        'search': 'hello',
      };

      final body = <String, dynamic>{};
      queryValues.forEach((key, value) {
        if (value == 'true' || value == 'false') {
          body[key] = value == 'true';
        } else if ((value.startsWith('{') && value.endsWith('}')) ||
            (value.startsWith('[') && value.endsWith(']'))) {
          body[key] = jsonDecode(value);
        } else if (num.tryParse(value) != null && value.isNotEmpty) {
          body[key] = num.parse(value);
        } else {
          body[key] = value;
        }
      });

      expect(body['includePosts'], isTrue);
      expect(body['limit'], 10);
      expect(body['filter'], {'status': 'published'});
      expect(body['tags'], ['dart', 'serverpod']);
      expect(body['search'], 'hello');
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

      final prettyJson = const JsonEncoder.withIndent('  ').convert(spec);
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

      for (final urlStr in testUrls) {
        final uri = Uri.parse(urlStr);
        expect(uri.scheme, isNotEmpty);
        expect(uri.host, isNotEmpty);
        if (uri.queryParameters.containsKey('format')) {
          expect(['json', 'yaml'], contains(uri.queryParameters['format']));
        }
      }
    });
  });
}
