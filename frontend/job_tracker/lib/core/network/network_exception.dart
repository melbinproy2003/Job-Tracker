class NetworkException implements Exception {
  NetworkException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'NetworkException($statusCode): $message';
}
