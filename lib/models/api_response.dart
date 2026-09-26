/// Custom exceptions and standard responses for Audius API interactions.

/// Base API exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// Thrown when Audius API returns HTTP 429 Too Many Requests
class RateLimitException extends ApiException {
  RateLimitException({String message = 'Audius API rate limit reached. Please wait a moment.'})
      : super(message, statusCode: 429);
}

/// Thrown when network connection fails or request times out
class NetworkException extends ApiException {
  NetworkException({String message = 'Unable to reach Audius network. Please check your connection.'})
      : super(message, statusCode: null);
}

/// Thrown when an expected resource is empty or not found
class EmptyResultException extends ApiException {
  EmptyResultException({String message = 'No tracks found matching your query.'})
      : super(message, statusCode: 404);
}
