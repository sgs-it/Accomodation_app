// lib/models/staff.dart

class StaffModel {
  final String id;
  final String staffId;
  final String name;
  final String status;
  final String? phone;
  final String? nationality;
  final DateTime? createdAt;

  // Filled by join
  final String? currentBedCode;
  final String? currentRoomCode;

  const StaffModel({
    required this.id,
    required this.staffId,
    required this.name,
    required this.status,
    this.phone,
    this.nationality,
    this.createdAt,
    this.currentBedCode,
    this.currentRoomCode,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'Active',
      phone: json['phone'] as String?,
      nationality: json['nationality'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'staff_id': staffId,
        'name': name,
        'status': status,
        'phone': phone,
        'nationality': nationality,
      };

  StaffModel copyWith({
    String? status,
    String? currentBedCode,
    String? currentRoomCode,
  }) {
    return StaffModel(
      id: id,
      staffId: staffId,
      name: name,
      status: status ?? this.status,
      phone: phone,
      nationality: nationality,
      createdAt: createdAt,
      currentBedCode: currentBedCode ?? this.currentBedCode,
      currentRoomCode: currentRoomCode ?? this.currentRoomCode,
    );
  }
}
