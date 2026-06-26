// lib/models/room.dart

class RoomModel {
  final String id;
  final String roomCode;
  final String locationId;
  final String roomNumber;
  final int capacity;
  final DateTime? contractExpiry;
  final String? notes;
  final DateTime? createdAt;

  // Filled by service
  final int occupiedCount;

  const RoomModel({
    required this.id,
    required this.roomCode,
    required this.locationId,
    required this.roomNumber,
    required this.capacity,
    this.contractExpiry,
    this.notes,
    this.createdAt,
    this.occupiedCount = 0,
  });

  int get vacantCount => capacity - occupiedCount;
  double get occupancyRate => capacity > 0 ? occupiedCount / capacity : 0;

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      roomCode: json['room_code'] as String,
      locationId: json['location_id'] as String,
      roomNumber: json['room_number'] as String,
      capacity: json['capacity'] as int,
      contractExpiry: json['contract_expiry'] != null
          ? DateTime.parse(json['contract_expiry'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'room_code': roomCode,
        'location_id': locationId,
        'room_number': roomNumber,
        'capacity': capacity,
        'contract_expiry': contractExpiry?.toIso8601String().split('T').first,
        'notes': notes,
      };

  RoomModel copyWith({int? occupiedCount}) {
    return RoomModel(
      id: id,
      roomCode: roomCode,
      locationId: locationId,
      roomNumber: roomNumber,
      capacity: capacity,
      contractExpiry: contractExpiry,
      notes: notes,
      createdAt: createdAt,
      occupiedCount: occupiedCount ?? this.occupiedCount,
    );
  }
}
