import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'export_dashboard.dart';

class ExportService {
  final _client = Supabase.instance.client;

  Future<void> exportData() async {
    // Read fresh data for every export, independently of cached screen totals.
    final locResp = await _allRows(
      (start, end) => _client
          .from('locations')
          .select()
          .order('name')
          .order('id')
          .range(start, end),
    );
    final roomsResp = await _allRows(
      (start, end) => _client
          .from('rooms')
          .select('*, beds(*, bed_assignments(*, staff(*)))')
          .order('location_id')
          .order('room_number')
          .order('id')
          .range(start, end),
    );
    final leaveResp = await _allRows(
      (start, end) => _client
          .from('staff')
          .select('id, staff_id, name, status, phone, nationality')
          .eq('status', 'On Leave')
          .order('name')
          .order('id')
          .range(start, end),
    );
    final generatedAt = DateTime.now();
    final bytes = buildWorkbook(
      locationsData: locResp,
      roomsData: roomsResp,
      leaveStaffData: leaveResp,
      generatedAt: generatedAt,
    );
    final timestamp = generatedAt
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')[0];
    final fileName = 'Staff_Accommodation_Plan_$timestamp.xlsx';
    if (kIsWeb) {
      final blob = html.Blob([
        bytes,
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/$fileName';
      await File(path).writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          text: 'Staff Accommodation Plan Export',
        ),
      );
    }
  }

  // Avoid silently truncating a large export at the Data API's default row limit.
  static Future<List<dynamic>> _allRows(
    Future<List<dynamic>> Function(int start, int end) page,
  ) async {
    final rows = <dynamic>[];
    const pageSize = 500;
    for (var start = 0; ; start += pageSize) {
      final batch = await page(start, start + pageSize - 1);
      rows.addAll(batch);
      if (batch.length < pageSize) return rows;
    }
  }

  static List<int> buildWorkbook({
    required List<dynamic> locationsData,
    required List<dynamic> roomsData,
    required List<dynamic> leaveStaffData,
    required DateTime generatedAt,
  }) {
    final excel = Excel.createExcel();

    // Rename default sheet to Summary
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Summary');
    final Sheet summarySheet = excel['Summary'];
    final summaryLinks = <String, String>{
      'J4': "'leave'!A1",
      'J5': "'leave'!A1",
    };
    final onLeave =
        leaveStaffData.where((s) => s['status'] == 'On Leave').toList()..sort(
          (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
            (b['name'] ?? '').toString().toLowerCase(),
          ),
        );
    // Create this before the room sheets so it is always the second tab.
    _writeLeaveSheet(excel['leave'], onLeave, locationsData, roomsData);
    final dashboard = ExportDashboard(locationsData, roomsData, onLeave.length);
    dashboard.write(summarySheet, generatedAt);

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
    final locations = {
      for (var l in locationsData)
        l['id'] as String: {
          'name': l['name'] as String,
          'manager_name': l['manager_name'] as String?,
          'city': l['city'] as String?,
        },
    };

    for (var room in roomsData) {
      final locId = room['location_id'] as String;
      final locInfo = locations[locId] ?? {};
      final emirate = locInfo['city'] ?? locId;
      final managedBy = locInfo['manager_name'] ?? '';

      final bedsList = room['beds'] as List<dynamic>? ?? [];

      // Calculate occupied and available counts based purely on actual beds
      int capacity = bedsList.length;
      int occupied = 0;
      int available = 0;
      for (var bed in bedsList) {
        final status = bed['status'] as String? ?? 'VACANT';
        if (status == 'FULL' || status == 'VACATION') {
          occupied++;
        } else if (status == 'VACANT') {
          available++;
        }
      }

      final contractExpiry = room['contract_expiry'] as String?;

      String contractStatus = 'Valid';
      if (contractExpiry != null) {
        final expiryDate = DateTime.tryParse(contractExpiry);
        if (expiryDate != null) {
          if (expiryDate.isBefore(generatedAt)) {
            contractStatus = 'Expired';
          } else if (expiryDate.difference(generatedAt).inDays < 90) {
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
      final String roomSheetName =
          'Room ${room['room_number']}-${locId.substring(0, locId.length > 2 ? 2 : locId.length)}';

      // Prevent duplicate sheet names or name too long
      String safeName = roomSheetName.replaceAll(RegExp(r'[\\/?*[\]]'), '-');
      if (safeName.length > 31) {
        safeName = safeName.substring(0, 31);
      }

      final Sheet roomSheet = excel[safeName];
      final roomCell = 'C${summarySheet.maxRows}';
      summaryLinks[roomCell] = "'${safeName.replaceAll("'", "''")}'!A1";
      summarySheet
          .cell(CellIndex.indexByString(roomCell))
          .cellStyle = CellStyle(
        fontColorHex: ExcelColor.fromHexString('246BCE'),
        underline: Underline.Single,
        bold: true,
      );
      roomSheet.appendRow([
        TextCellValue('Bed ID'),
        TextCellValue('Occupant Name'),
        TextCellValue('Occupant ID'),
        TextCellValue('Location'),
        TextCellValue('Position'),
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
          TextCellValue(
            '${room['room_code']}-${bed['bed_number']?.toString().padLeft(3, '0') ?? ''}',
          ),
          TextCellValue(bed['position']?.toString() ?? 'LB'),
          TextCellValue(bed['status']?.toString() ?? 'VACANT'),
        ]);
      }
    }

    // Generate bytes
    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file.');
    }

    return dashboard.addCharts(bytes, summaryLinks: summaryLinks);
  }

  static void _writeLeaveSheet(
    Sheet sheet,
    List<dynamic> staff,
    List<dynamic> locations,
    List<dynamic> rooms,
  ) {
    final locationNames = {for (final l in locations) l['id']: l['name']};
    final assignments = <String, List<Map<String, String>>>{};
    for (final room in rooms) {
      for (final bed in room['beds'] as List? ?? []) {
        final raw = bed['bed_assignments'];
        final rows = raw is List ? raw : (raw is Map ? [raw] : []);
        for (final assignment in rows) {
          final occupant = assignment['staff'];
          if (occupant is! Map) continue;
          final key = (occupant['id'] ?? occupant['staff_id'])?.toString();
          if (key == null) continue;
          assignments.putIfAbsent(key, () => []).add({
            'location':
                (locationNames[room['location_id']] ??
                        room['location_id'] ??
                        '')
                    .toString(),
            'room': (room['room_number'] ?? '').toString(),
            'bed': (bed['bed_code'] ?? '').toString(),
          });
        }
      }
    }
    const headers = [
      'Staff ID',
      'Staff Name',
      'Nationality',
      'Phone',
      'Location',
      'Room No',
      'Bed ID',
      'Status',
    ];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (var c = 0; c < headers.length; c++) {
      sheet.setColumnWidth(
        c,
        [18.0, 34.0, 20.0, 22.0, 30.0, 18.0, 22.0, 18.0][c],
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('6D28D9'),
        fontColorHex: ExcelColor.white,
        bold: true,
        fontSize: 12,
      );
    }
    sheet.setRowHeight(0, 30);
    for (var i = 0; i < staff.length; i++) {
      final person = staff[i];
      final places =
          assignments[person['id']?.toString()] ??
          assignments[person['staff_id']?.toString()] ??
          [];
      String place(String field) => places.isEmpty
          ? 'Unassigned'
          : places
                .map((p) => p[field]!)
                .where((v) => v.isNotEmpty)
                .toSet()
                .join(', ');
      sheet.appendRow([
        for (final value in [
          person['staff_id'],
          person['name'],
          person['nationality'],
          person['phone'],
          place('location'),
          place('room'),
          place('bed'),
          person['status'],
        ])
          TextCellValue(value?.toString() ?? ''),
      ]);
      sheet.setRowHeight(i + 1, 30);
      for (var c = 0; c < headers.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: i + 1))
            .cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString(
            i.isEven ? 'F3EEFF' : 'FFFFFF',
          ),
          fontColorHex: ExcelColor.fromHexString(c == 7 ? '6D28D9' : '172033'),
          bold: c == 7,
          textWrapping: TextWrapping.WrapText,
        );
      }
    }
    if (staff.isEmpty) {
      sheet.appendRow([TextCellValue('No staff currently on leave')]);
    }
  }
}
