// lib/services/location_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/location.dart';

class LocationService {
  final _client = Supabase.instance.client;

  Future<List<LocationModel>> getAll() async {
    final response = await _client
        .from('locations')
        .select()
        .order('name');

    final locations = (response as List)
        .map((e) => LocationModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Enrich with bed stats
    final enriched = <LocationModel>[];
    for (final loc in locations) {
      final stats = await _getBedStats(loc.id);
      enriched.add(loc.copyWith(
        totalBeds: stats['total'] ?? 0,
        occupiedBeds: stats['occupied'] ?? 0,
        vacantBeds: stats['vacant'] ?? 0,
        onLeaveBeds: stats['on_leave'] ?? 0,
      ));
    }
    return enriched;
  }

  Future<Map<String, int>> _getBedStats(String locationId) async {
    // Get all rooms for this location, then count beds
    final roomsResp = await _client
        .from('rooms')
        .select('id')
        .eq('location_id', locationId);

    final roomIds = (roomsResp as List).map((r) => (r as Map<String, dynamic>)['id'] as String).toList();
    if (roomIds.isEmpty) {
      return {'total': 0, 'occupied': 0, 'vacant': 0, 'on_leave': 0};
    }

    final bedsResp = await _client
        .from('beds')
        .select('status')
        .inFilter('room_id', roomIds);

    final beds = bedsResp as List;
    int total = beds.length;
    int occupied = beds.where((b) => b['status'] == 'FULL').length;
    int vacant = beds.where((b) => b['status'] == 'VACANT').length;
    int onLeave = beds.where((b) => b['status'] == 'VACATION').length;

    return {'total': total, 'occupied': occupied, 'vacant': vacant, 'on_leave': onLeave};
  }

  Future<LocationModel> create(LocationModel location) async {
    final response = await _client
        .from('locations')
        .insert(location.toJson())
        .select()
        .single();
    return LocationModel.fromJson(response);
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    await _client.from('locations').update(updates).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('locations').delete().eq('id', id);
  }
}
