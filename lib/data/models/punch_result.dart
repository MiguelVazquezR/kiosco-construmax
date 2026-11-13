import 'punch_option.dart';

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
    this.options = const [],
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

  /// 0-100 percentage reported by AWS Rekognition, shown to the collaborator
  /// in the success overlay (§6.2).
  final double? similarity;

  /// Daily sequence reported by the server, empty when it did not send it.
  final List<PunchOption> options;

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
      options: PunchOption.listFromJson(json['options']),
    );
  }

  static String? _nullableText(dynamic value) {
    if (value == null) return null;
    final text = '$value';
    return text.isEmpty ? null : text;
  }
}
