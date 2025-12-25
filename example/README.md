# Example Usage

This directory contains an example `server.dart` file showing how to integrate `serverpod_openapi` into your Serverpod project.

## Complete Example Code

Here's the complete `server.dart` file:

```dart
// NOTE: This is an example file. Update the imports below to match your Serverpod project structure.
// ignore_for_file: uri_does_not_exist, undefined_function

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_openapi/serverpod_openapi.dart';

void run(List<String> args) async {
  // Initialize Serverpod
  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
  );

  // Add OpenAPI documentation route
  // This will be available at http://localhost:8082/openapi
  pod.webServer.addRoute(
    RouteOpenApi(
      pod,
      title: 'E-Commerce API',
      version: '1.0.0',
      description: 'Complete API for managing products, orders, and customers.',
    ),
    '/openapi',
  );

  // Optional: Add additional routes or middleware here
  // pod.webServer.addRoute(...);

  // Start the server
  await pod.start();
}
```
