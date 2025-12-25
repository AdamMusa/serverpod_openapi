# Testing serverpod_openapi

## Running Tests

These tests require a Serverpod project context with generated Protocol and Endpoints.

### Option 1: Run tests in a Serverpod project

Copy the test files to your Serverpod project's `test` directory and run:

```bash
dart test
```

### Option 2: Integration tests

For full integration testing, create tests in your Serverpod project that use the actual generated code:

```dart
import 'package:test/test.dart';
import 'package:serverpod_test/serverpod_test.dart';
import 'package:serverpod_openapi/serverpod_openapi.dart';
import 'package:your_server/src/generated/protocol.dart';
import 'package:your_server/src/generated/endpoints.dart';

void main() {
  test('RouteOpenApi generates valid OpenAPI spec', () async {
    final pod = Serverpod(
      [],
      Protocol(),
      Endpoints(),
    );
    
    final route = RouteOpenApi(
      pod,
      title: 'Test API',
      version: '1.0.0',
    );
    
    final session = Session(pod, 'test');
    final request = Request(
      'GET',
      Uri.parse('http://localhost:8082/openapi?format=json'),
    );
    
    final widget = await route.build(session, request);
    final html = widget.toString();
    
    // Verify HTML contains expected content
    expect(html, contains('Test API'));
  });
}
```

## Test Coverage

The tests cover:

- RouteOpenApi constructor with default and custom parameters
- Different output formats (Swagger UI, JSON, YAML)
- OpenAPI spec generation
- HTML content validation
- Security schemes
- Custom title, version, and description

