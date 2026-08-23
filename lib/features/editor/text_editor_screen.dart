import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../services/docx_service.dart';

class TextEditorScreen extends StatefulWidget {
  final String? path;
  final bool isDocx;

  const TextEditorScreen({
    super.key,
    this.path,
    this.isDocx = false,
  });

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen>
    with SingleTickerProviderStateMixin {
  late QuillController _controller;
  late TabController _tabs;

  bool _loading = true;
  String? _sourcePath;
  String? _lastSavedPath;

  String _pageSize = 'A4';
  String _marginPreset = 'Normal';
  bool _landscape = false;
  bool _printLayout = true;
  bool _fitPageWidth = true;

  static const navy = Color(0xFF071A38);
  static const panel = Color(0xFF0D2449);
  static const accent = Color(0xFF79AEFF);

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
    _controller.addListener(_onEditorChanged);
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onEditorChanged);
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _onEditorChanged() {
    if (mounted) setState(() {});
  }

  String sidecarPath(String path) => '$path.astra.quill.json';

  Future<void> _load() async {
    _sourcePath = widget.path;

    try {
      if (widget.path != null) {
        final sidecar = File(sidecarPath(widget.path!));
        Document document;

        if (await sidecar.exists()) {
          final raw = await sidecar.readAsString();
          final data = jsonDecode(raw) as List<dynamic>;
          document = Document.fromJson(data);
        } else {
          final text = widget.isDocx
              ? await DocxService().readPlainText(widget.path!)
              : await File(widget.path!).readAsString();
          document = Document();
          if (text.isNotEmpty) document.insert(0, text);
        }

        _controller.removeListener(_onEditorChanged);
        _controller.dispose();
        _controller = QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _controller.addListener(_onEditorChanged);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Open failed: $e')),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveRichSidecar(String path) async {
    final json = _controller.document.toDelta().toJson();
    await File(sidecarPath(path)).writeAsString(
      jsonEncode(json),
      flush: true,
    );
  }

  Future<void> _saveAs() async {
    final defaultName = widget.isDocx ? 'Document.docx' : 'Document.txt';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save document as',
      fileName: defaultName,
    );
    if (path == null) return;

    final plain = _controller.document.toPlainText();

    try {
      if (widget.isDocx) {
        if (_sourcePath == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Native new-DOCX package creation is part of the DOCX round-trip engine milestone.',
              ),
            ),
          );
          return;
        }
        await DocxService().savePlainText(_sourcePath!, path, plain);
      } else {
        await File(path).writeAsString(plain, flush: true);
      }

      await _saveRichSidecar(path);
      _lastSavedPath = path;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _quickSave() async {
    final path = _lastSavedPath ?? _sourcePath;
    if (path == null) {
      await _saveAs();
      return;
    }

    final plain = _controller.document.toPlainText();

    try {
      if (widget.isDocx && _sourcePath != null) {
        await DocxService().savePlainText(_sourcePath!, path, plain);
      } else {
        await File(path).writeAsString(plain, flush: true);
      }
      await _saveRichSidecar(path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Map<String, Attribute> get _style =>
      _controller.getSelectionStyle().attributes;

  bool _isActive(Attribute attribute) {
    final current = _style[attribute.key];
    if (current == null) return false;
    if (attribute.value == null) return true;
    return current.value == attribute.value;
  }

  void _toggle(Attribute attribute) {
    final current = _style[attribute.key];
    final active = current != null &&
        (attribute.value == null || current.value == attribute.value);
    _controller.formatSelection(
      active ? Attribute.clone(attribute, null) : attribute,
    );
  }

  void _setAttr(String key, dynamic value) {
    _controller.formatSelection(Attribute.fromKeyValue(key, value));
  }

  void _clearFormatting() {
    const keys = [
      'bold',
      'italic',
      'underline',
      'strike',
      'script',
      'font',
      'size',
      'color',
      'background',
      'header',
      'align',
      'list',
      'indent',
    ];
    for (final key in keys) {
      _controller.formatSelection(Attribute.fromKeyValue(key, null));
    }
  }

  String get _fontLabel =>
      _style[Attribute.font.key]?.value?.toString() ?? 'Font';

  double get _fontSize {
    final value = _style[Attribute.size.key]?.value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
      if (value == 'small') return 10;
      if (value == 'large') return 18;
      if (value == 'huge') return 28;
    }
    return 14;
  }

  void _changeFontSize(double delta) {
    final next = (_fontSize + delta).clamp(8.0, 96.0);
    _setAttr(Attribute.size.key, next);
  }

  Future<void> _copy() async {
    final text = _controller.getPlainText();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied')),
      );
    }
  }

  Future<void> _cut() async {
    final selection = _controller.selection;
    if (selection.isCollapsed) return;
    final text = _controller.getPlainText();
    await Clipboard.setData(ClipboardData(text: text));
    _controller.replaceText(
      selection.start,
      selection.end - selection.start,
      '',
      TextSelection.collapsed(offset: selection.start),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) return;

    final selection = _controller.selection;
    _controller.replaceText(
      selection.start,
      selection.end - selection.start,
      text,
      TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  void _selectAll() {
    final length = math.max(0, _controller.document.length - 1);
    _controller.updateSelection(
      TextSelection(baseOffset: 0, extentOffset: length),
      ChangeSource.local,
    );
  }

  void _insertText(String text) {
    final selection = _controller.selection;
    _controller.replaceText(
      selection.start,
      selection.end - selection.start,
      text,
      TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  Future<void> _insertLink() async {
    final url = TextEditingController(text: 'https://');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert link'),
        content: TextField(
          controller: url,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'URL'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, url.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    _setAttr(Attribute.link.key, result);
  }

  Future<void> _insertSymbol() async {
    const symbols = ['©', '®', '™', '₹', '€', '£', '°', '±', '×', '÷', '✓', '•'];
    final symbol = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: navy,
      builder: (_) => SafeArea(
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 6,
          padding: const EdgeInsets.all(18),
          children: symbols
              .map(
                (s) => InkWell(
                  onTap: () => Navigator.pop(context, s),
                  child: Center(
                    child: Text(
                      s,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (symbol != null) _insertText(symbol);
  }

  void _insertDateTime() {
    final now = DateTime.now();
    final value =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _insertText(value);
  }

  Future<void> _findReplaceDialog() async {
    final find = TextEditingController();
    final replace = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Find & Replace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: find,
              decoration: const InputDecoration(labelText: 'Find'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: replace,
              decoration: const InputDecoration(labelText: 'Replace with'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final query = find.text;
              if (query.isNotEmpty) _findNext(query);
            },
            child: const Text('Find next'),
          ),
          FilledButton(
            onPressed: () {
              final query = find.text;
              if (query.isNotEmpty) {
                final count = _replaceAll(query, replace.text);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Replaced $count occurrence(s)')),
                );
              }
            },
            child: const Text('Replace all'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    find.dispose();
    replace.dispose();
  }

  void _findNext(String query) {
    final plain = _controller.document.toPlainText();
    if (plain.isEmpty) return;

    var start = _controller.selection.end;
    var index = plain.toLowerCase().indexOf(query.toLowerCase(), start);
    if (index < 0) {
      index = plain.toLowerCase().indexOf(query.toLowerCase());
    }

    if (index < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text not found')),
      );
      return;
    }

    _controller.updateSelection(
      TextSelection(
        baseOffset: index,
        extentOffset: index + query.length,
      ),
      ChangeSource.local,
    );
  }

  int _replaceAll(String query, String replacement) {
    final plain = _controller.document.toPlainText();
    final lower = plain.toLowerCase();
    final needle = query.toLowerCase();

    final positions = <int>[];
    var offset = 0;
    while (true) {
      final index = lower.indexOf(needle, offset);
      if (index < 0) break;
      positions.add(index);
      offset = index + query.length;
    }

    for (final index in positions.reversed) {
      _controller.replaceText(
        index,
        query.length,
        replacement,
        TextSelection.collapsed(offset: index + replacement.length),
      );
    }
    return positions.length;
  }

  void _showWordCount() {
    final text = _controller.document.toPlainText().trim();
    final words = text.isEmpty
        ? 0
        : text.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length;
    final chars = text.length;
    final paragraphs =
        text.isEmpty ? 0 : text.split(RegExp(r'\n+')).where((e) => e.trim().isNotEmpty).length;

    showModalBottomSheet(
      context: context,
      backgroundColor: navy,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metric('Words', '$words'),
              _metric('Characters', '$chars'),
              _metric('Paragraphs', '$paragraphs'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }

  Future<Uint8List> _buildPrintPdf(PdfPageFormat format) async {
    final document = pw.Document();
    final text = _controller.document.toPlainText();

    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(42),
        build: (_) => [
          pw.Text(
            text,
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
    return document.save();
  }

  void _printPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Print Preview')),
          body: PdfPreview(
            build: _buildPrintPdf,
            allowPrinting: true,
            allowSharing: true,
            canChangeOrientation: true,
            canChangePageFormat: true,
            pdfFileName: 'ASTRA_DOCUMENT.pdf',
          ),
        ),
      ),
    );
  }

  void _coming(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature: native document engine work is next.')),
    );
  }

  double get _pageAspect {
    double portrait;
    switch (_pageSize) {
      case 'Letter':
        portrait = 11 / 8.5;
        break;
      case 'Legal':
        portrait = 14 / 8.5;
        break;
      default:
        portrait = 297 / 210;
    }
    return _landscape ? 1 / portrait : portrait;
  }

  EdgeInsets get _pagePadding {
    switch (_marginPreset) {
      case 'Narrow':
        return const EdgeInsets.all(24);
      case 'Wide':
        return const EdgeInsets.all(60);
      default:
        return const EdgeInsets.fromLTRB(42, 48, 42, 56);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.path == null
        ? 'New Document'
        : widget.path!.split('/').last;

    return Scaffold(
      backgroundColor: const Color(0xFF06152F),
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: _controller.hasUndo ? _controller.undo : null,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: _quickSave,
            icon: const Icon(Icons.save_rounded),
          ),
          IconButton(
            tooltip: 'Save as',
            onPressed: _saveAs,
            icon: const Icon(Icons.save_as_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Home'),
            Tab(text: 'Insert'),
            Tab(text: 'Layout'),
            Tab(text: 'View'),
            Tab(text: 'Review'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 118,
                  child: TabBarView(
                    controller: _tabs,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _homeRibbon(),
                      _insertRibbon(),
                      _layoutRibbon(),
                      _viewRibbon(),
                      _reviewRibbon(),
                    ],
                  ),
                ),
                if (widget.isDocx)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    color: const Color(0xFF5F4A11),
                    child: const Text(
                      'Rich editing active • Full DOCX formatting round-trip is the next engine milestone',
                      style: TextStyle(
                        color: Color(0xFFFFE394),
                        fontSize: 10,
                      ),
                    ),
                  ),
                Expanded(child: _documentCanvas()),
                _statusBar(),
              ],
            ),
    );
  }

  Widget _documentCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxAvailable = math.max(280.0, constraints.maxWidth - 24);
        final pageWidth = _fitPageWidth
            ? maxAvailable
            : math.min(maxAvailable, 540.0);
        final pageHeight = math.max(700.0, pageWidth * _pageAspect);

        return Container(
          color: _printLayout
              ? const Color(0xFFCBD1DA)
              : Colors.white,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: _printLayout ? 12 : 0,
              vertical: _printLayout ? 18 : 0,
            ),
            child: Center(
              child: Container(
                width: pageWidth,
                constraints: BoxConstraints(minHeight: pageHeight),
                padding: _pagePadding,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_printLayout ? 2 : 0),
                  boxShadow: _printLayout
                      ? const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Theme(
                  data: ThemeData.light(useMaterial3: true),
                  child: QuillEditor.basic(
                    controller: _controller,
                    config: const QuillEditorConfig(
                      padding: EdgeInsets.zero,
                      expands: false,
                      placeholder: 'Start typing…',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _homeRibbon() {
    return _scrollRibbon([
      _tool(Icons.undo_rounded, 'Undo',
          _controller.hasUndo ? _controller.undo : null),
      _tool(Icons.redo_rounded, 'Redo',
          _controller.hasRedo ? _controller.redo : null),
      _tool(Icons.content_cut_rounded, 'Cut', _cut),
      _tool(Icons.copy_rounded, 'Copy', _copy),
      _tool(Icons.content_paste_rounded, 'Paste', _paste),
      _fontMenu(),
      _sizeMenu(),
      _tool(
        Icons.text_decrease_rounded,
        'Size −',
        () => _changeFontSize(-1),
      ),
      _tool(
        Icons.text_increase_rounded,
        'Size +',
        () => _changeFontSize(1),
      ),
      _tool(
        Icons.format_bold_rounded,
        'Bold',
        () => _toggle(Attribute.bold),
        selected: _isActive(Attribute.bold),
      ),
      _tool(
        Icons.format_italic_rounded,
        'Italic',
        () => _toggle(Attribute.italic),
        selected: _isActive(Attribute.italic),
      ),
      _tool(
        Icons.format_underlined_rounded,
        'Underline',
        () => _toggle(Attribute.underline),
        selected: _isActive(Attribute.underline),
      ),
      _tool(
        Icons.format_strikethrough_rounded,
        'Strike',
        () => _toggle(Attribute.strikeThrough),
        selected: _isActive(Attribute.strikeThrough),
      ),
      _tool(
        Icons.superscript_rounded,
        'Super',
        () => _toggle(Attribute.superscript),
        selected: _isActive(Attribute.superscript),
      ),
      _tool(
        Icons.subscript_rounded,
        'Sub',
        () => _toggle(Attribute.subscript),
        selected: _isActive(Attribute.subscript),
      ),
      _colorMenu(false),
      _colorMenu(true),
      _headingMenu(),
      _alignMenu(),
      _tool(
        Icons.format_list_bulleted_rounded,
        'Bullets',
        () => _toggle(Attribute.ul),
        selected: _isActive(Attribute.ul),
      ),
      _tool(
        Icons.format_list_numbered_rounded,
        'Numbering',
        () => _toggle(Attribute.ol),
        selected: _isActive(Attribute.ol),
      ),
      _tool(
        Icons.format_indent_decrease_rounded,
        'Indent −',
        () => _controller.indentSelection(false),
      ),
      _tool(
        Icons.format_indent_increase_rounded,
        'Indent +',
        () => _controller.indentSelection(true),
      ),
      _tool(
        Icons.format_clear_rounded,
        'Clear',
        _clearFormatting,
      ),
    ]);
  }

  Widget _insertRibbon() {
    return _scrollRibbon([
      _tool(
        Icons.table_chart_rounded,
        'Table',
        () => _coming('Table insertion'),
      ),
      _tool(
        Icons.image_rounded,
        'Picture',
        () => _coming('Image insertion'),
      ),
      _tool(
        Icons.photo_camera_rounded,
        'Camera',
        () => _coming('Camera image'),
      ),
      _tool(
        Icons.category_outlined,
        'Shapes',
        () => _coming('Shapes'),
      ),
      _tool(
        Icons.text_fields_rounded,
        'Text box',
        () => _coming('Text box'),
      ),
      _tool(
        Icons.link_rounded,
        'Link',
        _insertLink,
      ),
      _tool(
        Icons.horizontal_rule_rounded,
        'Page break',
        () => _coming('True page break'),
      ),
      _tool(
        Icons.vertical_align_top_rounded,
        'Header',
        () => _coming('Header'),
      ),
      _tool(
        Icons.vertical_align_bottom_rounded,
        'Footer',
        () => _coming('Footer'),
      ),
      _tool(
        Icons.pin_rounded,
        'Page no.',
        () => _coming('Page numbering'),
      ),
      _tool(
        Icons.calendar_month_rounded,
        'Date/Time',
        _insertDateTime,
      ),
      _tool(
        Icons.functions_rounded,
        'Symbol',
        _insertSymbol,
      ),
    ]);
  }

  Widget _layoutRibbon() {
    return _scrollRibbon([
      _pageSizeMenu(),
      _tool(
        _landscape
            ? Icons.stay_current_landscape_rounded
            : Icons.stay_current_portrait_rounded,
        _landscape ? 'Landscape' : 'Portrait',
        () => setState(() => _landscape = !_landscape),
        selected: _landscape,
      ),
      _marginMenu(),
      _tool(
        Icons.view_week_outlined,
        'Columns',
        () => _coming('Page columns'),
      ),
      _tool(
        Icons.format_line_spacing_rounded,
        'Line space',
        () => _coming('Advanced line spacing'),
      ),
      _tool(
        Icons.space_bar_rounded,
        'Paragraph',
        () => _coming('Paragraph spacing'),
      ),
      _tool(
        Icons.format_indent_decrease_rounded,
        'Left indent',
        () => _controller.indentSelection(false),
      ),
      _tool(
        Icons.format_indent_increase_rounded,
        'Right indent',
        () => _controller.indentSelection(true),
      ),
    ]);
  }

  Widget _viewRibbon() {
    return _scrollRibbon([
      _tool(
        Icons.article_outlined,
        'Print layout',
        () => setState(() => _printLayout = !_printLayout),
        selected: _printLayout,
      ),
      _tool(
        Icons.fit_screen_rounded,
        'Page width',
        () => setState(() => _fitPageWidth = !_fitPageWidth),
        selected: _fitPageWidth,
      ),
      _tool(
        Icons.zoom_out_rounded,
        'Zoom −',
        () => _coming('Interactive zoom'),
      ),
      _tool(
        Icons.zoom_in_rounded,
        'Zoom +',
        () => _coming('Interactive zoom'),
      ),
      _tool(
        Icons.fullscreen_rounded,
        'Full screen',
        () => _coming('Full screen editing'),
      ),
      _tool(
        Icons.straighten_rounded,
        'Ruler',
        () => _coming('Ruler'),
      ),
      _tool(
        Icons.print_rounded,
        'Preview',
        _printPreview,
      ),
      _tool(
        Icons.print_outlined,
        'Print',
        () => Printing.layoutPdf(onLayout: _buildPrintPdf),
      ),
    ]);
  }

  Widget _reviewRibbon() {
    return _scrollRibbon([
      _tool(
        Icons.search_rounded,
        'Find',
        _findReplaceDialog,
      ),
      _tool(
        Icons.find_replace_rounded,
        'Replace',
        _findReplaceDialog,
      ),
      _tool(
        Icons.select_all_rounded,
        'Select all',
        _selectAll,
      ),
      _tool(
        Icons.calculate_outlined,
        'Word count',
        _showWordCount,
      ),
      _tool(
        Icons.spellcheck_rounded,
        'Spelling',
        () => _coming('Spell checking'),
      ),
      _tool(
        Icons.comment_outlined,
        'Comment',
        () => _coming('Comments'),
      ),
      _tool(
        Icons.track_changes_rounded,
        'Track',
        () => _coming('Track changes'),
      ),
      _tool(
        Icons.compare_arrows_rounded,
        'Compare',
        () => _coming('Document compare'),
      ),
    ]);
  }

  Widget _scrollRibbon(List<Widget> children) {
    return Container(
      color: panel,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(children: children),
      ),
    );
  }

  Widget _tool(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool selected = false,
  }) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 62,
          height: 96,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF173E78)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: const Color(0xFF4E93EE))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 25,
                color: enabled ? accent : Colors.white24,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.white24,
                  fontSize: 9.5,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _popupShell(IconData icon, String label, {bool selected = false}) {
    return Container(
      width: 72,
      height: 96,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF173E78) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 25, color: accent),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9.5,
              height: 1.05,
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded, color: Colors.white38, size: 15),
        ],
      ),
    );
  }

  Widget _fontMenu() {
    const fonts = [
      'Roboto',
      'Arial',
      'Calibri',
      'Times New Roman',
      'serif',
      'sans-serif',
      'monospace',
    ];
    return PopupMenuButton<String>(
      tooltip: 'Font',
      onSelected: (value) => _setAttr(Attribute.font.key, value),
      itemBuilder: (_) => fonts
          .map((font) => PopupMenuItem(value: font, child: Text(font)))
          .toList(),
      child: _popupShell(Icons.font_download_outlined, _fontLabel),
    );
  }

  Widget _sizeMenu() {
    const sizes = <double>[
      8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 72
    ];
    return PopupMenuButton<double>(
      tooltip: 'Font size',
      onSelected: (value) => _setAttr(Attribute.size.key, value),
      itemBuilder: (_) => sizes
          .map(
            (size) => PopupMenuItem(
              value: size,
              child: Text(size.toInt().toString()),
            ),
          )
          .toList(),
      child: _popupShell(
        Icons.format_size_rounded,
        _fontSize.toInt().toString(),
      ),
    );
  }

  Widget _headingMenu() {
    return PopupMenuButton<int>(
      tooltip: 'Style',
      onSelected: (value) {
        if (value == 0) {
          _setAttr(Attribute.header.key, null);
        } else {
          _setAttr(Attribute.header.key, value);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 0, child: Text('Normal')),
        PopupMenuItem(value: 1, child: Text('Heading 1')),
        PopupMenuItem(value: 2, child: Text('Heading 2')),
        PopupMenuItem(value: 3, child: Text('Heading 3')),
      ],
      child: _popupShell(Icons.title_rounded, 'Styles'),
    );
  }

  Widget _alignMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Alignment',
      onSelected: (value) {
        _setAttr(
          Attribute.align.key,
          value == 'left' ? null : value,
        );
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'left', child: Text('Align left')),
        PopupMenuItem(value: 'center', child: Text('Center')),
        PopupMenuItem(value: 'right', child: Text('Align right')),
        PopupMenuItem(value: 'justify', child: Text('Justify')),
      ],
      child: _popupShell(Icons.format_align_left_rounded, 'Align'),
    );
  }

  Widget _colorMenu(bool background) {
    const colors = <String, String>{
      'Black': '#000000',
      'Red': '#E53935',
      'Blue': '#1E88E5',
      'Green': '#2E7D32',
      'Orange': '#F57C00',
      'Purple': '#8E24AA',
      'Yellow': '#FFF176',
      'Clear': '',
    };
    return PopupMenuButton<String>(
      tooltip: background ? 'Highlight' : 'Font color',
      onSelected: (value) => _setAttr(
        background ? Attribute.background.key : Attribute.color.key,
        value.isEmpty ? null : value,
      ),
      itemBuilder: (_) => colors.entries
          .map(
            (entry) => PopupMenuItem(
              value: entry.value,
              child: Text(entry.key),
            ),
          )
          .toList(),
      child: _popupShell(
        background
            ? Icons.format_color_fill_rounded
            : Icons.format_color_text_rounded,
        background ? 'Highlight' : 'Color',
      ),
    );
  }

  Widget _pageSizeMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Page size',
      onSelected: (value) => setState(() => _pageSize = value),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'A4', child: Text('A4')),
        PopupMenuItem(value: 'Letter', child: Text('Letter')),
        PopupMenuItem(value: 'Legal', child: Text('Legal')),
      ],
      child: _popupShell(Icons.description_outlined, _pageSize),
    );
  }

  Widget _marginMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Margins',
      onSelected: (value) => setState(() => _marginPreset = value),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'Narrow', child: Text('Narrow')),
        PopupMenuItem(value: 'Normal', child: Text('Normal')),
        PopupMenuItem(value: 'Wide', child: Text('Wide')),
      ],
      child: _popupShell(Icons.border_outer_rounded, _marginPreset),
    );
  }

  Widget _statusBar() {
    final plain = _controller.document.toPlainText().trim();
    final words = plain.isEmpty
        ? 0
        : plain.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length;

    return Container(
      height: 34,
      color: navy,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Text(
            'Page 1',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(width: 16),
          Text(
            'Words: $words',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const Spacer(),
          Text(
            '$_pageSize • ${_landscape ? 'Landscape' : 'Portrait'}',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
