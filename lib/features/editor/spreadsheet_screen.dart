import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class SpreadsheetScreen extends StatefulWidget {
  final String? path;
  const SpreadsheetScreen({super.key, this.path});

  @override
  State<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends State<SpreadsheetScreen> {
  Excel _book = Excel.createExcel();
  String _sheet = 'Sheet1';
  int rows = 30;
  int cols = 12;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.path != null) {
      try {
        _book = Excel.decodeBytes(await File(widget.path!).readAsBytes());
        _sheet = _book.tables.keys.isNotEmpty ? _book.tables.keys.first : 'Sheet1';
        setState(() {});
      } catch (_) {}
    }
  }

  Sheet get current => _book[_sheet];

  Future<void> _edit(int r, int c) async {
    final cell = current.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    final controller = TextEditingController(text: cell.value?.toString() ?? '');
    final value = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: Text('Edit ${CellIndex.indexByColumnRow(columnIndex: c,rowIndex:r).cellId}'),
      content: TextField(controller: controller, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Apply'))],
    ));
    if (value != null) {
      cell.value = TextCellValue(value);
      setState(() {});
    }
  }

  Future<void> _save() async {
    final path = await FilePicker.platform.saveFile(dialogTitle: 'Save spreadsheet', fileName: 'Workbook.xlsx');
    if (path == null) return;
    final bytes = _book.encode();
    if (bytes != null) await File(path).writeAsBytes(bytes, flush: true);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $path')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.path?.split('/').last ?? 'New Spreadsheet'), actions: [IconButton(onPressed: _save, icon: const Icon(Icons.save_as))]),
      body: InteractiveViewer(
        constrained: false,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(110),
          border: TableBorder.all(color: Colors.black12),
          children: List.generate(rows, (r) => TableRow(children: List.generate(cols, (c) {
            final cell = current.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
            return InkWell(onTap: () => _edit(r,c), child: Container(height: 44, padding: const EdgeInsets.all(8), alignment: Alignment.centerLeft, child: Text(cell.value?.toString() ?? '')));
          }))),
        ),
      ),
    );
  }
}
