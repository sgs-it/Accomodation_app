// lib/services/export_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  final _client = Supabase.instance.client;

  Future<void> exportData() async {
    final excel = Excel.createExcel();
    
    // Rename default sheet to Summary
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Summary');
    final Sheet summarySheet = excel['Summary'];

    // Header for Summary sheet
    summarySheet.appendRow([
      TextCellValue('Room ID'),
      TextCellValue(' '),
      TextCellValue('Room No'),
      TextCellValue('Contract No'),
      TextCellValue('Emirate'),
      TextCellValue('Expiry'),
      TextCellValue('Contract Status'),
      TextCellValue('Capacity'),
      TextCellValue('Occupied'),
      TextCellValue('Available'),
      TextCellValue('Managed by'),
    ]);

    // Fetch all locations to get the managers and emirates
    final locResp = await _client.from('locations').select();
    final locations = {
      for (var l in locResp) 
        l['id'] as String: {
          'name': l['name'] as String,
          'manager_name': l['manager_name'] as String?,
          'city': l['city'] as String?,
        }
    };

    // Fetch all rooms with beds and staff assignments
    final roomsResp = await _client.from('rooms').select(
      '*, beds(*, bed_assignments(*, staff(*)))'
    ).order('location_id').order('room_number');

    final List<dynamic> roomsData = roomsResp as List<dynamic>;

    for (var room in roomsData) {
      final locId = room['location_id'] as String;
      final locInfo = locations[locId] ?? {};
      final emirate = locInfo['city'] ?? locId;
      final managedBy = locInfo['manager_name'] ?? '';
      
      final bedsList = room['beds'] as List<dynamic>? ?? [];
      final capacity = room['capacity'] as int? ?? 0;
      
      // Calculate occupied count
      int occupied = 0;
      for (var bed in bedsList) {
        final status = bed['status'] as String? ?? 'VACANT';
        if (status == 'FULL' || status == 'VACATION') {
          occupied++;
        }
      }
      final available = capacity - occupied;

      final contractExpiry = room['contract_expiry'] as String?;
      
      String contractStatus = 'Valid';
      if (contractExpiry != null) {
        final expiryDate = DateTime.tryParse(contractExpiry);
        if (expiryDate != null) {
          if (expiryDate.isBefore(DateTime.now())) {
            contractStatus = 'Expired';
          } else if (expiryDate.difference(DateTime.now()).inDays < 90) {
            contractStatus = 'Expiring Soon';
          }
        }
      } else {
        contractStatus = 'N/A';
      }

      // Add to summary
      summarySheet.appendRow([
        TextCellValue(room['room_code']?.toString() ?? ''),
        TextCellValue(''),
        TextCellValue(room['room_number']?.toString() ?? ''),
        TextCellValue(room['contract_number']?.toString() ?? ''),
        TextCellValue(emirate.toString()),
        TextCellValue(contractExpiry ?? ''),
        TextCellValue(contractStatus),
        IntCellValue(capacity),
        IntCellValue(occupied),
        IntCellValue(available),
        TextCellValue(managedBy.toString()),
      ]);

      // Create a sheet for this room
      final String roomSheetName = 'Room ${room['room_number']}-${locId.substring(0, locId.length > 2 ? 2 : locId.length)}';
      
      // Prevent duplicate sheet names or name too long
      String safeName = roomSheetName.replaceAll(RegExp(r'[\\/?*[\]]'), '-');
      if (safeName.length > 31) {
        safeName = safeName.substring(0, 31);
      }
      
      final Sheet roomSheet = excel[safeName];
      roomSheet.appendRow([
        TextCellValue('Bed ID'),
        TextCellValue('Occupant Name'),
        TextCellValue('Occupant ID'),
        TextCellValue('Location'),
        TextCellValue('Status'),
      ]);

      // Sort beds
      bedsList.sort((a, b) {
        final numA = (a['bed_number'] as int?) ?? 0;
        final numB = (b['bed_number'] as int?) ?? 0;
        return numA.compareTo(numB);
      });

      for (var bed in bedsList) {
        String occupantName = '';
        String occupantId = '';
        
        final assignments = bed['bed_assignments'];
        if (assignments != null) {
          Map<String, dynamic>? assignmentObj;
          if (assignments is List && assignments.isNotEmpty) {
            assignmentObj = assignments.first as Map<String, dynamic>;
          } else if (assignments is Map<String, dynamic>) {
            assignmentObj = assignments;
          }
          
          if (assignmentObj != null && assignmentObj['staff'] != null) {
            final staffObj = assignmentObj['staff'] as Map<String, dynamic>;
            occupantName = staffObj['name']?.toString() ?? '';
            occupantId = staffObj['staff_id']?.toString() ?? '';
          }
        }

        roomSheet.appendRow([
          TextCellValue(bed['bed_code']?.toString() ?? ''),
          TextCellValue(occupantName),
          TextCellValue(occupantId),
          TextCellValue('${room['room_code']}-${bed['bed_number']?.toString().padLeft(3, '0') ?? ''}'),
          TextCellValue(bed['status']?.toString() ?? 'VACANT'),
        ]);
      }
    }

    // Generate bytes
    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file.');
    }

    // Save to temp dir and share
    final tempDir = await getTemporaryDirectory();
    final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final String path = '${tempDir.path}/Staff_Accommodation_Plan_$timestamp.xlsx';
    final File file = File(path);
    await file.writeAsBytes(bytes);

    // Share the file
    final xFile = XFile(path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    await Share.shareXFiles([xFile], text: 'Staff Accommodation Plan Export');
  }
}
