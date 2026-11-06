import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staff_accommodation_app/services/export_service.dart';
import 'package:xml/xml.dart';

void main() {
  final locations = [
    {
      'id': 'AA',
      'name': 'Main & East',
      'manager_name': 'Manager',
      'city': 'Dubai',
    },
    {'id': 'BB', 'name': 'West'},
    {'id': 'CC', 'name': 'Empty Location'},
  ];
  Map<String, dynamic> bed(int number, String status) => {
    'bed_number': number,
    'bed_code': 'B$number',
    'status': status,
    'position': 'LB',
    'bed_assignments': status == 'VACANT'
        ? []
        : [
            {
              'staff': {
                'name': 'Example Staff $number',
                'staff_id': 'S$number',
              },
            },
          ],
  };
  final rooms = [
    {
      'location_id': 'AA',
      'room_number': '101',
      'room_code': 'AA-101',
      'contract_number': 'Contract 1',
      'contract_expiry': '2027-12-31',
      'beds': [bed(2, 'VACATION'), bed(1, 'FULL'), bed(3, 'VACANT')],
    },
    {
      'location_id': 'BB',
      'room_number': '102',
      'room_code': 'BB-102',
      'beds': [bed(4, 'VACANT')],
    },
  ];
  test(
    'dashboard has correct totals, native charts and unchanged room details',
    () {
      final bytes = ExportService.buildWorkbook(
        locationsData: locations,
        roomsData: rooms,
        leaveStaffData: [
          {
            'id': '2',
            'staff_id': 'S2',
            'name': 'Example Staff 2',
            'status': 'On Leave',
            'phone': '0501234567',
            'nationality': 'India',
          },
          {
            'id': 'unassigned',
            'staff_id': 'S9',
            'name': 'Unassigned Staff',
            'status': 'On Leave',
          },
          {
            'id': 'active',
            'staff_id': 'S10',
            'name': 'Active Staff',
            'status': 'Active',
          },
        ],
        generatedAt: DateTime(2026, 11, 6, 12),
      );
      final excel = Excel.decodeBytes(bytes);
      final summary = excel['Summary'];
      expect(
        [
          'A4',
          'D4',
          'G4',
          'J4',
        ].map((c) => summary.cell(CellIndex.indexByString(c)).value),
        [IntCellValue(4), IntCellValue(2), IntCellValue(2), IntCellValue(2)],
      );
      expect(
        summary.cell(CellIndex.indexByString('A30')).value,
        TextCellValue('Main & East'),
      );
      expect(
        summary.cell(CellIndex.indexByString('E30')).value,
        IntCellValue(1),
      );
      expect(
        summary.cell(CellIndex.indexByString('B32')).value,
        IntCellValue(0),
      );
      final header = summary.rows.indexWhere(
        (r) => r.first?.value == TextCellValue('Room ID'),
      );
      expect(header, greaterThan(50));
      expect(summary.rows[header + 1].take(11).map((c) => c?.value).toList(), [
        TextCellValue('AA-101'),
        TextCellValue(''),
        TextCellValue('101'),
        TextCellValue('Contract 1'),
        TextCellValue('Dubai'),
        TextCellValue('2027-12-31'),
        TextCellValue('Valid'),
        IntCellValue(3),
        IntCellValue(2),
        IntCellValue(1),
        TextCellValue('Manager'),
      ]);
      expect(excel.tables.keys, [
        'Summary',
        'leave',
        'Room 101-AA',
        'Room 102-BB',
      ]);
      final leave = excel['leave'];
      expect(leave.rows.length, 3);
      expect(leave.rows[1].map((c) => c?.value).toList(), [
        for (final v in [
          'S2',
          'Example Staff 2',
          'India',
          '0501234567',
          'Main & East',
          '101',
          'B2',
          'On Leave',
        ])
          TextCellValue(v),
      ]);
      expect(
        leave.cell(CellIndex.indexByString('E3')).value,
        TextCellValue('Unassigned'),
      );
      expect(
        leave.cell(CellIndex.indexByString('H3')).value,
        TextCellValue('On Leave'),
      );
      final detail = excel['Room 101-AA'].rows;
      expect(detail.length, 4);
      expect(detail[1][0]?.value, TextCellValue('B1'));
      expect(detail[1][1]?.value, TextCellValue('Example Staff 1'));
      expect(detail[2][5]?.value, TextCellValue('VACATION'));
      final archive = ZipDecoder().decodeBytes(bytes);
      final styles = XmlDocument.parse(
        utf8.decode(archive.findFile('xl/styles.xml')!.content as List<int>),
      );
      for (final name in [
        'fonts',
        'fills',
        'borders',
        'cellStyleXfs',
        'cellXfs',
      ]) {
        final table = styles.findAllElements(name).single;
        expect(
          int.parse(table.getAttribute('count')!),
          table.childElements.length,
          reason: name,
        );
      }
      final fillCount = styles
          .findAllElements('fills')
          .single
          .childElements
          .length;
      for (final xf in styles.findAllElements('xf')) {
        expect(
          int.parse(xf.getAttribute('fillId') ?? '0'),
          lessThan(fillCount),
        );
      }
      for (final color in styles.descendants.whereType<XmlElement>().where(
        (e) => e.getAttribute('rgb') != null,
      )) {
        expect(color.getAttribute('rgb'), matches(RegExp(r'^FF[0-9A-F]{6}$')));
      }
      expect(
        styles
            .findAllElements('patternFill')
            .any((p) => p.getAttribute('patternType') == 'lightGray'),
        isFalse,
      );
      final links = archive.files
          .where(
            (f) =>
                f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml'),
          )
          .map((f) => XmlDocument.parse(utf8.decode(f.content as List<int>)))
          .expand((d) => d.findAllElements('hyperlink'))
          .toList();
      expect(
        links
            .firstWhere((l) => l.getAttribute('ref') == 'J4')
            .getAttribute('location'),
        "'leave'!A1",
      );
      expect(
        links
            .firstWhere((l) => l.getAttribute('ref') == 'J5')
            .getAttribute('location'),
        "'leave'!A1",
      );
      expect(
        links
            .firstWhere((l) => l.getAttribute('ref') == 'C${header + 2}')
            .getAttribute('location'),
        "'Room 101-AA'!A1",
      );
      expect(
        links
            .firstWhere((l) => l.getAttribute('ref') == 'C${header + 3}')
            .getAttribute('location'),
        "'Room 102-BB'!A1",
      );
      for (final file in archive.files.where(
        (f) => f.name.endsWith('.xml') || f.name.endsWith('.rels'),
      )) {
        expect(
          () => XmlDocument.parse(utf8.decode(file.content as List<int>)),
          returnsNormally,
          reason: file.name,
        );
      }
      final charts = archive.files
          .where((f) => f.name.startsWith('xl/charts/'))
          .toList();
      expect(charts.length, 4);
      expect(
        utf8.decode(charts[0].content as List<int>),
        contains("'Summary'!\$A\$4,'Summary'!\$D\$4"),
      );
      final locationChart = utf8.decode(charts[1].content as List<int>);
      expect(locationChart, contains('Main &amp; East'));
      expect(locationChart, contains("'Summary'!\$B\$30:\$E\$30"));
      expect(locationChart, contains('Main &amp; East | Current Bed Counts'));
      expect(
        utf8.decode(charts[2].content as List<int>),
        contains('West | Current Bed Counts'),
      );
      expect(
        utf8.decode(charts[3].content as List<int>),
        contains('Empty Location | Current Bed Counts'),
      );
      expect(summary.cell(CellIndex.indexByString('A9')).value, isNull);
      expect(summary.cell(CellIndex.indexByString('A10')).value, isNull);
      expect(
        summary.cell(CellIndex.indexByString('A36')).value,
        TextCellValue('LOCATION | Main & East'),
      );
      expect(
        summary.cell(CellIndex.indexByString('B30')).cellStyle!.backgroundColor,
        isNot(
          summary
              .cell(CellIndex.indexByString('C30'))
              .cellStyle!
              .backgroundColor,
        ),
      );
      expect(
        summary.cell(CellIndex.indexByString('A29')).cellStyle!.fontColor,
        ExcelColor.white,
      );
      expect(
        summary.cell(CellIndex.indexByString('A30')).cellStyle!.fontColor,
        ExcelColor.white,
      );
      expect(
        summary.cell(CellIndex.indexByString('B30')).cellStyle!.fontColor,
        ExcelColor.white,
      );
      Directory('build').createSync(recursive: true);
      File('build/export_dashboard_example.xlsx').writeAsBytesSync(bytes);
    },
  );
  test('empty export has zero metrics and a valid overall chart', () {
    final bytes = ExportService.buildWorkbook(
      locationsData: [],
      roomsData: [],
      leaveStaffData: [],
      generatedAt: DateTime(2026, 11, 6),
    );
    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.keys.toList()[1], 'leave');
    expect(
      excel['leave'].cell(CellIndex.indexByString('A2')).value,
      TextCellValue('No staff currently on leave'),
    );
    expect(
      excel['Summary'].cell(CellIndex.indexByString('A4')).value,
      IntCellValue(0),
    );
    expect(
      ZipDecoder()
          .decodeBytes(bytes)
          .files
          .where((f) => f.name.startsWith('xl/charts/'))
          .length,
      1,
    );
  });
}
