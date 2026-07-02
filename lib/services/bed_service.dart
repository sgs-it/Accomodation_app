// lib/services/bed_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bed.dart';

class BedService {
  final _client = Supabase.instance.client;

  Future<List<BedModel>> getByRoom(String roomId) async {
    final response = await _client
        .from('beds')
        .select('*, bed_assignments(id, staff(*))')
        .eq('room_id', roomId)
        .order('bed_number')
        .order('position');

    return (response as List)
        .map((e) => BedModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BedModel> create(BedModel bed) async {
    final response = await _client
        .from('beds')
        .insert(bed.toJson())
        .select()
        .single();
    return BedModel.fromJson(response);

  }

  Future<void> updateStatus(String bedId, String status) async {
    await _client.from('beds').update({'status': status}).eq('id', bedId);
  }

  Future<void> updateBedCode(String bedId, String bedCode) async {
    await _client.from('beds').update({'bed_code': bedCode}).eq('id', bedId);
  }

  Future<void> delete(String bedId) async {
    await _client.from('beds').delete().eq('id', bedId);
  }

  /// Assign a staff member to a bed (creates bed_assignment + updates bed status)
  Future<void> assignStaff({
    required String bedId,
    required String staffId,
    required String bedStatus, // 'FULL' or 'VACATION'
  }) async {
    // Remove any existing assignment for this bed first
    await _client.from('bed_assignments').delete().eq('bed_id', bedId);

    // Create new assignment
    await _client.from('bed_assignments').insert({
      'bed_id': bedId,
      'staff_id': staffId,
    });

    // Update bed status
    await _client.from('beds').update({'status': bedStatus}).eq('id', bedId);
  }

  /// Remove staff from a bed (deletes assignment + sets bed VACANT)
  Future<void> removeStaff(String bedId) async {
    await _client.from('bed_assignments').delete().eq('bed_id', bedId);
    await _client.from('beds').update({'status': 'VACANT'}).eq('id', bedId);
  }

  /// Get all vacant beds (for dropdown when assigning)
  Future<List<BedModel>> getVacantBeds() async {
    final response = await _client
        .from('beds')
        .select()
        .eq('status', 'VACANT')
        .order('bed_code');

    return (response as List)
        .map((e) => BedModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get all beds, optionally filtered by status, with joined room/location and occupant data
  Future<List<BedModel>> getAllFiltered({String? status}) async {
    var query = _client
        .from('beds')
        .select('*, room:rooms(*, location:locations(*)), bed_assignments(id, staff(*))');

    if (status != null && status != 'all') {
      query = query.eq('status', status.toUpperCase());
    }

    final response = await query.order('bed_code');

    return (response as List)
        .map((e) => BedModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
