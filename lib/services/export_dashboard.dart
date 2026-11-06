import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';

/// Presentation only: all figures use the same fresh room snapshot as the detail sheets.
class ExportDashboard {
  final List<Map<String, dynamic>> locations;
  final int onLeaveStaff;
  final totals = [0, 0, 0, 0];
  final Map<String, List<int>> counts = {};
  late int chartEndRow;
  static const colors = ['246BCE', 'EF3434', '10B981', '8B5CF6'];
  static const darkFills = ['1E3A5F', '682C3C', '145445', '4C2875'];

  // excel 4.x requires opaque ARGB; six-digit RGB can leave dangling fill IDs.
  static ExcelColor cellColor(String rgb) => ExcelColor.fromHexString('FF$rgb');

  ExportDashboard(
    List<dynamic> locationRows,
    List<dynamic> rooms,
    this.onLeaveStaff,
  ) : locations = locationRows
          .map((l) => Map<String, dynamic>.from(l))
          .toList() {
    for (final loc in locations) {
      counts[loc['id'].toString()] = [0, 0, 0, 0];
    }
    for (final room in rooms) {
      final stats = counts.putIfAbsent(
        room['location_id'].toString(),
        () => [0, 0, 0, 0],
      );
      for (final bed in room['beds'] as List? ?? []) {
        stats[0]++;
        totals[0]++;
        final status = bed['status'] ?? 'VACANT';
        if (status == 'FULL' || status == 'VACATION') {
          stats[1]++;
          totals[1]++;
        } else if (status == 'VACANT') {
          stats[2]++;
          totals[2]++;
        }
        if (status == 'VACATION') stats[3]++;
      }
    }
    totals[3] = onLeaveStaff;
  }

  void write(Sheet sheet, DateTime generatedAt) {
    void band(int row, int first, int last, CellValue value, CellStyle style) {
      for (var col = first; col <= last; col++) {
        sheet
                .cell(
                  CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
                )
                .cellStyle =
            style;
      }
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: first, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: last, rowIndex: row),
      );
      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: first, rowIndex: row),
              )
              .value =
          value;
    }

    final heading = CellStyle(
      backgroundColorHex: cellColor('111827'),
      fontColorHex: ExcelColor.white,
      bold: true,
      fontSize: 18,
    );
    for (var c = 0; c < 12; c++) {
      sheet.setColumnWidth(c, 14);
    }
    band(0, 0, 11, TextCellValue('ACCOMMODATION | OVERVIEW'), heading);
    sheet.setRowHeight(0, 36);
    band(
      1,
      0,
      11,
      TextCellValue(
        'Exported: ${generatedAt.toIso8601String()} (device local time) | Current snapshot',
      ),
      CellStyle(fontSize: 11, fontColorHex: cellColor('475569')),
    );
    final labels = ['Total Beds', 'Occupied', 'Vacant', 'On Leave (staff)'];
    for (var i = 0; i < 4; i++) {
      final style = CellStyle(
        backgroundColorHex: cellColor(darkFills[i]),
        fontColorHex: ExcelColor.white,
        bold: true,
        fontSize: 28,
        horizontalAlign: HorizontalAlign.Center,
      );
      band(3, i * 3, i * 3 + 2, IntCellValue(totals[i]), style);
      band(
        4,
        i * 3,
        i * 3 + 2,
        TextCellValue(labels[i]),
        style.copyWith(fontSizeVal: 12),
      );
    }
    sheet.setRowHeight(3, 48);
    sheet.setRowHeight(4, 26);
    band(
      6,
      0,
      11,
      TextCellValue(
        'Occupied includes beds reserved during leave. Charts show current counts, not trends.',
      ),
      CellStyle(fontSize: 11),
    );
    // Charts reference the coloured cards directly: no repeated source table.
    final header = [
      'Location',
      'Total Beds',
      'Occupied',
      'Vacant',
      'On Leave Beds',
    ];
    for (var c = 0; c < header.length; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 28),
      );
      cell.value = TextCellValue(header[c]);
      cell.cellStyle = heading.copyWith(
        fontSizeVal: 11,
        backgroundColorHexVal: cellColor(c == 0 ? '111827' : darkFills[c - 1]),
      );
    }
    sheet.setColumnWidth(0, 26);
    for (var i = 0; i < locations.length; i++) {
      final loc = locations[i];
      final values = counts[loc['id'].toString()]!;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 29 + i))
          .value = TextCellValue(
        loc['name'].toString(),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 29 + i))
          .cellStyle = CellStyle(
        bold: true,
        fontSize: 12,
        backgroundColorHex: cellColor('1F2937'),
        fontColorHex: ExcelColor.white,
      );
      sheet.setRowHeight(29 + i, 28);
      for (var c = 0; c < 4; c++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: 29 + i),
            )
            .value = IntCellValue(
          values[c],
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: 29 + i),
            )
            .cellStyle = CellStyle(
          bold: true,
          fontSize: 14,
          horizontalAlign: HorizontalAlign.Center,
          fontColorHex: ExcelColor.white,
          backgroundColorHex: cellColor(darkFills[c]),
        );
      }
    }
    final noteRow = 30 + locations.length;
    band(
      noteRow,
      0,
      11,
      TextCellValue(
        'Location leave figures count reserved VACATION beds; overall On Leave counts staff, including unassigned staff.',
      ),
      CellStyle(fontSize: 11),
    );
    final chartStart = noteRow + 2;
    for (var i = 0; i < locations.length; i++) {
      final row = chartStart + i * 20;
      band(
        row,
        0,
        11,
        TextCellValue('LOCATION | ${locations[i]['name']}'),
        heading.copyWith(fontSizeVal: 14),
      );
      sheet.setRowHeight(row, 30);
    }
    chartEndRow = chartStart + locations.length * 20;
    band(
      chartEndRow + 1,
      0,
      11,
      TextCellValue('ROOM DETAILS | Existing export'),
      heading.copyWith(fontSizeVal: 14),
    );
    sheet.setRowHeight(chartEndRow + 1, 30);
    // Reserve space for both charts before appending the original room table.
  }

  List<int> addCharts(
    List<int> bytes, {
    Map<String, String> summaryLinks = const {},
  }) {
    final zip = ZipDecoder().decodeBytes(bytes);
    String read(String path) =>
        utf8.decode(zip.findFile(path)!.content as List<int>);
    void put(String path, String value) {
      final data = utf8.encode(value);
      zip.addFile(ArchiveFile(path, data.length, data));
    }

    final styles = XmlDocument.parse(read('xl/styles.xml'));
    // The library's reserved second fill uses a non-OOXML name.
    for (final pattern in styles.findAllElements('patternFill')) {
      if (pattern.getAttribute('patternType') == 'lightGray') {
        pattern.setAttribute('patternType', 'gray125');
      }
    }
    for (final name in [
      'fonts',
      'fills',
      'borders',
      'cellStyleXfs',
      'cellXfs',
    ]) {
      final table = styles.findAllElements(name).single;
      if (int.parse(table.getAttribute('count')!) !=
          table.childElements.length) {
        throw StateError('Invalid Excel style table: $name');
      }
    }
    put('xl/styles.xml', styles.toXmlString());

    // Resolve the Summary relationship instead of assuming a sheet number.
    final book = XmlDocument.parse(read('xl/workbook.xml'));
    final summary = book
        .findAllElements('sheet')
        .firstWhere((e) => e.getAttribute('name') == 'Summary');
    final rels = XmlDocument.parse(read('xl/_rels/workbook.xml.rels'));
    final rel = rels
        .findAllElements('Relationship')
        .firstWhere(
          (e) => e.getAttribute('Id') == summary.getAttribute('r:id'),
        );
    final target = rel.getAttribute('Target')!;
    final path = target.startsWith('/') ? target.substring(1) : 'xl/$target';
    final sheet = XmlDocument.parse(read(path));
    final hyperlinks = XmlElement(XmlName('hyperlinks'), [], [
      for (final link in summaryLinks.entries)
        XmlElement(XmlName('hyperlink'), [
          XmlAttribute(XmlName('ref'), link.key),
          XmlAttribute(XmlName('location'), link.value),
          XmlAttribute(XmlName('tooltip'), 'Open worksheet'),
        ]),
    ]);
    // OOXML places hyperlinks after cell/formatting data and before page settings.
    const following = {
      'printOptions',
      'pageMargins',
      'pageSetup',
      'headerFooter',
      'rowBreaks',
      'colBreaks',
      'customProperties',
      'cellWatches',
      'ignoredErrors',
      'smartTags',
      'drawing',
      'legacyDrawing',
      'extLst',
    };
    final next = sheet.rootElement.children.indexWhere(
      (n) => n is XmlElement && following.contains(n.name.local),
    );
    sheet.rootElement.children.insert(
      next < 0 ? sheet.rootElement.children.length : next,
      hyperlinks,
    );
    sheet.rootElement.setAttribute(
      'xmlns:r',
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
    );
    sheet.rootElement.children.add(
      XmlElement(XmlName('drawing'), [
        XmlAttribute(XmlName('id', 'r'), 'dashboardDrawing'),
      ]),
    );
    put(path, sheet.toXmlString());
    final slash = path.lastIndexOf('/');
    final relPath =
        '${path.substring(0, slash)}/_rels/${path.substring(slash + 1)}.rels';
    final sheetRels = zip.findFile(relPath) == null
        ? XmlDocument.parse(
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>',
          )
        : XmlDocument.parse(read(relPath));
    sheetRels.rootElement.children.add(
      XmlElement(XmlName('Relationship'), [
        XmlAttribute(XmlName('Id'), 'dashboardDrawing'),
        XmlAttribute(
          XmlName('Type'),
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing',
        ),
        XmlAttribute(
          XmlName('Target'),
          '../drawings/accommodationDashboard.xml',
        ),
      ]),
    );
    put(relPath, sheetRels.toXmlString());
    String anchor(int id, int from, int to) =>
        '''<xdr:twoCellAnchor>
<xdr:from><xdr:col>0</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>$from</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>
<xdr:to><xdr:col>12</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>$to</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>
<xdr:graphicFrame macro=""><xdr:nvGraphicFramePr><xdr:cNvPr id="$id" name="Accommodation Chart $id"/><xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr>
<xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart"><c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" r:id="chart$id"/></a:graphicData></a:graphic></xdr:graphicFrame><xdr:clientData/></xdr:twoCellAnchor>''';
    final chartIds = List.generate(locations.length + 1, (i) => i + 1);
    put(
      'xl/drawings/accommodationDashboard.xml',
      '''<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">${anchor(1, 11, 27)}${[for (var i = 0; i < locations.length; i++) anchor(i + 2, 33 + locations.length + i * 20, 50 + locations.length + i * 20)].join()}</xdr:wsDr>''',
    );
    put(
      'xl/drawings/_rels/accommodationDashboard.xml.rels',
      '''<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${chartIds.map((id) => '<Relationship Id="chart$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart" Target="../charts/accommodation$id.xml"/>').join()}</Relationships>''',
    );
    final series = <String>[];
    const labels = ['Total Beds', 'Occupied', 'Vacant', 'On Leave (staff)'];
    var overall = _series(
      0,
      'Current count',
      colors[0],
      labels,
      totals,
      "('Summary'!\$A\$5,'Summary'!\$D\$5,'Summary'!\$G\$5,'Summary'!\$J\$5)",
      "('Summary'!\$A\$4,'Summary'!\$D\$4,'Summary'!\$G\$4,'Summary'!\$J\$4)",
    );
    final points = [
      for (var i = 0; i < 4; i++)
        '<c:dPt><c:idx val="$i"/><c:spPr><a:solidFill><a:srgbClr val="${colors[i]}"/></a:solidFill></c:spPr></c:dPt>',
    ].join();
    overall = overall.replaceFirst('<c:cat>', '$points<c:cat>');
    series.add(overall);
    put(
      'xl/charts/accommodation1.xml',
      _chart('Overall | Current Snapshot', series.join()),
    );
    for (var i = 0; i < locations.length; i++) {
      final loc = locations[i];
      final row = 30 + i;
      var locSeries = _series(
        0,
        loc['name'].toString(),
        colors[0],
        ['Total Beds', 'Occupied', 'Vacant', 'On Leave Beds'],
        counts[loc['id'].toString()]!,
        "'Summary'!\$B\$29:\$E\$29",
        "'Summary'!\$B\$$row:\$E\$$row",
      );
      locSeries = locSeries.replaceFirst('<c:cat>', '$points<c:cat>');
      put(
        'xl/charts/accommodation${i + 2}.xml',
        _chart('${loc['name']} | Current Bed Counts', locSeries),
      );
    }
    final types = XmlDocument.parse(read('[Content_Types].xml'));
    for (final entry in {
      '/xl/drawings/accommodationDashboard.xml':
          'application/vnd.openxmlformats-officedocument.drawing+xml',
      for (final id in chartIds)
        '/xl/charts/accommodation$id.xml':
            'application/vnd.openxmlformats-officedocument.drawingml.chart+xml',
    }.entries) {
      types.rootElement.children.add(
        XmlElement(XmlName('Override'), [
          XmlAttribute(XmlName('PartName'), entry.key),
          XmlAttribute(XmlName('ContentType'), entry.value),
        ]),
      );
    }
    put('[Content_Types].xml', types.toXmlString());
    return ZipEncoder().encode(zip)!;
  }

  static String _escape(String text) => XmlText(text).toXmlString();
  static String _series(
    int index,
    String label,
    String color,
    List<String> labels,
    List<int> values,
    String catRef,
    String valRef,
  ) =>
      '''<c:ser><c:idx val="$index"/><c:order val="$index"/><c:tx><c:v>${_escape(label)}</c:v></c:tx><c:spPr><a:solidFill><a:srgbClr val="$color"/></a:solidFill></c:spPr>
<c:cat><c:strRef><c:f>${_escape(catRef)}</c:f><c:strCache><c:ptCount val="${labels.length}"/>${[for (var i = 0; i < labels.length; i++) '<c:pt idx="$i"><c:v>${_escape(labels[i])}</c:v></c:pt>'].join()}</c:strCache></c:strRef></c:cat>
<c:val><c:numRef><c:f>${_escape(valRef)}</c:f><c:numCache><c:formatCode>0</c:formatCode><c:ptCount val="${values.length}"/>${[for (var i = 0; i < values.length; i++) '<c:pt idx="$i"><c:v>${values[i]}</c:v></c:pt>'].join()}</c:numCache></c:numRef></c:val></c:ser>''';

  static String _chart(String title, String series) =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><c:chart><c:title><c:tx><c:rich><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US" sz="1600" b="1"/><a:t>${_escape(title)}</a:t></a:r></a:p></c:rich></c:tx><c:overlay val="0"/></c:title><c:autoTitleDeleted val="0"/><c:plotArea><c:layout/><c:barChart><c:barDir val="bar"/><c:grouping val="clustered"/><c:varyColors val="0"/>$series<c:dLbls><c:showLegendKey val="0"/><c:showVal val="1"/><c:showCatName val="0"/><c:showSerName val="0"/></c:dLbls><c:gapWidth val="70"/><c:overlap val="0"/><c:axId val="100"/><c:axId val="200"/></c:barChart>
<c:catAx><c:axId val="100"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:axPos val="l"/><c:tickLblPos val="nextTo"/><c:crossAx val="200"/><c:crosses val="autoZero"/><c:auto val="1"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/></c:catAx>
<c:valAx><c:axId val="200"/><c:scaling><c:orientation val="minMax"/><c:min val="0"/></c:scaling><c:axPos val="b"/><c:majorGridlines/><c:numFmt formatCode="0" sourceLinked="0"/><c:tickLblPos val="nextTo"/><c:crossAx val="100"/><c:crosses val="autoZero"/><c:crossBetween val="between"/></c:valAx></c:plotArea><c:legend><c:legendPos val="b"/><c:overlay val="0"/></c:legend><c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/></c:chart></c:chartSpace>''';
}
