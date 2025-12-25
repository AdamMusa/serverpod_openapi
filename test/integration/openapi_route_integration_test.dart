import 'dart:convert';
import 'package:test/test.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_openapi/serverpod_openapi.dart';

// Import your generated code
// import 'package:your_server/src/generated/protocol.dart';
// import 'package:your_server/src/generated/endpoints.dart';

/// Integration tests for RouteOpenApi
///
/// These tests require a real Serverpod instance with generated Protocol
/// and Endpoints. Copy this file to your Serverpod project's test directory
/// and uncomment the imports above.
void main() {
  group('RouteOpenApi Integration Tests', () {
    // Uncomment and modify these tests when running in a Serverpod project:
    /*
    late Serverpod pod;
    late RouteOpenApi route;

    setUp(() {
      pod = Serverpod([], Protocol(), Endpoints());
      route = RouteOpenApi(pod);
    });

    tearDown(() {
      pod.shutdown();
    });

    test('should return SwaggerUIWidget by default', () async {
      final session = Session(
        server: pod.server,
        endpoint: pod.endpoints.getConnectorByName('greeting')!,
        enableLogging: false,
      );
      final request = Request.get(
        Uri.parse('http://localhost:8082/openapi'),
      );

      final widget = await route.build(session, request);
      final html = widget.toString();

      expect(html, contains('swagger-ui'));
      expect(html, contains('SwaggerUIBundle'));
      expect(html, contains('requestInterceptor'));
    });

    test('should return JsonWidget when format=json', () async {
      final session = Session(
        server: pod.server,
        endpoint: pod.endpoints.getConnectorByName('greeting')!,
        enableLogging: false,
      );
      final request = Request.get(
        Uri.parse('http://localhost:8082/openapi?format=json'),
      );

      final widget = await route.build(session, request);
      final html = widget.toString();

      expect(html, contains('OpenAPI Specification - JSON'));
      
      // Extract and validate JSON
      final jsonMatch = RegExp(r'<pre>(.*?)</pre>', dotAll: true)
          .firstMatch(html);
      expect(jsonMatch, isNotNull);
      
      if (jsonMatch != null) {
        final jsonContent = jsonMatch.group(1);
        expect(jsonContent, isNotNull);
        expect(() => jsonDecode(jsonContent!), returnsNormally);
        
        final decoded = jsonDecode(jsonContent!);
        expect(decoded['openapi'], '3.0.3');
        expect(decoded['info'], isNotNull);
        expect(decoded['paths'], isA<Map>());
      }
    });

    test('should return YamlWidget when format=yaml', () async {
      final session = Session(
        server: pod.server,
        endpoint: pod.endpoints.getConnectorByName('greeting')!,
        enableLogging: false,
      );
      final request = Request.get(
        Uri.parse('http://localhost:8082/openapi?format=yaml'),
      );

      final widget = await route.build(session, request);
      final html = widget.toString();

      expect(html, contains('OpenAPI Specification - YAML'));
      expect(html, contains('openapi:'));
      expect(html, contains('info:'));
    });

    test('should use custom title, version, and description', () async {
      final customRoute = RouteOpenApi(
        pod,
        title: 'Custom API',
        version: '2.0.0',
        description: 'Custom description',
      );

      final session = Session(
        server: pod.server,
        endpoint: pod.endpoints.getConnectorByName('greeting')!,
        enableLogging: false,
      );
      final request = Request.get(
        Uri.parse('http://localhost:8082/openapi?format=json'),
      );

      final widget = await customRoute.build(session, request);
      final html = widget.toString();

      final jsonMatch = RegExp(r'<pre>(.*?)</pre>', dotAll: true)
          .firstMatch(html);
      if (jsonMatch != null) {
        final jsonContent = jsonMatch.group(1);
        if (jsonContent != null) {
          final decoded = jsonDecode(jsonContent);
          expect(decoded['info']['title'], 'Custom API');
          expect(decoded['info']['version'], '2.0.0');
          expect(decoded['info']['description'], 'Custom description');
        }
      }
    });

    test('should generate paths for all endpoints', () async {
      final session = Session(
        server: pod.server,
        endpoint: pod.endpoints.getConnectorByName('greeting')!,
        enableLogging: false,
      );
      final request = Request.get(
        Uri.parse('http://localhost:8082/openapi?format=json'),
      );

      final widget = await route.build(session, request);
      final html = widget.toString();

      final jsonMatch = RegExp(r'<pre>(.*?)</pre>', dotAll: true)
          .firstMatch(html);
      if (jsonMatch != null) {
        final jsonContent = jsonMatch.group(1);
        if (jsonContent != null) {
          final decoded = jsonDecode(jsonContent);
          final paths = decoded['paths'] as Map;
          
          // Should have at least one path
          expect(paths.isNotEmpty, isTrue);
          
          // Each path should have HTTP methods
          for (final path in paths.keys) {
            final pathDef = paths[path] as Map;
            expect(pathDef.isNotEmpty, isTrue);
          }
        }
      }
    });

    test('should include security schemes', () async {
      final session = Session(
        server: pod.server,
        endpoint: pod.endpoints.getConnectorByName('greeting')!,
        enableLogging: false,
      );
      final request = Request.get(
        Uri.parse('http://localhost:8082/openapi?format=json'),
      );

      final widget = await route.build(session, request);
      final html = widget.toString();

      final jsonMatch = RegExp(r'<pre>(.*?)</pre>', dotAll: true)
          .firstMatch(html);
      if (jsonMatch != null) {
        final jsonContent = jsonMatch.group(1);
        if (jsonContent != null) {
          final decoded = jsonDecode(jsonContent);
          expect(
            decoded['components']['securitySchemes'],
            isNotNull,
          );
          expect(
            decoded['components']['securitySchemes']['bearerAuth'],
            isNotNull,
          );
        }
      }
    });
    */
  });
}
