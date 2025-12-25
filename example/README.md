# Example Usage

This directory contains an example `server.dart` file showing how to integrate `serverpod_openapi` into your Serverpod project.

## Setup

1. Copy this `server.dart` file to your Serverpod project's `bin` directory
2. Update the imports to match your project structure:
   - Replace `package:your_server/src/generated/protocol.dart` with your actual protocol import
   - Replace `package:your_server/src/generated/endpoints.dart` with your actual endpoints import
3. Add `serverpod_openapi` to your `pubspec.yaml`:
   ```yaml
   dependencies:
     serverpod_openapi: ^0.0.1
   ```
4. Run `dart pub get`
5. Start your server and visit `http://localhost:8082/openapi` to view the API documentation

## Customization

You can customize the OpenAPI documentation by modifying the `RouteOpenApi` parameters:

```dart
pod.webServer.addRoute(
  RouteOpenApi(
    pod,
    title: 'Your API Title',
    version: '1.0.0',
    description: 'Your API description',
  ),
  '/openapi', // Customize the path if needed
);
```
