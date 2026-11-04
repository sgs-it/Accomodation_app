// lib/services/shift_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shift_history.dart';

class ShiftService {
  final _client = Supabase.instance.client;

  Future<List<ShiftHistoryModel>> getAll({
    String? staffId,
    DateTime? startDate,
    DateTime? endDate,
    bool ascending = false,
  }) async {
    var query = _client
        .from('shift_history')
        .select('*, staff(name, staff_id), from_bed:from_bed_id(bed_code), to_bed:to_bed_id(bed_code)');

    if (staffId != null) {
      query = query.eq('staff_id', staffId);
    }

    // shift_date is a Postgres date: include both selected calendar days.
    if (startDate != null) {
      query = query.gte(
        'shift_date',
        startDate.toIso8601String().split('T').first,
      );
    }
    if (endDate != null) {
      query = query.lte(
        'shift_date',
        endDate.toIso8601String().split('T').first,
      );
    }

    final response = await query.order('shift_date', ascending: ascending);

    return (response as List)
        .map((e) => ShiftHistoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShiftHistoryModel> logShift({
    required String staffId,
    String? fromBedId,
    String? toBedId,
    required DateTime shiftDate,
    String? reason,
  }) async {
    final userId = _client.auth.currentUser?.id;

    final response = await _client
        .from('shift_history')
        .insert({
          'staff_id': staffId,
          'from_bed_id': fromBedId,
          'to_bed_id': toBedId,
          'shift_date': shiftDate.toIso8601String().split('T').first,
          'reason': reason,
          'created_by': userId,
        })
        .select('*, staff(name, staff_id), from_bed:from_bed_id(bed_code), to_bed:to_bed_id(bed_code)')
        .single();

    return ShiftHistoryModel.fromJson(response);

  }

  Future<void> delete(String id) async {
    await _client.from('shift_history').delete().eq('id', id);
  }
}
