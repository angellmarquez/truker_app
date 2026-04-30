library latlong2;

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  double get lat => latitude;
  double get lng => longitude;

  @override
  String toString() => 'LatLng(lat: $latitude, lon: $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          other.runtimeType == runtimeType &&
          other.latitude == latitude &&
          other.longitude == longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}
