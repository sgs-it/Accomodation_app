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
  final String? currentLocationName;

  const StaffModel({
    required this.id,
    required this.staffId,
    required this.name,
    required this.status,
    this.phone,
    this.nationality,
    this.createdAt,
    this.currentBedCode,
    this.currentLocationName,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    String? bedCode;
    String? locName;
    if (json['bed_assignments'] != null && (json['bed_assignments'] as List).isNotEmpty) {
      final assign = (json['bed_assignments'] as List).first as Map<String, dynamic>;
      if (assign['beds'] != null) {
        final bed = assign['beds'] as Map<String, dynamic>;
        bedCode = bed['bed_code'] as String?;
        if (bed['rooms'] != null) {
          final room = bed['rooms'] as Map<String, dynamic>;
          if (room['locations'] != null) {
            final loc = room['locations'] as Map<String, dynamic>;
            locName = loc['name'] as String?;
          }
        }
      }
    }

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
      currentBedCode: bedCode,
      currentLocationName: locName,
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
    String? currentLocationName,
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
      currentLocationName: currentLocationName ?? this.currentLocationName,
    );
  }
}
