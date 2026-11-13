/// One punch type of the daily sequence, as reported by the server in
/// `options[]` (`200` payload and `422 attendance_punch_not_allowed`).
class PunchOption {
  const PunchOption({
    required this.type,
    required this.label,
    required this.allowed,
    this.reason,
    this.lastRegisteredAt,
  });

  final String type;
  final String label;
  final bool allowed;

  /// Why the type cannot be registered, already written for the collaborator.
  final String? reason;

  /// `HH:mm` of the last punch of this type today, `null` when never used.
  final String? lastRegisteredAt;

  factory PunchOption.fromJson(Map<String, dynamic> json) {
    return PunchOption(
      type: _text(json['type']) ?? '',
      label: _text(json['label']) ?? '',
      allowed: json['allowed'] == true,
      reason: _text(json['reason']),
      lastRegisteredAt: _text(json['last_registered_at']),
    );
  }

  /// Reads `options[]`; a missing or malformed list yields an empty list.
  static List<PunchOption> listFromJson(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => PunchOption.fromJson(Map<String, dynamic>.from(item)))
        .where((option) => option.type.isNotEmpty)
        .toList();
  }

  static String? _text(dynamic value) {
    if (value == null) return null;

    final text = '$value';

    return text.isEmpty ? null : text;
  }
}
