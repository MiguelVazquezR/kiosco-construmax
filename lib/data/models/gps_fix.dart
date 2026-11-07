/// A GPS fix used as mandatory evidence for a punch.
class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (accuracy != null) 'location_accuracy': accuracy,
  };
}
