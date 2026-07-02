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

    final stats = await _getAllBedStats();

    final enriched = <RoomModel>[];
    for (final room in rooms) {
      final roomStats = stats[room.id] ?? {'total': 0, 'occupied': 0};
      enriched.add(room.copyWith(
        occupiedCount: roomStats['occupied'],
        actualBedsCount: roomStats['total'],
      ));
    }
    return enriched;
  }

  Future<List<RoomModel>> getAll() async {
    final response = await _client
        .from('rooms')
        .select()
        .order('location_id')
        .order('room_number');

    final rooms = (response as List)
        .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final stats = await _getAllBedStats();
    
    final enriched = <RoomModel>[];
    for (final room in rooms) {
      final roomStats = stats[room.id] ?? {'total': 0, 'occupied': 0};
      enriched.add(room.copyWith(
        occupiedCount: roomStats['occupied'],
        actualBedsCount: roomStats['total'],
      ));
    }
    return enriched;
  }

  Future<Map<String, Map<String, int>>> _getAllBedStats() async {
    final resp = await _client
        .from('beds')
        .select('room_id, status');
        
    final Map<String, Map<String, int>> stats = {};
    for (var b in (resp as List)) {
      final rId = b['room_id'] as String;
      final status = b['status'] as String;
      
      stats.putIfAbsent(rId, () => {'total': 0, 'occupied': 0});
      stats[rId]!['total'] = stats[rId]!['total']! + 1;
      
      if (status == 'FULL' || status == 'VACATION') {
        stats[rId]!['occupied'] = stats[rId]!['occupied']! + 1;
      }
    }
    return stats;
  }

  Future<RoomModel> create(RoomModel room) async {
    final response = await _client
        .from('rooms')
        .insert(room.toJson())
        .select()
        .single();
    return RoomModel.fromJson(response);

  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    await _client.from('rooms').update(updates).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('rooms').delete().eq('id', id);
  }
}
