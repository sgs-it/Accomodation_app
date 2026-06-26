// lib/services/room_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room.dart';

class RoomService {
  final _client = Supabase.instance.client;

  Future<List<RoomModel>> getByLocation(String locationId) async {
    final response = await _client
        .from('rooms')
        .select()
        .eq('location_id', locationId)
        .order('room_number');

    final rooms = (response as List)
        .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Enrich with occupied count
    final enriched = <RoomModel>[];
    for (final room in rooms) {
      final count = await _getOccupiedCount(room.id);
      enriched.add(room.copyWith(occupiedCount: count));
    }
    return enriched;
  }

  Future<List<RoomModel>> getAll() async {
    final response = await _client
        .from('rooms')
        .select()
        .order('location_id')
        .order('room_number');

    return (response as List)
        .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> _getOccupiedCount(String roomId) async {
    final resp = await _client
        .from('beds')
        .select('id')
        .eq('room_id', roomId)
        .inFilter('status', ['FULL', 'VACATION']);
    return (resp as List).length;
  }

  Future<RoomModel> create(RoomModel room) async {
    final response = await _client
        .from('rooms')
        .insert(room.toJson())
        .select()
        .single();
    return RoomModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    await _client.from('rooms').update(updates).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('rooms').delete().eq('id', id);
  }
}
