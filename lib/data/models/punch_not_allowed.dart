import 'api_error.dart';
import 'punch_option.dart';

/// Business rejection `422 attendance_punch_not_allowed`: the requested
/// movement does not follow the daily attendance sequence.
class PunchNotAllowed {
  const PunchNotAllowed({
    required this.type,
    required this.message,
    this.lastRegisteredAt,
    this.options = const [],
  });

  final String type;
  final String message;
  final String? lastRegisteredAt;
  final List<PunchOption> options;

  static const String fallbackMessage =
      'Ese registro ya se realizó o no está disponible en este momento.';
  static const String hint =
      'Selecciona otro tipo de registro para continuar.';

  String get title => lastRegisteredAt != null
      ? 'Ese registro ya se realizó'
      : 'No se pudo registrar ese movimiento';

  /// The rejected option, so the dialog can show its label.
  PunchOption? get rejectedOption {
    for (final option in options) {
      if (option.type == type) return option;
    }

    return null;
  }

  String get typeLabel => rejectedOption?.label ?? '';

  /// Same rule as the web kiosk: do not repeat the hint when the server
  /// message already tells the collaborator to pick another type.
  bool get showsHint => !message.toLowerCase().contains('selecciona otro');

  factory PunchNotAllowed.fromApiError(ApiError error) {
    final data = error.responseData ?? const <String, dynamic>{};
    final options = PunchOption.listFromJson(data['options']);
    final type = '${data['type'] ?? ''}';

    PunchOption? rejected;
    for (final option in options) {
      if (option.type == type) {
        rejected = option;
        break;
      }
    }

    return PunchNotAllowed(
      type: type,
      message: _text(data['message']) ?? error.message,
      lastRegisteredAt:
          _text(data['last_registered_at']) ?? rejected?.lastRegisteredAt,
      options: options,
    );
  }

  /// Used when the collaborator taps a disabled type: the server would answer
  /// exactly the same, so the kiosk shows it without spending a request.
  factory PunchNotAllowed.fromOption(
    PunchOption option, {
    required List<PunchOption> options,
  }) {
    return PunchNotAllowed(
      type: option.type,
      message: option.reason ?? fallbackMessage,
      lastRegisteredAt: option.lastRegisteredAt,
      options: options,
    );
  }

  static String? _text(dynamic value) {
    if (value == null) return null;

    final text = '$value';

    return text.isEmpty ? null : text;
  }
}
