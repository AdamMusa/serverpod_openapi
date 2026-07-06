/// OpenAPI metadata supplied by an endpoint for one of its Serverpod methods.
///
/// Serverpod still provides the method parameters, parameter types, nullability,
/// auth requirements, and dispatch wiring through its generated endpoint
/// connectors. This metadata only fills the API contract details Serverpod does
/// not expose on [MethodConnector], such as the semantic HTTP method, summary,
/// and response type override.
class OpenApiOperation {
  final String method;
  final String? summary;
  final Type? response;

  const OpenApiOperation(
    this.method, {
    this.summary,
    this.response,
  });

  const OpenApiOperation.get({
    this.summary,
    this.response,
  }) : method = 'GET';

  const OpenApiOperation.post({
    this.summary,
    this.response,
  }) : method = 'POST';

  const OpenApiOperation.put({
    this.summary,
    this.response,
  }) : method = 'PUT';

  const OpenApiOperation.patch({
    this.summary,
    this.response,
  }) : method = 'PATCH';

  const OpenApiOperation.delete({
    this.summary,
    this.response,
  }) : method = 'DELETE';
}

/// Implement this on a Serverpod endpoint to supply explicit OpenAPI metadata
/// for methods on that endpoint without mirrors, build_runner, or route-level
/// configuration.
abstract interface class OpenApiEndpoint {
  Map<String, OpenApiOperation> get openApiOperations;
}

class Get extends OpenApiOperation {
  const Get({
    super.summary,
    super.response,
  }) : super.get();
}

class Post extends OpenApiOperation {
  const Post({
    super.summary,
    super.response,
  }) : super.post();
}

class Put extends OpenApiOperation {
  const Put({
    super.summary,
    super.response,
  }) : super.put();
}

class Patch extends OpenApiOperation {
  const Patch({
    super.summary,
    super.response,
  }) : super.patch();
}

class Delete extends OpenApiOperation {
  const Delete({
    super.summary,
    super.response,
  }) : super.delete();
}
