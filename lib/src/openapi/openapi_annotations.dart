/// Declares the HTTP method that should be shown in the generated OpenAPI spec.
///
/// Serverpod still receives requests through its normal RPC POST transport.
/// These annotations only control the semantic OpenAPI/Swagger operation.
class OpenApiMethod {
  final String method;
  final String? summary;
  final Type? response;

  const OpenApiMethod(
    this.method, {
    this.summary,
    this.response,
  });

  const OpenApiMethod.get({
    this.summary,
    this.response,
  }) : method = 'GET';

  const OpenApiMethod.post({
    this.summary,
    this.response,
  }) : method = 'POST';

  const OpenApiMethod.put({
    this.summary,
    this.response,
  }) : method = 'PUT';

  const OpenApiMethod.patch({
    this.summary,
    this.response,
  }) : method = 'PATCH';

  const OpenApiMethod.delete({
    this.summary,
    this.response,
  }) : method = 'DELETE';
}

/// Documents the annotated Serverpod endpoint method as a GET operation.
class Get extends OpenApiMethod {
  const Get({
    super.summary,
    super.response,
  }) : super.get();
}

/// Documents the annotated Serverpod endpoint method as a POST operation.
class Post extends OpenApiMethod {
  const Post({
    super.summary,
    super.response,
  }) : super.post();
}

/// Documents the annotated Serverpod endpoint method as a PUT operation.
class Put extends OpenApiMethod {
  const Put({
    super.summary,
    super.response,
  }) : super.put();
}

/// Documents the annotated Serverpod endpoint method as a PATCH operation.
class Patch extends OpenApiMethod {
  const Patch({
    super.summary,
    super.response,
  }) : super.patch();
}

/// Documents the annotated Serverpod endpoint method as a DELETE operation.
class Delete extends OpenApiMethod {
  const Delete({
    super.summary,
    super.response,
  }) : super.delete();
}
