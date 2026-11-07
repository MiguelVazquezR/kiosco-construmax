/// Single error type the UI understands, so screens never parse raw JSON.
class ApiError implements Exception {
  const ApiError({
    required this.statusCode,
    required this.message,
    this.fieldErrors = const {},
  });

  /// HTTP status, or `0` when the request never reached the server
  /// (no network, timeout, DNS failure).
  final int statusCode;

  final String message;

  /// Laravel validation errors: `{"employee_number": ["..."]}`.
  final Map<String, List<String>> fieldErrors;

  bool get isUnreachable => statusCode == 0;
  bool get isThrottled => statusCode == 429;
  bool get isValidation => statusCode == 422;

  /// First message for [field], falling back to the global [message].
  String messageFor(String field) {
    final messages = fieldErrors[field];
    if (messages != null && messages.isNotEmpty) return messages.first;
    return message;
  }

  static const String unreachableMessage =
      'No se pudo conectar con el servidor.';
  static const String throttleMessage =
      'Demasiados intentos. Espera unos segundos e intenta de nuevo.';

  factory ApiError.unreachable([String? message]) => ApiError(
    statusCode: 0,
    message: message ?? unreachableMessage,
  );

  factory ApiError.throttled([String? message]) => ApiError(
    statusCode: 429,
    message: message ?? throttleMessage,
  );

  /// Builds an error from a decoded JSON body (or any other payload).
  factory ApiError.fromResponse(int statusCode, dynamic data) {
    if (statusCode == 429) return ApiError.throttled();

    final Map<String, List<String>> fieldErrors = {};
    String? message;

    if (data is Map) {
      final rawMessage = data['message'];
      if (rawMessage is String && rawMessage.trim().isNotEmpty) {
        message = rawMessage;
      }

      final rawErrors = data['errors'];
      if (rawErrors is Map) {
        for (final entry in rawErrors.entries) {
          final value = entry.value;
          if (value is List) {
            fieldErrors['${entry.key}'] = value
                .map((item) => '$item')
                .where((item) => item.isNotEmpty)
                .toList();
          } else if (value is String) {
            fieldErrors['${entry.key}'] = [value];
          }
        }
      }
    } else if (data is String && data.trim().isNotEmpty) {
      message = data;
    }

    message ??= fieldErrors.values
        .expand((messages) => messages)
        .cast<String?>()
        .firstWhere((item) => item != null, orElse: () => null);

    return ApiError(
      statusCode: statusCode,
      message: message ?? _defaultMessage(statusCode),
      fieldErrors: fieldErrors,
    );
  }

  static String _defaultMessage(int statusCode) {
    if (statusCode >= 500) return unreachableMessage;
    return 'No se pudo completar el registro. Intenta de nuevo.';
  }

  @override
  String toString() => 'ApiError($statusCode): $message';
}
