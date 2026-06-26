// lib/models/bed.dart

import 'staff.dart';

class BedModel {
  final String id;
  final String bedCode;
  final String roomId;
  final int bedNumber;
  final String position; // LB, UB, SB
  final String status;   // FULL, VACANT, VACATION, MAINTENANCE
  final DateTime? createdAt;

  // Filled by join
  final StaffModel? occupant;
  final String? assignmentId;

  const BedModel({
    required this.id,
    required this.bedCode,
    required this.roomId,
    required this.bedNumber,
    required this.position,
    required this.status,
    this.createdAt,
    this.occupant,
    this.assignmentId,
  });

  bool get isOccupied => status == 'FULL' || status == 'VACATION';
  bool get isVacant => status == 'VACANT';

  factory BedModel.fromJson(Map<String, dynamic> json) {
    StaffModel? occupant;
    String? assignmentId;

    // Handle joined bed_assignments → staff
    if (json['bed_assignments'] != null) {
      final assignments = json['bed_assignments'] as List;
      if (assignments.isNotEmpty) {
        final assignment = assignments.first as Map<String, dynamic>;
        assignmentId = assignment['id'] as String?;
        if (assignment['staff'] != null) {
          occupant = StaffModel.fromJson(assignment['staff'] as Map<String, dynamic>);
        }
      }
    }

    return BedModel(
      id: json['id'] as String,
      bedCode: json['bed_code'] as String,
      roomId: json['room_id'] as String,
      bedNumber: json['bed_number'] as int,
      position: json['position'] as String,
      status: json['status'] as String? ?? 'VACANT',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      occupant: occupant,
      assignmentId: assignmentId,
    );
  }

  Map<String, dynamic> toJson() => {
        'bed_code': bedCode,
        'room_id': roomId,
        'bed_number': bedNumber,
        'position': position,
        'status': status,
      };

  BedModel copyWith({String? status, StaffModel? occupant, String? assignmentId}) {
    return BedModel(
      id: id,
      bedCode: bedCode,
      roomId: roomId,
      bedNumber: bedNumber,
      position: position,
      status: status ?? this.status,
      createdAt: createdAt,
      occupant: occupant ?? this.occupant,
      assignmentId: assignmentId ?? this.assignmentId,
    );
  }
}
