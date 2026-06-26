// lib/models/shift_history.dart

class ShiftHistoryModel {
  final String id;
  final String staffId;
  final String? fromBedId;
  final String? toBedId;
  final DateTime shiftDate;
  final String? reason;
  final String? createdBy;
  final DateTime? createdAt;

  // Filled by join
  final String? staffName;
  final String? staffIdCode;
  final String? fromBedCode;
  final String? toBedCode;

  const ShiftHistoryModel({
    required this.id,
    required this.staffId,
    this.fromBedId,
    this.toBedId,
    required this.shiftDate,
    this.reason,
    this.createdBy,
    this.createdAt,
    this.staffName,
    this.staffIdCode,
    this.fromBedCode,
    this.toBedCode,
  });

  factory ShiftHistoryModel.fromJson(Map<String, dynamic> json) {
    return ShiftHistoryModel(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      fromBedId: json['from_bed_id'] as String?,
      toBedId: json['to_bed_id'] as String?,
      shiftDate: DateTime.parse(json['shift_date'] as String),
      reason: json['reason'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      staffName: json['staff'] != null
          ? (json['staff'] as Map<String, dynamic>)['name'] as String?
          : null,
      staffIdCode: json['staff'] != null
          ? (json['staff'] as Map<String, dynamic>)['staff_id'] as String?
          : null,
      fromBedCode: json['from_bed'] != null
          ? (json['from_bed'] as Map<String, dynamic>)['bed_code'] as String?
          : null,
      toBedCode: json['to_bed'] != null
          ? (json['to_bed'] as Map<String, dynamic>)['bed_code'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'staff_id': staffId,
        'from_bed_id': fromBedId,
        'to_bed_id': toBedId,
        'shift_date': shiftDate.toIso8601String().split('T').first,
        'reason': reason,
      };
}
