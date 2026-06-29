// lib/services/staff_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/staff.dart';

class StaffService {
  final _client = Supabase.instance.client;

  Future<List<StaffModel>> getAll({String? search, String? status, String? locationId}) async {
    var query = _client.from('staff').select();

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    final response = await query.order('name');
    var staff = (response as List)
        .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
        .toList();

    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      staff = staff
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.staffId.toLowerCase().contains(q))
          .toList();
    }

    return staff;
  }

  Future<List<StaffModel>> getOnLeave() async {
    final response = await _client
        .from('staff')
        .select()
        .eq('status', 'On Leave')
        .order('name');

    return (response as List)
        .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StaffModel?> getById(String id) async {
    final response = await _client
        .from('staff')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return StaffModel.fromJson(response);

  }

  Future<List<StaffModel>> getUnassigned() async {
    // Staff not in any bed_assignments
    final assignedResp = await _client.from('bed_assignments').select('staff_id');
    final assignedIds = (assignedResp as List).map((a) => a['staff_id'] as String).toList();

    final resp = await _client.from('staff').select().eq('status', 'Active').order('name');
    var all = (resp as List)
        .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
        .toList();

    if (assignedIds.isEmpty) return all;
    return all.where((s) => !assignedIds.contains(s.id)).toList();
  }

  Future<StaffModel> create(StaffModel staff) async {
    final response = await _client
        .from('staff')
        .insert(staff.toJson())
        .select()
        .single();
    return StaffModel.fromJson(response);

  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    await _client.from('staff').update(updates).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('staff').delete().eq('id', id);
  }

  Future<void> markOnLeave(String id) async {
    await _client.from('staff').update({'status': 'On Leave'}).eq('id', id);
    // Update bed status to VACATION
    final assignResp = await _client
        .from('bed_assignments')
        .select('bed_id')
        .eq('staff_id', id)
        .maybeSingle();
    if (assignResp != null) {
      await _client
          .from('beds')
          .update({'status': 'VACATION'})
          .eq('id', assignResp['bed_id'] as String);
    }
  }

  Future<void> markReturned(String id) async {
    await _client.from('staff').update({'status': 'Active'}).eq('id', id);
    // Restore bed to FULL
    final assignResp = await _client
        .from('bed_assignments')
        .select('bed_id')
        .eq('staff_id', id)
        .maybeSingle();
    if (assignResp != null) {
      await _client
          .from('beds')
          .update({'status': 'FULL'})
          .eq('id', assignResp['bed_id'] as String);
    }
  }
}
