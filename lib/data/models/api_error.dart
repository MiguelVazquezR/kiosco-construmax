/// Single error type the UI understands, so screens never parse raw JSON.
class ApiError implements Exception {
  const ApiError({
    required this.statusCode,
    required this.message,
    this.fieldErrors = const {},
    this.code,
    this.responseData,
  });

  /// HTTP status, or `0` when the request never reached the server
  /// (no network, timeout, DNS failure).
  final int statusCode;

  final String message;

  /// Laravel validation errors: `{"employee_number": ["..."]}`.
  final Map<String, List<String>> fieldErrors;

  /// Machine-readable code sent by the backend, e.g.
  /// `attendance_punch_not_allowed`.
  final String? code;

  /// Decoded JSON body, kept so a screen can build a rich dialog out of a
  /// business error without parsing the raw JSON twice.
  final Map<String, dynamic>? responseData;

  static const String punchNotAllowedCode = 'attendance_punch_not_allowed';

  /// The daily attendance sequence rejected the movement (§4): show the
  /// "already registered" dialog instead of a generic error.
  bool get isPunchNotAllowed => code == punchNotAllowedCode;

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
    Map<String, dynamic>? payload;
    String? code;

    if (data is Map) {
      payload = Map<String, dynamic>.from(data);

      final rawCode = data['code'];
      if (rawCode is String && rawCode.trim().isNotEmpty) {
        code = rawCode;
      }

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
      code: code,
      responseData: payload,
    );
  }

  static String _defaultMessage(int statusCode) {
    if (statusCode >= 500) return unreachableMessage;
    return 'No se pudo completar el registro. Intenta de nuevo.';
  }

  @override
  String toString() => 'ApiError($statusCode): $message';
}
