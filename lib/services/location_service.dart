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

    // Optimize: fetch all beds with their location_id in a single query
    final bedsResp = await _client
        .from('beds')
        .select('status, room_id, rooms!inner(location_id)');
        
    final Map<String, Map<String, int>> locStats = {};
    for (final loc in locations) {
      locStats[loc.id] = {'total': 0, 'occupied': 0, 'vacant': 0, 'on_leave': 0};
    }
    
    for (var b in (bedsResp as List)) {
      final locId = b['rooms']?['location_id'] as String?;
      if (locId == null || !locStats.containsKey(locId)) continue;
      
      final status = b['status'] as String? ?? 'VACANT';
      locStats[locId]!['total'] = locStats[locId]!['total']! + 1;
      
      if (status == 'FULL') {
        locStats[locId]!['occupied'] = locStats[locId]!['occupied']! + 1;
      } else if (status == 'VACANT') {
        locStats[locId]!['vacant'] = locStats[locId]!['vacant']! + 1;
      } else if (status == 'VACATION') {
        locStats[locId]!['on_leave'] = locStats[locId]!['on_leave']! + 1;
        // Occupied includes VACATION beds in export and dashboard logic
        locStats[locId]!['occupied'] = locStats[locId]!['occupied']! + 1;
      }
    }

    final enriched = <LocationModel>[];
    for (final loc in locations) {
      final stats = locStats[loc.id]!;
      enriched.add(loc.copyWith(
        totalBeds: stats['total'] ?? 0,
        occupiedBeds: stats['occupied'] ?? 0,
        vacantBeds: stats['vacant'] ?? 0,
        onLeaveBeds: stats['on_leave'] ?? 0,
      ));
    }
    return enriched;
  }

  Future<LocationModel> create(LocationModel location) async {
    final response = await _client
        .from('locations')
        .insert(location.toJson())
        .select()
        .single();
    return LocationModel.fromJson(response);
  }

  /// Create location and auto-generate rooms and beds with the custom naming pattern
  Future<void> createWithRoomsAndBeds({
    required LocationModel location,
    required int numRooms,
    required int numBeds,
  }) async {
    // 1. Create Location
    final createdLoc = await create(location);
    
    if (numRooms <= 0 || numBeds <= 0) return;
    
    // 2. Fetch all locations sorted by created_at to calculate 1-based index
    final locsResp = await _client
        .from('locations')
        .select('id')
        .order('created_at', ascending: true);
    
    final locList = (locsResp as List).map((l) => l['id'] as String).toList();
    int locIndex = locList.indexOf(createdLoc.id) + 1;
    if (locIndex <= 0) {
      locIndex = locList.length + 1;
    }
    
    // 3. Find the next global room sequence number
    final roomsResp = await _client.from('rooms').select('room_number');
    int maxSeq = 0;
    for (final r in roomsResp as List) {
      final roomNum = r['room_number'] as String;
      final regExp = RegExp(r'^R\d+(\d{3})$');
      final match = regExp.firstMatch(roomNum);
      if (match != null) {
        final seq = int.tryParse(match.group(1) ?? '');
        if (seq != null && seq > maxSeq) {
          maxSeq = seq;
        }
      }
    }
    int nextRoomSeq = maxSeq + 1;
    
    // 4. Prepare rooms batch insert
    final roomsData = <Map<String, dynamic>>[];
    for (int i = 0; i < numRooms; i++) {
      final currentRoomSeq = nextRoomSeq + i;
      final roomNumStr = currentRoomSeq.toString().padLeft(3, '0');
      // Room number: R<LocationIndex><RoomSeq> e.g. R6031
      final roomNumber = 'R$locIndex$roomNumStr';
      // Room code: <LocationId>-<LocationIndex><RoomSeq> e.g. IN-6031
      final roomCode = '${createdLoc.id}-$locIndex$roomNumStr';
      
      roomsData.add({
        'room_code': roomCode,
        'location_id': createdLoc.id,
        'room_number': roomNumber,
        'capacity': numBeds,
      });
    }
    
    // Batch insert rooms
    final roomsResponse = await _client
        .from('rooms')
        .insert(roomsData)
        .select('id, room_number, room_code');
        
    final createdRooms = roomsResponse as List;
    
    // 5. Prepare beds batch insert
    final bedsData = <Map<String, dynamic>>[];
    int globalBedCounter = 1;
    for (final room in createdRooms) {
      final roomId = room['id'] as String;
      final roomNumber = room['room_number'] as String;
      
      for (int b = 0; b < numBeds; b++) {
        final bedSeqStr = globalBedCounter.toString().padLeft(3, '0');
        // Bed code: <RoomNumber>-<LocationBedSequence> e.g. R6031-001
        final bedCode = '$roomNumber-$bedSeqStr';
        
        String position;
        if (numBeds == 1) {
          position = 'SB';
        } else {
          position = (b % 2 == 0) ? 'LB' : 'UB';
        }
        
        bedsData.add({
          'bed_code': bedCode,
          'room_id': roomId,
          'bed_number': b + 1,
          'position': position,
          'status': 'VACANT',
        });
        
        globalBedCounter++;
      }
    }
    
    // Batch insert beds
    await _client.from('beds').insert(bedsData);
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    await _client.from('locations').update(updates).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('locations').delete().eq('id', id);
  }
}
