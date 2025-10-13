/// Location Model
///
/// Lightweight GeoPoint-like structure for serialization compatibility.
/// Avoids Firebase GeoPoint which doesn't serialize well in all contexts.
library;

class GeoPointLike {
  final double lat;
  final double lng;

  const GeoPointLike({required this.lat, required this.lng});

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng};

  factory GeoPointLike.fromMap(Map<String, dynamic> m) => GeoPointLike(
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
  );

  @override
  String toString() => 'GeoPointLike(lat: $lat, lng: $lng)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPointLike &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng;

  @override
  int get hashCode => lat.hashCode ^ lng.hashCode;
}
