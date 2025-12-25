import 'dart:convert';
import 'package:serverpod/serverpod.dart';

/// Generates OpenAPI 3.0 specification from Serverpod endpoints
///
/// Serverpod's generated code doesn't explicitly store HTTP method information.
/// This generator intelligently infers HTTP methods from method names for REST-like documentation.
class OpenApiGenerator {
  final Serverpod pod;
  final String title;
  final String version;
  final String? serverUrl;
  final String? description;

  OpenApiGenerator({
    required this.pod,
    this.title = 'API Documentation',
    this.version = '1.0.0',
    this.serverUrl,
    this.description,
  });

  /// Generates the complete OpenAPI specification
  Map<String, dynamic> generate() {
    final paths = <String, dynamic>{};
    final components = <String, dynamic>{
      'schemas': <String, dynamic>{},
      'securitySchemes': <String, dynamic>{
        'bearerAuth': {
          'type': 'http',
          'scheme': 'bearer',
          'bearerFormat': 'JWT',
          'description': 'Bearer token authentication. '
              'To obtain a token:\n'
              '1. Call the login endpoint (/emailIdp/login) with your email and password\n'
              '2. Copy the "key" value from the response\n'
              '3. Click "Authorize" above and paste the token, or use it in the Authorization header as: Bearer <token>',
        },
      },
    };

    // Extract all endpoints and their methods
    // Serverpod's actual structure: POST to /endpointName with body: {"method": "methodName", ...params}
    // For OpenAPI, we create separate paths with semantic HTTP methods: /endpointName/methodName
    pod.endpoints.connectors.forEach((endpointName, connector) {
      // Check if this endpoint requires authentication
      final requiresAuth = connector.endpoint.requireLogin;

      connector.methodConnectors.forEach((methodName, methodConnector) {
        // Infer the semantic HTTP method from method name
        // This is the "real" HTTP method that should be used in OpenAPI
        final httpMethod = _inferHttpMethod(methodName);

        // Create path: /endpointName/methodName for OpenAPI documentation
        // The actual Serverpod path is /endpointName, but we use /endpointName/methodName for clarity
        final path = '/$endpointName/$methodName';

        final isAuth = _isAuthEndpoint(endpointName, methodName);
        final isLogin = methodName == 'login';
        final operation = _generateOperation(
          endpointName: endpointName,
          methodName: methodName,
          methodConnector: methodConnector,
          httpMethod:
              httpMethod, // Use semantic method as the actual HTTP method
          requiresAuth: requiresAuth &&
              !isAuth, // Use endpoint's requireLogin, but exclude auth endpoints
          isAuthEndpoint: isAuth,
          isLogin: isLogin,
        );

        // Initialize path if not exists
        if (!paths.containsKey(path)) {
          paths[path] = <String, dynamic>{};
        }

        // Add operation with its semantic HTTP method
        paths[path][httpMethod.toLowerCase()] = operation;
      });
    });

    return {
      'openapi': '3.0.3',
      'info': {
        'title': title,
        'version': version,
        if (description != null) 'description': description,
      },
      if (serverUrl != null)
        'servers': [
          {'url': serverUrl, 'description': 'API Server'}
        ],
      'paths': paths,
      'components': components,
    };
  }

  /// Generates an OpenAPI operation for a method
  Map<String, dynamic> _generateOperation({
    required String endpointName,
    required String methodName,
    required dynamic methodConnector,
    required String
        httpMethod, // The semantic HTTP method (GET, POST, PATCH, DELETE)
    required bool requiresAuth, // Whether the endpoint requires authentication
    bool isAuthEndpoint = false,
    bool isLogin = false,
  }) {
    final requestBody = <String, dynamic>{};
    final requiredParams = <String>[];

    // Serverpod requires "method" field in request body
    // All method parameters also go in request body
    final properties = <String, dynamic>{
      'method': {
        'type': 'string',
        'enum': [methodName],
        'description': 'The method name to call on the endpoint',
        'example': methodName,
      },
    };

    // Add method parameters
    methodConnector.params.forEach((paramName, paramDesc) {
      properties[paramName] =
          _generateSchemaFromType(paramDesc.type, paramDesc.nullable);
      if (!paramDesc.nullable) {
        requiredParams.add(paramName);
      }
    });

    // "method" is always required
    requiredParams.insert(0, 'method');

    if (properties.isNotEmpty) {
      requestBody['required'] = true;

      // Add example for login endpoint
      Map<String, dynamic>? example;
      if (isLogin &&
          properties.containsKey('email') &&
          properties.containsKey('password')) {
        example = {
          'email': 'user@example.com',
          'password': 'your-password',
        };
      }

      requestBody['content'] = {
        'application/json': {
          'schema': {
            'type': 'object',
            'properties': properties,
            if (requiredParams.isNotEmpty) 'required': requiredParams,
          },
          if (example != null) 'example': example,
        },
      };
    }

    // Build summary from method name
    final summary = _generateSummary(methodName);

    // Add description explaining Serverpod's RPC structure
    final description = isLogin
        ? 'Login with email and password to obtain an authentication token. '
            'The response contains a "key" field which is your bearer token. '
            'Use this token in the "Authorize" button above or as a Bearer token in the Authorization header.\n\n'
            'Note: Serverpod uses POST internally for all RPC calls. The HTTP method shown ($httpMethod) is semantic.'
        : 'Note: Serverpod uses POST internally for all RPC calls to /$endpointName with {"method": "$methodName", ...params} in the body. '
            'The HTTP method shown ($httpMethod) is semantic for REST-like documentation.';

    // No path parameters needed - method name is in the path for OpenAPI
    // but Serverpod actually uses /endpointName with method in body
    final parameters = <Map<String, dynamic>>[];

    final operation = <String, dynamic>{
      'operationId': '${endpointName}_$methodName',
      'summary': summary,
      'tags': [endpointName],
      'parameters': parameters,
      'description': description,
      'responses': {
        '200': _generateResponseSchema(isLogin),
        '400': {'description': 'Bad request'},
        '401': {'description': 'Unauthorized'},
        '500': {'description': 'Internal server error'},
      },
      // Store the HTTP method for later use
      // Store Serverpod metadata for request transformation
      'x-serverpod-endpoint': '/$endpointName',
      'x-serverpod-method': methodName,
      'x-serverpod-actual-http-method':
          'POST', // Serverpod always uses POST internally
    };

    if (requestBody.isNotEmpty) {
      operation['requestBody'] = requestBody;
    }

    // Only add security requirement if the endpoint requires authentication
    // Auth endpoints (login, register, etc.) don't require authentication
    if (requiresAuth && !isAuthEndpoint) {
      operation['security'] = [
        {'bearerAuth': []}
      ];
    }

    return operation;
  }

  /// Checks if an endpoint is an authentication endpoint (login, register, etc.)
  bool _isAuthEndpoint(String endpointName, String methodName) {
    final lowerEndpoint = endpointName.toLowerCase();
    final lowerMethod = methodName.toLowerCase();

    // Auth-related endpoints
    if (lowerEndpoint.contains('auth') ||
        lowerEndpoint.contains('idp') ||
        lowerEndpoint.contains('login') ||
        lowerEndpoint.contains('register')) {
      return true;
    }

    // Auth-related methods
    if (lowerMethod == 'login' ||
        lowerMethod == 'logout' ||
        lowerMethod.startsWith('register') ||
        lowerMethod.startsWith('startregistration') ||
        lowerMethod.startsWith('finishregistration') ||
        lowerMethod.startsWith('verifyregistration') ||
        lowerMethod.startsWith('startpasswordreset') ||
        lowerMethod.startsWith('verifypasswordreset') ||
        lowerMethod.startsWith('finishpasswordreset')) {
      return true;
    }

    return false;
  }

  /// Generates response schema for an operation
  Map<String, dynamic> _generateResponseSchema(bool isLogin) {
    if (isLogin) {
      // Login endpoint returns AuthSuccess with token
      return {
        'description':
            'Authentication successful. Returns an AuthSuccess object containing the session token.',
        'content': {
          'application/json': {
            'schema': {
              'type': 'object',
              'properties': {
                'keyId': {
                  'type': 'string',
                  'description': 'Key ID for the session',
                },
                'key': {
                  'type': 'string',
                  'description': 'Session key (use this as Bearer token)',
                },
                'userInfo': {
                  'type': 'object',
                  'description': 'User information',
                },
              },
              'required': ['keyId', 'key'],
            },
            'example': {
              'keyId': 'session-key-id',
              'key': 'your-bearer-token-here',
              'userInfo': {
                'id': 1,
                'userName': 'user@example.com',
              },
            },
          },
        },
      };
    }

    // Generic response for other endpoints
    return {
      'description': 'Successful response',
      'content': {
        'application/json': {
          'schema': {'type': 'object'},
        },
      },
    };
  }

  /// Generates a JSON schema from a Dart type
  Map<String, dynamic> _generateSchemaFromType(Type type, bool nullable) {
    final schema = <String, dynamic>{};
    final typeStr = type.toString();

    // Handle common types by checking string representation
    if (typeStr == 'int' || typeStr == 'int?') {
      schema['type'] = 'integer';
      schema['format'] = 'int64';
    } else if (typeStr == 'double' || typeStr == 'double?') {
      schema['type'] = 'number';
      schema['format'] = 'double';
    } else if (typeStr == 'String' || typeStr == 'String?') {
      schema['type'] = 'string';
    } else if (typeStr == 'bool' || typeStr == 'bool?') {
      schema['type'] = 'boolean';
    } else if (typeStr == 'DateTime' || typeStr == 'DateTime?') {
      schema['type'] = 'string';
      schema['format'] = 'date-time';
    } else if (typeStr.contains('UuidValue')) {
      schema['type'] = 'string';
      schema['format'] = 'uuid';
    } else if (typeStr.contains('Map')) {
      schema['type'] = 'object';
      schema['additionalProperties'] = true;
    } else if (typeStr.contains('List')) {
      schema['type'] = 'array';
      schema['items'] = {'type': 'object'};
    } else {
      // For custom types, use object
      schema['type'] = 'object';
      schema['description'] = 'Type: $typeStr';
    }

    if (nullable) {
      return {
        'oneOf': [
          schema,
          {'type': 'null'}
        ],
        'nullable': true,
      };
    }

    return schema;
  }

  /// Infers HTTP method from method name for semantic documentation
  ///
  /// Since Serverpod's generated code doesn't store HTTP method information,
  /// we infer it from common naming patterns for better REST-like OpenAPI documentation.
  String _inferHttpMethod(String methodName) {
    final lowerName = methodName.toLowerCase();

    // Read operations (GET)
    if (lowerName.startsWith('get') ||
        lowerName.startsWith('list') ||
        lowerName.startsWith('fetch') ||
        lowerName.startsWith('find') ||
        lowerName.startsWith('read') ||
        lowerName.startsWith('retrieve') ||
        lowerName.startsWith('query') ||
        lowerName.startsWith('search') ||
        lowerName.startsWith('show') ||
        lowerName.startsWith('view') ||
        lowerName.startsWith('load')) {
      return 'GET';
    }

    // Create operations (POST)
    if (lowerName.startsWith('create') ||
        lowerName.startsWith('add') ||
        lowerName.startsWith('insert') ||
        lowerName.startsWith('save') ||
        lowerName.startsWith('register') ||
        lowerName.startsWith('new') ||
        lowerName.startsWith('build') ||
        lowerName.startsWith('generate') ||
        lowerName.startsWith('submit') ||
        lowerName.startsWith('send') ||
        lowerName.startsWith('post')) {
      return 'POST';
    }

    // Update operations (PATCH)
    if (lowerName.startsWith('update') ||
        lowerName.startsWith('modify') ||
        lowerName.startsWith('patch') ||
        lowerName.startsWith('edit') ||
        lowerName.startsWith('change') ||
        lowerName.startsWith('set') ||
        lowerName.startsWith('put') ||
        lowerName.startsWith('replace') ||
        lowerName.startsWith('adjust')) {
      return 'PATCH';
    }

    // Delete operations (DELETE)
    if (lowerName.startsWith('delete') ||
        lowerName.startsWith('remove') ||
        lowerName.startsWith('destroy') ||
        lowerName.startsWith('drop') ||
        lowerName.startsWith('clear') ||
        lowerName.startsWith('unlink') ||
        lowerName.startsWith('unregister')) {
      return 'DELETE';
    }

    // Action/command operations (POST - for operations that perform actions)
    if (lowerName.startsWith('execute') ||
        lowerName.startsWith('run') ||
        lowerName.startsWith('perform') ||
        lowerName.startsWith('do') ||
        lowerName.startsWith('trigger') ||
        lowerName.startsWith('invoke') ||
        lowerName.startsWith('call') ||
        lowerName.startsWith('start') ||
        lowerName.startsWith('stop') ||
        lowerName.startsWith('cancel') ||
        lowerName.startsWith('complete') ||
        lowerName.startsWith('finish') ||
        lowerName.startsWith('verify') ||
        lowerName.startsWith('validate') ||
        lowerName.startsWith('sync') ||
        lowerName.startsWith('link') ||
        lowerName.startsWith('login') ||
        lowerName.startsWith('logout')) {
      return 'POST';
    }

    // If we can't determine, default to POST
    // Serverpod uses POST internally for all RPC calls, so POST is the appropriate default
    return 'POST';
  }

  /// Generates a summary from method name
  String _generateSummary(String methodName) {
    // Convert camelCase to Title Case
    final words = methodName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .trim()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');

    return words;
  }

  /// Converts the OpenAPI spec to JSON string
  String toJson({bool pretty = true}) {
    final spec = generate();
    if (pretty) {
      return JsonEncoder.withIndent('  ').convert(spec);
    }
    return jsonEncode(spec);
  }

  /// Converts the OpenAPI spec to YAML string
  String toYaml() {
    // Simple YAML conversion (for full YAML support, consider using a package)
    final spec = generate();
    return _jsonToYaml(spec, 0);
  }

  String _jsonToYaml(dynamic obj, int indent) {
    final indentStr = '  ' * indent;
    if (obj is Map) {
      final buffer = StringBuffer();
      obj.forEach((key, value) {
        if (value is Map || value is List) {
          buffer.writeln('$indentStr$key:');
          buffer.write(_jsonToYaml(value, indent + 1));
        } else if (value is String) {
          buffer.writeln('$indentStr$key: "$value"');
        } else {
          buffer.writeln('$indentStr$key: $value');
        }
      });
      return buffer.toString();
    } else if (obj is List) {
      final buffer = StringBuffer();
      for (var item in obj) {
        buffer.writeln('$indentStr-');
        buffer.write(_jsonToYaml(item, indent + 1));
      }
      return buffer.toString();
    } else {
      return '$indentStr$obj\n';
    }
  }
}
