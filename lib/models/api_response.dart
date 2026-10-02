/// Custom exceptions and standard responses for API interactions.
library;

/// Base API exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// Thrown when API returns HTTP 429 Too Many Requests
class RateLimitException extends ApiException {
  RateLimitException({String message = 'API rate limit reached. Please wait a moment.'})
      : super(message, statusCode: 429);
}

/// Thrown when network connection fails or request times out
class NetworkException extends ApiException {
  NetworkException({String message = 'Unable to reach network. Please check your internet connection.'})
      : super(message, statusCode: null);
}

/// Thrown when an expected resource is empty or not found
class EmptyResultException extends ApiException {
  EmptyResultException({String message = 'No tracks found matching your query.'})
      : super(message, statusCode: 404);
}
