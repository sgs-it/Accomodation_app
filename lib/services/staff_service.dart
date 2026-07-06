// lib/services/staff_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/staff.dart';

class StaffService {
  final _client = Supabase.instance.client;

  Future<List<StaffModel>> getAll({String? search, String? status, String? locationId}) async {
    var query = _client.from('staff').select('*, bed_assignments(beds(bed_code, rooms(locations(name))))');

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
              s.staffId.toLowerCase().contains(q) ||
              (s.currentBedCode?.toLowerCase().contains(q) ?? false) ||
              (s.currentLocationName?.toLowerCase().contains(q) ?? false))
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
    // 1. Get the staff to find their auth_user_id and bed assignment
    final staffResp = await _client.from('staff').select('auth_user_id').eq('id', id).maybeSingle();
    
    // 2. Unassign from bed and mark bed as vacant
    final assignResp = await _client.from('bed_assignments').select('bed_id').eq('staff_id', id).maybeSingle();
    if (assignResp != null) {
      final bedId = assignResp['bed_id'];
      // Delete assignment
      await _client.from('bed_assignments').delete().eq('staff_id', id);
      // Make bed vacant
      await _client.from('beds').update({'status': 'VACANT'}).eq('id', bedId);
    }

    // 3. Delete any pending requests and shift history
    await _client.from('pending_changes').delete().eq('target_id', id);
    await _client.from('shift_history').delete().eq('staff_id', id);
    
    // 4. Delete from staff
    await _client.from('staff').delete().eq('id', id);
    
    // 5. Delete from user_roles and auth.users
    if (staffResp != null && staffResp['auth_user_id'] != null) {
       await _client.from('user_roles').delete().eq('user_id', staffResp['auth_user_id']);
       // Invoke the secure Postgres RPC to delete the authentication credentials
       await _client.rpc('delete_user_account', params: {'target_user_id': staffResp['auth_user_id']});
    }
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
