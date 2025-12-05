class Shop {
  Shop({
    this.id,
    required this.name,
    this.latitude,
    this.longitude,
  });

  final int? id;
  final String name;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'] as int?,
      name: map['name'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}
