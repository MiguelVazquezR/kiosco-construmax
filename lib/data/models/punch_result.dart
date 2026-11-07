/// Successful punch returned by `POST /punch` and `POST /face-punch`.
class PunchResult {
  const PunchResult({
    required this.userName,
    required this.employeeNumber,
    required this.type,
    required this.typeLabel,
    required this.punchedAt,
    required this.dateLabel,
    this.suggestedNext,
    this.suggestedNextLabel,
    this.similarity,
  });

  final String userName;
  final String employeeNumber;
  final String type;
  final String typeLabel;

  /// `HH:mm`
  final String punchedAt;

  /// `dd/MM/yyyy`
  final String dateLabel;

  final String? suggestedNext;
  final String? suggestedNextLabel;

  /// 0-100 percentage reported by AWS Rekognition (never shown to the
  /// collaborator).
  final double? similarity;

  factory PunchResult.fromJson(Map<String, dynamic> json) {
    return PunchResult(
      userName: '${json['user_name'] ?? ''}',
      employeeNumber: '${json['employee_number'] ?? ''}',
      type: '${json['type'] ?? ''}',
      typeLabel: '${json['type_label'] ?? ''}',
      punchedAt: '${json['punched_at'] ?? ''}',
      dateLabel: '${json['date_label'] ?? ''}',
      suggestedNext: _nullableText(json['suggested_next']),
      suggestedNextLabel: _nullableText(json['suggested_next_label']),
      similarity: json['similarity'] is num
          ? (json['similarity'] as num).toDouble()
          : double.tryParse('${json['similarity'] ?? ''}'),
    );
  }

  static String? _nullableText(dynamic value) {
    if (value == null) return null;
    final text = '$value';
    return text.isEmpty ? null : text;
  }
}
