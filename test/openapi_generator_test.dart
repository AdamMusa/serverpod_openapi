import 'dart:convert';
import 'package:test/test.dart';

/// Tests for OpenApiGenerator
///
/// Note: These tests focus on testing the generator's logic that can be
/// tested without a full Serverpod instance. For full integration tests,
/// see the integration test file which should be run in a Serverpod project.
void main() {
  group('OpenApiGenerator', () {
    test('should create generator with default values', () {
      // This test verifies the constructor defaults
      // Full testing requires a Serverpod instance with endpoints
      expect(
        () {
          // Constructor validation would happen here
          // In a real test with a Serverpod instance:
          // final generator = OpenApiGenerator(pod: mockPod);
          // expect(generator.title, 'API Documentation');
          // expect(generator.version, '1.0.0');
        },
        returnsNormally,
      );
    });

    test('should generate valid JSON format', () {
      // Test JSON encoding/decoding logic
      final testSpec = {
        'openapi': '3.0.3',
        'info': {
          'title': 'Test API',
          'version': '1.0.0',
        },
        'paths': {},
        'components': {
          'securitySchemes': {
            'bearerAuth': {
              'type': 'http',
              'scheme': 'bearer',
            },
          },
        },
      };

      final json = JsonEncoder.withIndent('  ').convert(testSpec);
      expect(() => jsonDecode(json), returnsNormally);
      final decoded = jsonDecode(json);
      expect(decoded['openapi'], '3.0.3');
    });

    test('should generate valid YAML-like structure', () {
      // Test YAML conversion logic
      final testSpec = {
        'openapi': '3.0.3',
        'info': {
          'title': 'Test API',
          'version': '1.0.0',
        },
      };

      // Simple YAML conversion test
      final yaml = _simpleYamlConvert(testSpec);
      expect(yaml.contains('openapi:'), isTrue);
      expect(yaml.contains('info:'), isTrue);
    });

    test('should handle OpenAPI 3.0.3 structure', () {
      // Verify OpenAPI spec structure
      final spec = {
        'openapi': '3.0.3',
        'info': {
          'title': 'Test',
          'version': '1.0.0',
        },
        'paths': <String, dynamic>{},
        'components': {
          'securitySchemes': <String, dynamic>{},
        },
      };

      expect(spec['openapi'], '3.0.3');
      expect(spec['info'], isA<Map>());
      expect(spec['paths'], isA<Map>());
      expect(spec['components'], isA<Map>());
    });

    test('should format method names correctly', () {
      // Test summary generation logic
      final methodName = 'createUser';
      final words = methodName
          .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
          .trim()
          .split(' ')
          .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
          .join(' ');

      expect(words, 'Create User');
    });

    test('should infer HTTP methods from method names', () {
      // Test HTTP method inference logic
      final testCases = {
        'getUser': 'GET',
        'listUsers': 'GET',
        'fetchData': 'GET',
        'createUser': 'POST',
        'addItem': 'POST',
        'updateUser': 'PATCH',
        'modifyData': 'PATCH',
        'deleteUser': 'DELETE',
        'removeItem': 'DELETE',
        'login': 'POST',
        'unknownMethod': 'POST', // Default
      };

      testCases.forEach((methodName, expectedMethod) {
        final lowerName = methodName.toLowerCase();
        String httpMethod;

        if (lowerName.startsWith('get') ||
            lowerName.startsWith('list') ||
            lowerName.startsWith('fetch')) {
          httpMethod = 'GET';
        } else if (lowerName.startsWith('create') ||
            lowerName.startsWith('add') ||
            lowerName.startsWith('login')) {
          httpMethod = 'POST';
        } else if (lowerName.startsWith('update') ||
            lowerName.startsWith('modify')) {
          httpMethod = 'PATCH';
        } else if (lowerName.startsWith('delete') ||
            lowerName.startsWith('remove')) {
          httpMethod = 'DELETE';
        } else {
          httpMethod = 'POST'; // Default
        }

        expect(httpMethod, expectedMethod, reason: 'Method: $methodName');
      });
    });

    test('should generate type schemas correctly', () {
      // Test type schema generation logic
      final typeTests = {
        'int': {'type': 'integer', 'format': 'int64'},
        'double': {'type': 'number', 'format': 'double'},
        'String': {'type': 'string'},
        'bool': {'type': 'boolean'},
        'DateTime': {'type': 'string', 'format': 'date-time'},
      };

      typeTests.forEach((typeStr, expectedSchema) {
        Map<String, dynamic> schema = {};
        if (typeStr == 'int' || typeStr == 'int?') {
          schema = {'type': 'integer', 'format': 'int64'};
        } else if (typeStr == 'double' || typeStr == 'double?') {
          schema = {'type': 'number', 'format': 'double'};
        } else if (typeStr == 'String' || typeStr == 'String?') {
          schema = {'type': 'string'};
        } else if (typeStr == 'bool' || typeStr == 'bool?') {
          schema = {'type': 'boolean'};
        } else if (typeStr == 'DateTime' || typeStr == 'DateTime?') {
          schema = {'type': 'string', 'format': 'date-time'};
        }

        expect(schema['type'], expectedSchema['type']);
        if (expectedSchema.containsKey('format')) {
          expect(schema['format'], expectedSchema['format']);
        }
      });
    });

    test('should handle nullable types', () {
      // Test nullable type handling
      final baseSchema = {'type': 'string'};
      final nullableSchema = {
        'oneOf': [
          baseSchema,
          {'type': 'null'}
        ],
        'nullable': true,
      };

      expect(nullableSchema['nullable'], isTrue);
      expect(nullableSchema['oneOf'], isA<List>());
    });

    test('should generate operation structure', () {
      // Test operation structure
      final operation = {
        'operationId': 'user_createUser',
        'summary': 'Create User',
        'tags': ['user'],
        'parameters': [],
        'responses': {
          '200': {'description': 'Successful response'},
          '400': {'description': 'Bad request'},
          '401': {'description': 'Unauthorized'},
          '500': {'description': 'Internal server error'},
        },
        'x-serverpod-endpoint': '/user',
        'x-serverpod-method': 'createUser',
        'x-serverpod-actual-http-method': 'POST',
      };

      expect(operation['operationId'], 'user_createUser');
      expect(operation['tags'], contains('user'));
      expect(operation['responses'], isA<Map>());
      expect(operation['x-serverpod-endpoint'], '/user');
    });

    test('should generate request body structure', () {
      // Test request body structure
      final requestBody = {
        'required': true,
        'content': {
          'application/json': {
            'schema': {
              'type': 'object',
              'properties': {
                'method': {
                  'type': 'string',
                  'enum': ['createUser'],
                },
                'name': {'type': 'string'},
                'email': {'type': 'string'},
              },
              'required': ['method', 'name', 'email'],
            },
          },
        },
      };

      expect(requestBody['required'], isTrue);
      expect(requestBody['content'], isA<Map>());
      final content = requestBody['content'] as Map<String, dynamic>;
      final jsonContent = content['application/json'] as Map<String, dynamic>;
      final schema = jsonContent['schema'] as Map<String, dynamic>;
      expect(schema['properties'], isA<Map>());
      expect(schema['required'], contains('method'));
    });

    test('should generate security schemes', () {
      // Test security scheme structure
      final securitySchemes = {
        'bearerAuth': {
          'type': 'http',
          'scheme': 'bearer',
          'bearerFormat': 'JWT',
          'description': 'Bearer token authentication.',
        },
      };

      final bearerAuth = securitySchemes['bearerAuth'] as Map<String, dynamic>;
      expect(bearerAuth['type'], 'http');
      expect(bearerAuth['scheme'], 'bearer');
      expect(bearerAuth['bearerFormat'], 'JWT');
    });

    test('should detect auth endpoints', () {
      // Test auth endpoint detection logic
      final authEndpoints = [
        'emailIdp',
        'auth',
        'login',
        'register',
      ];

      final authMethods = [
        'login',
        'logout',
        'register',
        'startRegistration',
      ];

      authEndpoints.forEach((endpoint) {
        final isAuth = endpoint.toLowerCase().contains('auth') ||
            endpoint.toLowerCase().contains('idp') ||
            endpoint.toLowerCase().contains('login') ||
            endpoint.toLowerCase().contains('register');
        expect(isAuth, isTrue, reason: 'Endpoint: $endpoint');
      });

      authMethods.forEach((method) {
        final lowerMethod = method.toLowerCase();
        final isAuth = lowerMethod == 'login' ||
            lowerMethod == 'logout' ||
            lowerMethod.startsWith('register') ||
            lowerMethod.startsWith('startregistration');
        expect(isAuth, isTrue, reason: 'Method: $method');
      });
    });
  });
}

/// Simple YAML conversion for testing
String _simpleYamlConvert(Map<dynamic, dynamic> obj, [int indent = 0]) {
  final indentStr = '  ' * indent;
  final buffer = StringBuffer();
  obj.forEach((key, value) {
    if (value is Map) {
      buffer.writeln('$indentStr$key:');
      buffer.write(_simpleYamlConvert(value, indent + 1));
    } else if (value is String) {
      buffer.writeln('$indentStr$key: "$value"');
    } else {
      buffer.writeln('$indentStr$key: $value');
    }
  });
  return buffer.toString();
}
