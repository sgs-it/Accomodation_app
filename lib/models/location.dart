// lib/models/location.dart

class LocationModel {
  final String id;
  final String name;
  final String? managerName;
  final DateTime? createdAt;

  // Computed stats (filled by service)
  final int totalBeds;
  final int occupiedBeds;
  final int vacantBeds;
  final int onLeaveBeds;

  const LocationModel({
    required this.id,
    required this.name,
    this.managerName,
    this.createdAt,
    this.totalBeds = 0,
    this.occupiedBeds = 0,
    this.vacantBeds = 0,
    this.onLeaveBeds = 0,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      managerName: json['manager_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'manager_name': managerName,
      };

  LocationModel copyWith({
    int? totalBeds,
    int? occupiedBeds,
    int? vacantBeds,
    int? onLeaveBeds,
  }) {
    return LocationModel(
      id: id,
      name: name,
      managerName: managerName,
      createdAt: createdAt,
      totalBeds: totalBeds ?? this.totalBeds,
      occupiedBeds: occupiedBeds ?? this.occupiedBeds,
      vacantBeds: vacantBeds ?? this.vacantBeds,
      onLeaveBeds: onLeaveBeds ?? this.onLeaveBeds,
    );
  }
}
