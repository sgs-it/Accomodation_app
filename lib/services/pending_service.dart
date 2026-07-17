// lib/services/pending_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingChange {
  final String id;
  final String submittedBy;
  final String staffName;
  final String changeType;
  final String? targetTable;
  final String? targetId;
  final Map<String, dynamic> payload;
  final String status; // pending | approved | rejected
  final String? adminNote;
  final DateTime createdAt;

  PendingChange({
    required this.id,
    required this.submittedBy,
    required this.staffName,
    required this.changeType,
    this.targetTable,
    this.targetId,
    required this.payload,
    required this.status,
    this.adminNote,
    required this.createdAt,
  });

  factory PendingChange.fromJson(Map<String, dynamic> j) => PendingChange(
        id: j['id'] as String,
        submittedBy: j['submitted_by'] as String,
        staffName: j['staff_name'] as String? ?? 'Unknown',
        changeType: j['change_type'] as String,
        targetTable: j['target_table'] as String?,
        targetId: j['target_id'] as String?,
        payload: Map<String, dynamic>.from(j['payload'] as Map? ?? {}),
        status: j['status'] as String,
        adminNote: j['admin_note'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class PendingService {
  final _client = Supabase.instance.client;

  /// Staff submits any change for admin approval
  Future<void> submitChange({
    required String staffName,
    required String changeType,
    String? targetTable,
    String? targetId,
    required Map<String, dynamic> payload,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _client.from('pending_changes').insert({
      'submitted_by': user.id,
      'staff_name': staffName,
      'change_type': changeType,
      'target_table': targetTable,
      'target_id': targetId,
      'payload': payload,
      'status': 'pending',
    });

    try {
      final String typeDisplay = changeType == 'leave_request' ? 'Leave' : 'Room Shift';
      await _client.functions.invoke(
        'notify_admins',
        body: {
          'title': 'New $typeDisplay Request',
          'body': 'Staff member <b>$staffName</b> has submitted a new $typeDisplay request.<br/><br/>Please review it in the Admin Dashboard.'
        },
      );
    } catch (e) {
      debugPrint('Error sending admin notification: $e');
    }
  }

  /// Get all pending changes (admin sees all, staff sees their own)
  Future<List<PendingChange>> getAll({String? status}) async {
    var query = _client
        .from('pending_changes')
        .select()
        .order('created_at', ascending: false);

    final data = await query;
    var list = data.map((j) => PendingChange.fromJson(j)).toList();
    if (status != null) {
      list = list.where((c) => c.status == status).toList();
    }
    return list;
  }

  /// Get pending changes submitted by the current user
  Future<List<PendingChange>> getMyChanges() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final data = await _client
        .from('pending_changes')
        .select()
        .eq('submitted_by', user.id)
        .order('created_at', ascending: false);
    return data.map((j) => PendingChange.fromJson(j)).toList();
  }

  Future<int> getPendingCount() async {
    final data = await _client
        .from('pending_changes')
        .select()
        .eq('status', 'pending');
    return data.length;
  }

  /// Get approved leave requests for a specific staff
  Future<List<PendingChange>> getApprovedLeavesForStaff(String staffId) async {
    final data = await _client
        .from('pending_changes')
        .select()
        .eq('status', 'approved')
        .eq('change_type', 'leave_request')
        .eq('target_id', staffId)
        .order('created_at', ascending: false);
    return data.map((j) => PendingChange.fromJson(j)).toList();
  }

  /// Admin approves a change — applies it to the target table
  Future<void> approve(PendingChange change, {String? note}) async {
    // Apply the change to the real table if applicable
    if (change.targetTable != null && change.targetId != null && change.payload.isNotEmpty) {
      Map<String, dynamic> updatePayload = {};

      if (change.changeType == 'leave_request' && change.targetTable == 'staff') {
        updatePayload = {'status': 'On Leave'};
        final assignResp = await _client
            .from('bed_assignments')
            .select('bed_id')
            .eq('staff_id', change.targetId!);
        
        if ((assignResp as List).isNotEmpty) {
          for (final assignment in assignResp) {
            final bedId = assignment['bed_id'] as String;
            if (change.payload['leave_type'] == 'Annual leave') {
              await _client.from('beds').update({'status': 'VACANT'}).eq('id', bedId);
            } else {
              await _client.from('beds').update({'status': 'VACATION'}).eq('id', bedId);
            }
          }
          if (change.payload['leave_type'] == 'Annual leave') {
            await _client.from('bed_assignments').delete().eq('staff_id', change.targetId!);
          }
        }
      } else if (change.changeType == 'shift_request' && change.targetTable == 'staff') {
        final newBedId = change.payload['new_bed_id'] as String?;
        final currentBedId = change.payload['current_bed_id'] as String?;
        final staffId = change.targetId!;
        final adminId = _client.auth.currentUser?.id;

        if (newBedId != null) {
          // Remove from old bed if they had one
          if (currentBedId != null) {
            await _client.from('bed_assignments').delete().eq('bed_id', currentBedId);
            await _client.from('beds').update({'status': 'VACANT'}).eq('id', currentBedId);
          }
          
          // Assign to new bed
          await _client.from('bed_assignments').delete().eq('bed_id', newBedId);
          await _client.from('bed_assignments').insert({
            'bed_id': newBedId,
            'staff_id': staffId,
          });
          await _client.from('beds').update({'status': 'FULL'}).eq('id', newBedId);

          // Log in shift_history
          await _client.from('shift_history').insert({
            'staff_id': staffId,
            'from_bed_id': currentBedId,
            'to_bed_id': newBedId,
            'shift_date': DateTime.now().toIso8601String().split('T').first,
            'reason': 'Approved shift request: ${change.payload['reason'] ?? ''}',
            'created_by': adminId,
          });
        }
      } else {
        // Clean out metadata keys if any
        updatePayload = Map.from(change.payload)
          ..removeWhere((k, v) => k == 'staff_name' || k == 'staff_id' || k == 'reason');
      }

      if (updatePayload.isNotEmpty) {
        await _client
            .from(change.targetTable!)
            .update(updatePayload)
            .eq('id', change.targetId!);
      }
    }

    await _client.from('pending_changes').update({
      'status': 'approved',
      'admin_note': note,
    }).eq('id', change.id);
  }

  /// Admin rejects a change
  Future<void> reject(PendingChange change, {required String reason}) async {
    await _client.from('pending_changes').update({
      'status': 'rejected',
      'admin_note': reason,
    }).eq('id', change.id);
  }
}
