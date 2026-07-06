/// Declares the HTTP method that should be shown in the generated OpenAPI spec.
///
/// Serverpod still receives requests through its normal RPC POST transport.
/// These annotations only control the semantic OpenAPI/Swagger operation.
class OpenApiMethod {
  final String method;

  const OpenApiMethod(this.method);

  const OpenApiMethod.get() : method = 'GET';
  const OpenApiMethod.post() : method = 'POST';
  const OpenApiMethod.put() : method = 'PUT';
  const OpenApiMethod.patch() : method = 'PATCH';
  const OpenApiMethod.delete() : method = 'DELETE';
}

/// Documents the annotated Serverpod endpoint method as a GET operation.
const get = OpenApiMethod.get();

/// Documents the annotated Serverpod endpoint method as a POST operation.
const post = OpenApiMethod.post();

/// Documents the annotated Serverpod endpoint method as a PUT operation.
const put = OpenApiMethod.put();

/// Documents the annotated Serverpod endpoint method as a PATCH operation.
const patch = OpenApiMethod.patch();

/// Documents the annotated Serverpod endpoint method as a DELETE operation.
const delete = OpenApiMethod.delete();
