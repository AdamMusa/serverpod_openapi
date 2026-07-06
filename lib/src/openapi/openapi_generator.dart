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
        final httpMethod = inferHttpMethodForDocumentation(
          methodName,
          parameterNames: _getParameterNames(methodConnector),
          returnsVoid: _returnsVoid(methodConnector),
        );

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
    final parameters = <Map<String, dynamic>>[];
    final usesQueryParameters = httpMethod == 'GET';

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
      final schema =
          _generateSchemaFromType(paramDesc.type, paramDesc.nullable);
      if (usesQueryParameters) {
        parameters.add({
          'name': paramName,
          'in': 'query',
          'required': !paramDesc.nullable,
          'schema': schema,
        });
        return;
      }

      properties[paramName] = schema;
      if (!paramDesc.nullable) {
        requiredParams.add(paramName);
      }
    });

    // "method" is always required
    if (!usesQueryParameters) {
      requiredParams.insert(0, 'method');
    }

    if (!usesQueryParameters && properties.isNotEmpty) {
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
  /// Infers a semantic HTTP method for documentation from the data Serverpod
  /// exposes in generated endpoint connectors.
  static String inferHttpMethodForDocumentation(
    String methodName, {
    Iterable<String> parameterNames = const [],
    bool? returnsVoid,
  }) {
    final lowerName = methodName.toLowerCase();
    final words = _splitMethodName(methodName);
    final firstWord = words.isEmpty ? lowerName : words.first;
    final paramNames = parameterNames
        .map((param) => param.toLowerCase().replaceAll('_', ''))
        .toList();

    bool startsWithAny(Iterable<String> prefixes) {
      return prefixes.any(lowerName.startsWith);
    }

    bool firstWordIsAny(Set<String> verbs) {
      return verbs.contains(firstWord);
    }

    final hasQueryLikeParams = paramNames.isNotEmpty &&
        paramNames.every(
          (param) =>
              param == 'id' ||
              param.endsWith('id') ||
              param == 'uuid' ||
              param.endsWith('uuid') ||
              param == 'query' ||
              param == 'filter' ||
              param == 'filters' ||
              param == 'search' ||
              param == 'searchterm' ||
              param == 'limit' ||
              param == 'offset' ||
              param == 'page' ||
              param == 'pagesize' ||
              param == 'sort' ||
              param == 'orderby' ||
              param == 'start' ||
              param == 'end' ||
              param == 'from' ||
              param == 'to' ||
              param.startsWith('include') ||
              param.startsWith('with'),
        );

    // Read operations (GET).
    if (firstWordIsAny(_readVerbs) || startsWithAny(_readPrefixes)) {
      return 'GET';
    }

    // Update operations (PATCH).
    if (firstWordIsAny(_updateVerbs) || startsWithAny(_updatePrefixes)) {
      return 'PATCH';
    }

    // Delete operations (DELETE).
    if (firstWordIsAny(_deleteVerbs) || startsWithAny(_deletePrefixes)) {
      return 'DELETE';
    }

    if (returnsVoid == true) {
      return 'POST';
    }

    if (paramNames.isEmpty &&
        words.any((word) => _readNouns.contains(word)) &&
        returnsVoid != true) {
      return 'GET';
    }

    if (hasQueryLikeParams && returnsVoid != true) {
      return 'GET';
    }

    // If we can't determine, default to POST
    // Serverpod uses POST internally for all RPC calls, so POST is the appropriate default
    return 'POST';
  }

  static List<String> _splitMethodName(String methodName) {
    return methodName
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll(RegExp(r'[_\-\s]+'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word.toLowerCase())
        .toList();
  }

  List<String> _getParameterNames(dynamic methodConnector) {
    final params = methodConnector.params;
    if (params is Map) {
      return params.keys.map((key) => key.toString().toLowerCase()).toList();
    }
    return const [];
  }

  bool? _returnsVoid(dynamic methodConnector) {
    if (methodConnector is MethodConnector) {
      return methodConnector.returnsVoid;
    }
    return null;
  }

  static const _readVerbs = {
    'get',
    'list',
    'fetch',
    'find',
    'read',
    'retrieve',
    'query',
    'search',
    'show',
    'view',
    'load',
    'count',
    'check',
  };

  static const _readPrefixes = {
    'get',
    'list',
    'fetch',
    'find',
    'read',
    'retrieve',
    'query',
    'search',
  };

  static const _updateVerbs = {
    'update',
    'modify',
    'patch',
    'edit',
    'change',
    'set',
    'put',
    'replace',
    'adjust',
  };

  static const _updatePrefixes = {
    'update',
    'modify',
    'patch',
  };

  static const _deleteVerbs = {
    'delete',
    'remove',
    'destroy',
    'drop',
    'unlink',
    'unregister',
  };

  static const _deletePrefixes = {
    'delete',
    'remove',
    'destroy',
  };

  static const _readNouns = {
    'status',
    'health',
    'info',
    'summary',
    'overview',
    'settings',
    'configuration',
    'config',
    'data',
    'definition',
    'definitions',
    'count',
    'counts',
  };

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
      return const JsonEncoder.withIndent('  ').convert(spec);
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
