import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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

class _TextEditorScreenState extends State<TextEditorScreen> {
  late QuillController _controller;
  late FocusNode _editorFocusNode;
  late ScrollController _editorScrollController;

  bool _loading = true;
  String? _sourcePath;
  String? _lastSavedPath;

  String _pageSize = 'A4';
  String _marginPreset = 'Normal';
  bool _landscape = false;
  bool _printLayout = true;
  bool _fitPageWidth = true;
  bool _toolsPinned = true;

  static const wordBlue = Color(0xFF185ABD);
  static const wordBlueDark = Color(0xFF114B98);
  static const accent = Color(0xFF185ABD);

  @override
  void initState() {
    super.initState();
    _editorFocusNode = FocusNode(debugLabel: 'ASTRA document editor');
    _editorScrollController = ScrollController();
    _controller = QuillController.basic();
    _controller.addListener(_onEditorChanged);

    // New documents should always start with readable black text.
    _controller.formatSelection(const ColorAttribute('#000000'));
    _load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onEditorChanged);
    _controller.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
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
        var loadedRichSidecar = false;

        if (await sidecar.exists()) {
          final raw = await sidecar.readAsString();
          final data = jsonDecode(raw) as List<dynamic>;
          document = Document.fromJson(data);
          loadedRichSidecar = true;
        } else {
          final text = widget.isDocx
              ? await DocxService().readPlainText(widget.path!)
              : await File(widget.path!).readAsString();

          document = Document();
          if (text.isNotEmpty) {
            document.insert(0, text);
          }
        }

        _controller.removeListener(_onEditorChanged);
        _controller.dispose();

        _controller = QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _controller.addListener(_onEditorChanged);

        // Plain imports have no preserved rich color information yet.
        // Force them to readable black. Sidecar-rich documents keep their colors.
        if (!loadedRichSidecar) {
          final contentLength = math.max(0, document.length - 1);
          if (contentLength > 0) {
            _controller.formatText(
              0,
              contentLength,
              const ColorAttribute('#000000'),
            );
          }
          _controller.moveCursorToEnd();
          _controller.formatSelection(const ColorAttribute('#000000'));
        }
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

  void _focusEditor() {
    if (!_editorFocusNode.hasFocus) {
      FocusScope.of(context).requestFocus(_editorFocusNode);
    }
    Future<void>.delayed(const Duration(milliseconds: 80), () async {
      if (!mounted || !_editorFocusNode.hasFocus) return;
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
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
                'Native new-DOCX creation requires the DOCX round-trip engine, which is the next core-engine milestone.',
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
      'line-height',
    ];
    for (final key in keys) {
      _controller.formatSelection(Attribute.fromKeyValue(key, null));
    }
    _controller.formatSelection(const ColorAttribute('#000000'));
  }

  String get _fontLabel =>
      _style[Attribute.font.key]?.value?.toString() ?? 'Default';

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
    return 12;
  }

  void _changeFontSize(double delta) {
    final next = (_fontSize + delta).clamp(8.0, 96.0);
    _setAttr(Attribute.size.key, next);
  }

  Future<void> _copy() async {
    final text = _controller.getPlainText();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
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
    url.dispose();
    if (result == null || result.isEmpty) return;
    _setAttr(Attribute.link.key, result);
  }

  Future<void> _insertSymbol() async {
    const symbols = [
      '©', '®', '™', '₹', '€', '£', '°', '±', '×', '÷', '✓', '•',
      '→', '←', '↑', '↓', '∞', '≈', '≠', '≤', '≥', 'π', 'Ω', '§'
    ];

    final symbol = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
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
                        color: Colors.black87,
                        fontSize: 25,
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
              if (find.text.isNotEmpty) _findNext(find.text);
            },
            child: const Text('Find next'),
          ),
          FilledButton(
            onPressed: () {
              if (find.text.isEmpty) return;
              final count = _replaceAll(find.text, replace.text);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Replaced $count occurrence(s)')),
              );
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

    var index = plain
        .toLowerCase()
        .indexOf(query.toLowerCase(), _controller.selection.end);

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
    final paragraphs = text.isEmpty
        ? 0
        : text
            .split(RegExp(r'\n+'))
            .where((e) => e.trim().isNotEmpty)
            .length;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Word Count'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _countRow('Words', words),
            _countRow('Characters', chars),
            _countRow('Paragraphs', paragraphs),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _countRow(String label, int value) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        '$value',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
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
      SnackBar(
        content: Text(
          '$feature is present in the Word command shell; native implementation is being added in the editor-engine phases.',
        ),
      ),
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

  Future<void> _showWordRibbon() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      barrierColor: Colors.black38,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        var expandedPanel = false;
        return DefaultTabController(
          length: 8,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              void refresh() => setSheetState(() {});

              return SizedBox(
                height: MediaQuery.of(context).size.height *
                    (expandedPanel ? 0.80 : 0.50),
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      width: 40,
                      margin: const EdgeInsets.only(top: 6, bottom: 2),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Document Tools',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: expandedPanel
                                ? 'Compact panel'
                                : 'Expand panel',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setSheetState(() {
                                expandedPanel = !expandedPanel;
                              });
                            },
                            icon: Icon(
                              expandedPanel
                                  ? Icons.unfold_less_rounded
                                  : Icons.unfold_more_rounded,
                              size: 21,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded, size: 21),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    const TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: Colors.black87,
                      unselectedLabelColor: Colors.black54,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: TextStyle(fontSize: 12),
                      indicatorColor: accent,
                      indicatorWeight: 2.5,
                      dividerHeight: 0,
                      tabs: [
                        Tab(text: 'Home'),
                        Tab(text: 'Insert'),
                        Tab(text: 'Design'),
                        Tab(text: 'Layout'),
                        Tab(text: 'References'),
                        Tab(text: 'Mailings'),
                        Tab(text: 'Review'),
                        Tab(text: 'View'),
                      ],
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _homePane(refresh),
                          _insertPane(refresh),
                          _designPane(refresh),
                          _layoutPane(refresh),
                          _referencesPane(),
                          _mailingsPane(),
                          _reviewPane(refresh),
                          _viewPane(refresh, sheetContext),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _homePane(VoidCallback refresh) {
    return _paneList([
      _sectionTitle('Font Format'),
      _card(
        child: Column(
          children: [
            Row(
              children: [
                _bigFormatButton(
                  'B',
                  _isActive(Attribute.bold),
                  () {
                    _toggle(Attribute.bold);
                    refresh();
                  },
                  fontWeight: FontWeight.w900,
                ),
                _bigFormatButton(
                  'I',
                  _isActive(Attribute.italic),
                  () {
                    _toggle(Attribute.italic);
                    refresh();
                  },
                  fontStyle: FontStyle.italic,
                ),
                _bigFormatButton(
                  'U',
                  _isActive(Attribute.underline),
                  () {
                    _toggle(Attribute.underline);
                    refresh();
                  },
                  decoration: TextDecoration.underline,
                ),
                _bigFormatButton(
                  'ab',
                  _isActive(Attribute.strikeThrough),
                  () {
                    _toggle(Attribute.strikeThrough);
                    refresh();
                  },
                  decoration: TextDecoration.lineThrough,
                ),
                _bigFormatButton(
                  'x²',
                  _isActive(Attribute.superscript),
                  () {
                    _toggle(Attribute.superscript);
                    refresh();
                  },
                ),
                _iconFormatButton(
                  Icons.more_horiz_rounded,
                  () => _showMoreFontCommands(refresh),
                ),
              ],
            ),
            const Divider(height: 1),
            _stylesRow(refresh),
            const Divider(height: 1),
            _fontFamilyRow(refresh),
            const Divider(height: 1),
            _fontSizeRow(refresh),
            const Divider(height: 1),
            _fontColorsRow(refresh),
          ],
        ),
      ),
      _sectionTitle('Clipboard'),
      _card(
        child: Row(
          children: [
            _commandCell(Icons.content_paste_rounded, 'Paste', _paste),
            _commandCell(Icons.content_cut_rounded, 'Cut', _cut),
            _commandCell(Icons.copy_rounded, 'Copy', _copy),
            _commandCell(
              Icons.format_paint_rounded,
              'Format Painter',
              () => _coming('Format Painter'),
            ),
          ],
        ),
      ),
      _sectionTitle('Paragraph'),
      _card(
        child: Wrap(
          spacing: 3,
          runSpacing: 3,
          children: [
            _smallCommand(Icons.format_list_bulleted_rounded, 'Bullets', () {
              _toggle(Attribute.ul);
              refresh();
            }),
            _smallCommand(Icons.format_list_numbered_rounded, 'Numbering', () {
              _toggle(Attribute.ol);
              refresh();
            }),
            _smallCommand(
              Icons.format_indent_decrease_rounded,
              'Decrease indent',
              () => _controller.indentSelection(false),
            ),
            _smallCommand(
              Icons.format_indent_increase_rounded,
              'Increase indent',
              () => _controller.indentSelection(true),
            ),
            _smallCommand(Icons.format_align_left_rounded, 'Left', () {
              _setAttr(Attribute.align.key, null);
              refresh();
            }),
            _smallCommand(Icons.format_align_center_rounded, 'Center', () {
              _setAttr(Attribute.align.key, 'center');
              refresh();
            }),
            _smallCommand(Icons.format_align_right_rounded, 'Right', () {
              _setAttr(Attribute.align.key, 'right');
              refresh();
            }),
            _smallCommand(Icons.format_align_justify_rounded, 'Justify', () {
              _setAttr(Attribute.align.key, 'justify');
              refresh();
            }),
            _smallCommand(
              Icons.format_line_spacing_rounded,
              'Line spacing',
              () => _showLineSpacing(refresh),
            ),
            _smallCommand(
              Icons.border_all_rounded,
              'Borders',
              () => _coming('Paragraph Borders'),
            ),
            _smallCommand(
              Icons.format_color_fill_rounded,
              'Shading',
              () => _coming('Paragraph Shading'),
            ),
          ],
        ),
      ),
      _sectionTitle('Editing'),
      _card(
        child: Row(
          children: [
            _commandCell(Icons.search_rounded, 'Find', _findReplaceDialog),
            _commandCell(Icons.find_replace_rounded, 'Replace', _findReplaceDialog),
            _commandCell(Icons.select_all_rounded, 'Select', _selectAll),
          ],
        ),
      ),
    ]);
  }

  Widget _insertPane(VoidCallback refresh) {
    return _paneList([
      _sectionTitle('Pages'),
      _groupGrid([
        _Cmd(Icons.note_add_outlined, 'Cover Page', () => _coming('Cover Page')),
        _Cmd(Icons.insert_page_break_rounded, 'Blank Page', () => _coming('Blank Page')),
        _Cmd(Icons.horizontal_rule_rounded, 'Page Break', () => _coming('Page Break')),
      ]),
      _sectionTitle('Tables'),
      _groupGrid([
        _Cmd(Icons.table_chart_rounded, 'Table', () => _coming('Table')),
      ]),
      _sectionTitle('Illustrations'),
      _groupGrid([
        _Cmd(Icons.image_outlined, 'Pictures', () => _coming('Pictures')),
        _Cmd(Icons.photo_camera_outlined, 'Camera', () => _coming('Camera Picture')),
        _Cmd(Icons.category_outlined, 'Shapes', () => _coming('Shapes')),
        _Cmd(Icons.insert_chart_outlined, 'Chart', () => _coming('Chart')),
        _Cmd(Icons.account_tree_outlined, 'SmartArt', () => _coming('SmartArt')),
        _Cmd(Icons.screenshot_monitor_outlined, 'Screenshot', () => _coming('Screenshot')),
      ]),
      _sectionTitle('Links'),
      _groupGrid([
        _Cmd(Icons.link_rounded, 'Link', _insertLink),
        _Cmd(Icons.bookmark_border_rounded, 'Bookmark', () => _coming('Bookmark')),
        _Cmd(Icons.device_hub_rounded, 'Cross-reference', () => _coming('Cross-reference')),
      ]),
      _sectionTitle('Header & Footer'),
      _groupGrid([
        _Cmd(Icons.vertical_align_top_rounded, 'Header', () => _coming('Header')),
        _Cmd(Icons.vertical_align_bottom_rounded, 'Footer', () => _coming('Footer')),
        _Cmd(Icons.pin_rounded, 'Page Number', () => _coming('Page Number')),
      ]),
      _sectionTitle('Text'),
      _groupGrid([
        _Cmd(Icons.text_fields_rounded, 'Text Box', () => _coming('Text Box')),
        _Cmd(Icons.auto_awesome_motion_rounded, 'Quick Parts', () => _coming('Quick Parts')),
        _Cmd(Icons.text_format_rounded, 'WordArt', () => _coming('WordArt')),
        _Cmd(Icons.format_size_rounded, 'Drop Cap', () => _coming('Drop Cap')),
        _Cmd(Icons.calendar_month_rounded, 'Date & Time', _insertDateTime),
        _Cmd(Icons.attach_file_rounded, 'Object', () => _coming('Object')),
      ]),
      _sectionTitle('Symbols'),
      _groupGrid([
        _Cmd(Icons.functions_rounded, 'Equation', () => _coming('Equation')),
        _Cmd(Icons.emoji_symbols_rounded, 'Symbol', _insertSymbol),
      ]),
    ]);
  }

  Widget _designPane(VoidCallback refresh) {
    return _paneList([
      _sectionTitle('Document Formatting'),
      _groupGrid([
        _Cmd(Icons.auto_awesome_rounded, 'Themes', () => _coming('Themes')),
        _Cmd(Icons.palette_outlined, 'Colors', () => _coming('Theme Colors')),
        _Cmd(Icons.font_download_outlined, 'Fonts', () => _coming('Theme Fonts')),
        _Cmd(Icons.space_bar_rounded, 'Paragraph Spacing', () => _coming('Paragraph Spacing')),
        _Cmd(Icons.auto_fix_high_outlined, 'Effects', () => _coming('Theme Effects')),
        _Cmd(Icons.restart_alt_rounded, 'Set as Default', () => _coming('Set as Default')),
      ]),
      _sectionTitle('Page Background'),
      _groupGrid([
        _Cmd(Icons.opacity_rounded, 'Watermark', () => _coming('Watermark')),
        _Cmd(Icons.format_color_fill_rounded, 'Page Color', () => _coming('Page Color')),
        _Cmd(Icons.border_outer_rounded, 'Page Borders', () => _coming('Page Borders')),
      ]),
    ]);
  }

  Widget _layoutPane(VoidCallback refresh) {
    return _paneList([
      _sectionTitle('Page Setup'),
      _card(
        child: Column(
          children: [
            _choiceRow(
              Icons.border_outer_rounded,
              'Margins',
              _marginPreset,
              ['Narrow', 'Normal', 'Wide'],
              (value) {
                setState(() => _marginPreset = value);
                refresh();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.screen_rotation_alt_rounded),
              title: const Text('Orientation'),
              trailing: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Portrait')),
                  ButtonSegment(value: true, label: Text('Landscape')),
                ],
                selected: {_landscape},
                onSelectionChanged: (values) {
                  setState(() => _landscape = values.first);
                  refresh();
                },
              ),
            ),
            const Divider(height: 1),
            _choiceRow(
              Icons.description_outlined,
              'Size',
              _pageSize,
              ['A4', 'Letter', 'Legal'],
              (value) {
                setState(() => _pageSize = value);
                refresh();
              },
            ),
          ],
        ),
      ),
      _groupGrid([
        _Cmd(Icons.view_week_outlined, 'Columns', () => _coming('Columns')),
        _Cmd(Icons.call_split_rounded, 'Breaks', () => _coming('Breaks')),
        _Cmd(Icons.format_list_numbered_rounded, 'Line Numbers', () => _coming('Line Numbers')),
        _Cmd(Icons.text_rotation_none_rounded, 'Hyphenation', () => _coming('Hyphenation')),
      ]),
      _sectionTitle('Paragraph'),
      _groupGrid([
        _Cmd(Icons.format_indent_decrease_rounded, 'Indent Left', () => _controller.indentSelection(false)),
        _Cmd(Icons.format_indent_increase_rounded, 'Indent Right', () => _controller.indentSelection(true)),
        _Cmd(Icons.vertical_align_top_rounded, 'Spacing Before', () => _coming('Spacing Before')),
        _Cmd(Icons.vertical_align_bottom_rounded, 'Spacing After', () => _coming('Spacing After')),
      ]),
      _sectionTitle('Arrange'),
      _groupGrid([
        _Cmd(Icons.layers_outlined, 'Position', () => _coming('Position')),
        _Cmd(Icons.wrap_text_rounded, 'Wrap Text', () => _coming('Wrap Text')),
        _Cmd(Icons.vertical_align_top_rounded, 'Bring Forward', () => _coming('Bring Forward')),
        _Cmd(Icons.vertical_align_bottom_rounded, 'Send Backward', () => _coming('Send Backward')),
        _Cmd(Icons.align_horizontal_left_rounded, 'Align', () => _coming('Object Align')),
        _Cmd(Icons.group_work_outlined, 'Group', () => _coming('Group Objects')),
        _Cmd(Icons.rotate_right_rounded, 'Rotate', () => _coming('Rotate Object')),
      ]),
    ]);
  }

  Widget _referencesPane() {
    return _paneList([
      _sectionTitle('Table of Contents'),
      _groupGrid([
        _Cmd(Icons.toc_rounded, 'Table of Contents', () => _coming('Table of Contents')),
        _Cmd(Icons.add_link_rounded, 'Add Text', () => _coming('Add TOC Text')),
        _Cmd(Icons.refresh_rounded, 'Update Table', () => _coming('Update Table of Contents')),
      ]),
      _sectionTitle('Footnotes'),
      _groupGrid([
        _Cmd(Icons.format_list_numbered_rounded, 'Insert Footnote', () => _coming('Footnote')),
        _Cmd(Icons.format_list_numbered_rtl_rounded, 'Insert Endnote', () => _coming('Endnote')),
        _Cmd(Icons.skip_next_rounded, 'Next Footnote', () => _coming('Next Footnote')),
        _Cmd(Icons.note_alt_outlined, 'Show Notes', () => _coming('Show Notes')),
      ]),
      _sectionTitle('Citations & Bibliography'),
      _groupGrid([
        _Cmd(Icons.format_quote_rounded, 'Insert Citation', () => _coming('Insert Citation')),
        _Cmd(Icons.source_outlined, 'Manage Sources', () => _coming('Manage Sources')),
        _Cmd(Icons.style_outlined, 'Style', () => _coming('Citation Style')),
        _Cmd(Icons.menu_book_outlined, 'Bibliography', () => _coming('Bibliography')),
      ]),
      _sectionTitle('Captions'),
      _groupGrid([
        _Cmd(Icons.closed_caption_outlined, 'Insert Caption', () => _coming('Insert Caption')),
        _Cmd(Icons.table_rows_outlined, 'Table of Figures', () => _coming('Table of Figures')),
        _Cmd(Icons.refresh_rounded, 'Update Table', () => _coming('Update Table of Figures')),
        _Cmd(Icons.device_hub_rounded, 'Cross-reference', () => _coming('Cross-reference')),
      ]),
      _sectionTitle('Index'),
      _groupGrid([
        _Cmd(Icons.bookmark_add_outlined, 'Mark Entry', () => _coming('Mark Index Entry')),
        _Cmd(Icons.list_alt_rounded, 'Insert Index', () => _coming('Insert Index')),
        _Cmd(Icons.refresh_rounded, 'Update Index', () => _coming('Update Index')),
      ]),
      _sectionTitle('Table of Authorities'),
      _groupGrid([
        _Cmd(Icons.gavel_outlined, 'Mark Citation', () => _coming('Mark Citation')),
        _Cmd(Icons.account_balance_outlined, 'Insert Authorities', () => _coming('Table of Authorities')),
        _Cmd(Icons.refresh_rounded, 'Update Table', () => _coming('Update Authorities')),
      ]),
    ]);
  }

  Widget _mailingsPane() {
    return _paneList([
      _sectionTitle('Create'),
      _groupGrid([
        _Cmd(Icons.mail_outline_rounded, 'Envelopes', () => _coming('Envelopes')),
        _Cmd(Icons.label_outline_rounded, 'Labels', () => _coming('Labels')),
      ]),
      _sectionTitle('Start Mail Merge'),
      _groupGrid([
        _Cmd(Icons.merge_type_rounded, 'Start Mail Merge', () => _coming('Start Mail Merge')),
        _Cmd(Icons.people_outline_rounded, 'Select Recipients', () => _coming('Select Recipients')),
        _Cmd(Icons.edit_note_rounded, 'Edit Recipient List', () => _coming('Edit Recipient List')),
      ]),
      _sectionTitle('Write & Insert Fields'),
      _groupGrid([
        _Cmd(Icons.location_on_outlined, 'Address Block', () => _coming('Address Block')),
        _Cmd(Icons.waving_hand_outlined, 'Greeting Line', () => _coming('Greeting Line')),
        _Cmd(Icons.data_object_rounded, 'Insert Merge Field', () => _coming('Insert Merge Field')),
        _Cmd(Icons.rule_rounded, 'Rules', () => _coming('Mail Merge Rules')),
        _Cmd(Icons.rule_rounded, 'Match Fields', () => _coming('Match Fields')),
        _Cmd(Icons.label_important_outline_rounded, 'Update Labels', () => _coming('Update Labels')),
      ]),
      _sectionTitle('Preview Results'),
      _groupGrid([
        _Cmd(Icons.preview_outlined, 'Preview Results', () => _coming('Preview Results')),
        _Cmd(Icons.navigate_before_rounded, 'Previous Record', () => _coming('Previous Record')),
        _Cmd(Icons.navigate_next_rounded, 'Next Record', () => _coming('Next Record')),
        _Cmd(Icons.person_search_outlined, 'Find Recipient', () => _coming('Find Recipient')),
        _Cmd(Icons.fact_check_outlined, 'Check for Errors', () => _coming('Mail Merge Error Check')),
      ]),
      _sectionTitle('Finish'),
      _groupGrid([
        _Cmd(Icons.done_all_rounded, 'Finish & Merge', () => _coming('Finish & Merge')),
      ]),
    ]);
  }

  Widget _reviewPane(VoidCallback refresh) {
    return _paneList([
      _sectionTitle('Proofing'),
      _groupGrid([
        _Cmd(Icons.spellcheck_rounded, 'Spelling & Grammar', () => _coming('Spelling & Grammar')),
        _Cmd(Icons.menu_book_outlined, 'Thesaurus', () => _coming('Thesaurus')),
        _Cmd(Icons.calculate_outlined, 'Word Count', _showWordCount),
      ]),
      _sectionTitle('Language'),
      _groupGrid([
        _Cmd(Icons.translate_rounded, 'Translate', () => _coming('Translate')),
        _Cmd(Icons.language_rounded, 'Language', () => _coming('Proofing Language')),
      ]),
      _sectionTitle('Comments'),
      _groupGrid([
        _Cmd(Icons.add_comment_outlined, 'New Comment', () => _coming('New Comment')),
        _Cmd(Icons.delete_outline_rounded, 'Delete', () => _coming('Delete Comment')),
        _Cmd(Icons.navigate_before_rounded, 'Previous', () => _coming('Previous Comment')),
        _Cmd(Icons.navigate_next_rounded, 'Next', () => _coming('Next Comment')),
        _Cmd(Icons.comments_disabled_outlined, 'Show Comments', () => _coming('Show Comments')),
      ]),
      _sectionTitle('Tracking'),
      _groupGrid([
        _Cmd(Icons.track_changes_rounded, 'Track Changes', () => _coming('Track Changes')),
        _Cmd(Icons.tune_rounded, 'Display for Review', () => _coming('Display for Review')),
        _Cmd(Icons.list_alt_rounded, 'Show Markup', () => _coming('Show Markup')),
        _Cmd(Icons.fact_check_outlined, 'Reviewing Pane', () => _coming('Reviewing Pane')),
      ]),
      _sectionTitle('Changes'),
      _groupGrid([
        _Cmd(Icons.check_circle_outline_rounded, 'Accept', () => _coming('Accept Change')),
        _Cmd(Icons.cancel_outlined, 'Reject', () => _coming('Reject Change')),
        _Cmd(Icons.navigate_before_rounded, 'Previous', () => _coming('Previous Change')),
        _Cmd(Icons.navigate_next_rounded, 'Next', () => _coming('Next Change')),
      ]),
      _sectionTitle('Compare & Protect'),
      _groupGrid([
        _Cmd(Icons.compare_arrows_rounded, 'Compare', () => _coming('Compare Documents')),
        _Cmd(Icons.merge_rounded, 'Combine', () => _coming('Combine Documents')),
        _Cmd(Icons.lock_outline_rounded, 'Restrict Editing', () => _coming('Restrict Editing')),
      ]),
      _sectionTitle('Editing'),
      _groupGrid([
        _Cmd(Icons.search_rounded, 'Find', _findReplaceDialog),
        _Cmd(Icons.find_replace_rounded, 'Replace', _findReplaceDialog),
        _Cmd(Icons.select_all_rounded, 'Select All', _selectAll),
      ]),
    ]);
  }

  Widget _viewPane(VoidCallback refresh, BuildContext sheetContext) {
    return _paneList([
      _sectionTitle('Views'),
      _groupGrid([
        _Cmd(Icons.chrome_reader_mode_outlined, 'Read Mode', () => _coming('Read Mode')),
        _Cmd(Icons.article_outlined, 'Print Layout', () {
          setState(() => _printLayout = true);
          refresh();
          Navigator.pop(sheetContext);
        }),
        _Cmd(Icons.web_asset_outlined, 'Web Layout', () => _coming('Web Layout')),
        _Cmd(Icons.view_headline_rounded, 'Outline', () => _coming('Outline View')),
        _Cmd(Icons.drafts_outlined, 'Draft', () => _coming('Draft View')),
      ]),
      _sectionTitle('Show'),
      _groupGrid([
        _Cmd(Icons.straighten_rounded, 'Ruler', () => _coming('Ruler')),
        _Cmd(Icons.grid_on_outlined, 'Gridlines', () => _coming('Gridlines')),
        _Cmd(Icons.view_sidebar_outlined, 'Navigation Pane', () => _coming('Navigation Pane')),
      ]),
      _sectionTitle('Zoom'),
      _groupGrid([
        _Cmd(Icons.zoom_in_rounded, 'Zoom', () => _coming('Interactive Zoom')),
        _Cmd(Icons.filter_1_outlined, '100%', () => _coming('100% Zoom')),
        _Cmd(Icons.looks_one_outlined, 'One Page', () => _coming('One Page')),
        _Cmd(Icons.grid_view_outlined, 'Multiple Pages', () => _coming('Multiple Pages')),
        _Cmd(Icons.fit_screen_rounded, 'Page Width', () {
          setState(() => _fitPageWidth = true);
          refresh();
          Navigator.pop(sheetContext);
        }),
      ]),
      _sectionTitle('Window'),
      _groupGrid([
        _Cmd(Icons.add_box_outlined, 'New Window', () => _coming('New Window')),
        _Cmd(Icons.view_agenda_outlined, 'Arrange All', () => _coming('Arrange All')),
        _Cmd(Icons.call_split_rounded, 'Split', () => _coming('Split Window')),
        _Cmd(Icons.sync_alt_rounded, 'View Side by Side', () => _coming('View Side by Side')),
        _Cmd(Icons.vertical_align_center_rounded, 'Synchronous Scrolling', () => _coming('Synchronous Scrolling')),
        _Cmd(Icons.restart_alt_rounded, 'Reset Window Position', () => _coming('Reset Window Position')),
        _Cmd(Icons.window_outlined, 'Switch Windows', () => _coming('Switch Windows')),
      ]),
      _sectionTitle('Macros & Output'),
      _groupGrid([
        _Cmd(Icons.code_rounded, 'Macros', () => _coming('Macros')),
        _Cmd(Icons.preview_rounded, 'Print Preview', _printPreview),
        _Cmd(Icons.print_rounded, 'Print', () => Printing.layoutPdf(onLayout: _buildPrintPdf)),
      ]),
    ]);
  }

  Future<void> _showMoreFontCommands(VoidCallback refresh) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('More Font Commands'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _dialogChip('Subscript', () {
              _toggle(Attribute.subscript);
              refresh();
            }),
            _dialogChip('Clear Formatting', () {
              _clearFormatting();
              refresh();
            }),
            _dialogChip('Text Effects', () => _coming('Text Effects')),
            _dialogChip('Change Case', () => _coming('Change Case')),
            _dialogChip('Character Spacing', () => _coming('Character Spacing')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _dialogChip(String label, VoidCallback onPressed) {
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
    );
  }

  Future<void> _showLineSpacing(VoidCallback refresh) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Line Spacing'),
        children: ['1.0', '1.15', '1.5', '2.0']
            .map(
              (value) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, value),
                child: Text(value),
              ),
            )
            .toList(),
      ),
    );
    if (choice == null) return;
    _setAttr(Attribute.lineHeight.key, double.parse(choice));
    refresh();
  }

  Widget _stylesRow(VoidCallback refresh) {
    Widget styleButton(String label, int? level) {
      final active = level == null
          ? !_style.containsKey(Attribute.header.key)
          : _style[Attribute.header.key]?.value == level;

      return Expanded(
        child: InkWell(
          onTap: () {
            _setAttr(Attribute.header.key, level);
            refresh();
          },
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFF0F0F0) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black87,
                fontSize: level == 1 ? 13 : 11.5,
                fontWeight: level == null ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          styleButton('Heading\n1', 1),
          styleButton('Heading 2', 2),
          styleButton('Heading 3', 3),
          styleButton('Normal', null),
        ],
      ),
    );
  }

  Widget _fontFamilyRow(VoidCallback refresh) {
    const fonts = [
      'Default',
      'Arial',
      'Calibri',
      'Times New Roman',
      'serif',
      'sans-serif',
      'monospace',
    ];

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      minLeadingWidth: 26,
      leading: const Icon(Icons.font_download_outlined, size: 24),
      title: const Text('Font', style: TextStyle(fontSize: 12)),
      trailing: DropdownButton<String>(
        value: fonts.contains(_fontLabel) ? _fontLabel : 'Default',
        underline: const SizedBox.shrink(),
        onChanged: (value) {
          if (value == null) return;
          _setAttr(
            Attribute.font.key,
            value == 'Default' ? null : value,
          );
          refresh();
        },
        items: fonts
            .map(
              (font) => DropdownMenuItem(
                value: font,
                child: Text(font),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _fontSizeRow(VoidCallback refresh) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      minLeadingWidth: 26,
      leading: const Icon(Icons.format_size_rounded, size: 24),
      title: const Text('Font Size', style: TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              _changeFontSize(-1);
              refresh();
            },
            icon: const Icon(Icons.remove_rounded),
          ),
          Container(
            width: 48,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _fontSize.toInt().toString(),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          IconButton(
            onPressed: () {
              _changeFontSize(1);
              refresh();
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  Widget _fontColorsRow(VoidCallback refresh) {
    const colors = [
      Color(0xFF111111),
      Color(0xFFD7191C),
      Color(0xFFFFB000),
      Color(0xFF7AC943),
      Color(0xFF00A9CE),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: colors.map((color) {
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final hex =
                  '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
              _setAttr(Attribute.color.key, hex);
              refresh();
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'A',
                style: TextStyle(
                  color: color,
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bigFormatButton(
    String label,
    bool selected,
    VoidCallback onTap, {
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          color: selected ? const Color(0xFFE9F2FF) : Colors.white,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 26,
              fontWeight: fontWeight,
              fontStyle: fontStyle,
              decoration: decoration,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconFormatButton(IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Icon(icon, color: Colors.black87, size: 25),
        ),
      ),
    );
  }

  Widget _paneList(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 18),
      children: children,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE4E4E4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _commandCell(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 21),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallCommand(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 82,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupGrid(List<_Cmd> commands) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 0,
          runSpacing: 0,
          children: commands.map((command) {
            return SizedBox(
              width: 84,
              height: 62,
              child: InkWell(
                onTap: command.onTap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(command.icon, color: accent, size: 21),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        command.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _choiceRow(
    IconData icon,
    String label,
    String value,
    List<String> choices,
    ValueChanged<String> onChanged,
  ) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      leading: Icon(icon, size: 21),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
        items: choices
            .map(
              (choice) => DropdownMenuItem(
                value: choice,
                child: Text(choice),
              ),
            )
            .toList(),
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

        final lightTheme = ThemeData.light(useMaterial3: true).copyWith(
          textTheme: ThemeData.light().textTheme.apply(
                bodyColor: Colors.black,
                displayColor: Colors.black,
              ),
        );

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
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _focusEditor(),
                  child: Theme(
                    data: lightTheme,
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        height: 1.3,
                      ),
                      child: QuillEditor.basic(
                        controller: _controller,
                        focusNode: _editorFocusNode,
                        scrollController: _editorScrollController,
                        config: const QuillEditorConfig(
                          padding: EdgeInsets.zero,
                          expands: false,
                          scrollable: false,
                          autoFocus: false,
                          showCursor: true,
                          onTapOutsideEnabled: false,
                          enableInteractiveSelection: true,
                          enableSelectionToolbar: true,
                          keyboardAppearance: Brightness.light,
                          placeholder: 'Start typing…',
                        ),
                      ),
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

  void _cycleAlignment() {
    final current = _style[Attribute.align.key]?.value?.toString();

    switch (current) {
      case 'center':
        _setAttr(Attribute.align.key, 'right');
        break;
      case 'right':
        _setAttr(Attribute.align.key, 'justify');
        break;
      case 'justify':
        _setAttr(Attribute.align.key, null);
        break;
      default:
        _setAttr(Attribute.align.key, 'center');
    }
  }

  Widget _pinnedToolsBar() {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SizedBox(
        height: 92,
        child: GridView.count(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 3,
          ),
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 6,
          childAspectRatio: 1.35,
          children: [
            _pinTool(
              Icons.undo_rounded,
              'Undo',
              _controller.hasUndo ? _controller.undo : null,
            ),
            _pinTool(
              Icons.redo_rounded,
              'Redo',
              _controller.hasRedo ? _controller.redo : null,
            ),
            _pinTool(
              Icons.format_bold_rounded,
              'Bold',
              () => _toggle(Attribute.bold),
              active: _isActive(Attribute.bold),
            ),
            _pinTool(
              Icons.format_italic_rounded,
              'Italic',
              () => _toggle(Attribute.italic),
              active: _isActive(Attribute.italic),
            ),
            _pinTool(
              Icons.format_underlined_rounded,
              'Underline',
              () => _toggle(Attribute.underline),
              active: _isActive(Attribute.underline),
            ),
            _pinTool(
              Icons.text_decrease_rounded,
              'A−',
              () => _changeFontSize(-1),
            ),
            _pinTool(
              Icons.text_increase_rounded,
              'A+',
              () => _changeFontSize(1),
            ),
            _pinTool(
              Icons.format_align_left_rounded,
              'Align',
              _cycleAlignment,
            ),
            _pinTool(
              Icons.format_list_bulleted_rounded,
              'Bullets',
              () => _toggle(Attribute.ul),
              active: _isActive(Attribute.ul),
            ),
            _pinTool(
              Icons.format_list_numbered_rounded,
              'Number',
              () => _toggle(Attribute.ol),
              active: _isActive(Attribute.ol),
            ),
            _pinTool(
              Icons.search_rounded,
              'Find',
              _findReplaceDialog,
            ),
            _pinTool(
              Icons.more_horiz_rounded,
              'More',
              _showWordRibbon,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinTool(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool active = false,
  }) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFE7F0FF)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: active
              ? Border.all(color: const Color(0xFF8EB8F2))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: enabled
                  ? wordBlue
                  : Colors.black26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: enabled
                    ? Colors.black76
                    : Colors.black26,
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.path == null
        ? 'New Document'
        : widget.path!.split('/').last;

    final plain = _controller.document.toPlainText().trim();
    final words = plain.isEmpty
        ? 0
        : plain.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF1F1F1),
      appBar: AppBar(
        backgroundColor: wordBlue,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: Row(
          children: [
            const _AstraOfficeMark(size: 27),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Keyboard',
            onPressed: _focusEditor,
            icon: const Icon(Icons.keyboard_rounded, size: 21),
          ),
          IconButton(
            tooltip: _toolsPinned ? 'Unpin tools' : 'Pin tools',
            onPressed: () {
              setState(() => _toolsPinned = !_toolsPinned);
            },
            icon: Icon(
              _toolsPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              size: 21,
            ),
          ),
          IconButton(
            tooltip: 'All document tools',
            onPressed: _showWordRibbon,
            icon: const Icon(Icons.text_format_rounded, size: 21),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: _quickSave,
            icon: const Icon(Icons.save_rounded, size: 21),
          ),
          PopupMenuButton<String>(
            tooltip: 'File',
            onSelected: (value) {
              switch (value) {
                case 'saveAs':
                  _saveAs();
                  break;
                case 'preview':
                  _printPreview();
                  break;
                case 'print':
                  Printing.layoutPdf(onLayout: _buildPrintPdf);
                  break;
                case 'wordCount':
                  _showWordCount();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'saveAs', child: Text('Save As')),
              PopupMenuItem(value: 'preview', child: Text('Print Preview')),
              PopupMenuItem(value: 'print', child: Text('Print')),
              PopupMenuItem(value: 'wordCount', child: Text('Word Count')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (widget.isDocx)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    color: const Color(0xFF5F4A11),
                    child: const Text(
                      'Rich editing active • Native DOCX fidelity engine is under migration',
                      style: TextStyle(
                        color: Color(0xFFFFE394),
                        fontSize: 10,
                      ),
                    ),
                  ),
                Expanded(child: _documentCanvas()),
                if (_toolsPinned) _pinnedToolsBar(),
                Container(
                  height: 34,
                  color: wordBlueDark,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Text(
                        'Page 1',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Words: $words',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _showWordRibbon,
                        icon: const Icon(
                          Icons.text_format_rounded,
                          size: 18,
                        ),
                        label: const Text('Tools'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                        ),
                      ),
                      Text(
                        '$_pageSize • ${_landscape ? 'Landscape' : 'Portrait'}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}


class _AstraOfficeMark extends StatelessWidget {
  final double size;

  const _AstraOfficeMark({this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * .22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: size * .08,
            top: size * .08,
            bottom: size * .08,
            width: size * .42,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A00),
                borderRadius: BorderRadius.circular(size * .16),
              ),
            ),
          ),
          Positioned(
            left: size * .22,
            top: size * .06,
            bottom: size * .02,
            width: size * .30,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF00B7FF),
                  borderRadius: BorderRadius.circular(size * .12),
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              'A',
              style: TextStyle(
                color: const Color(0xFF185ABD),
                fontWeight: FontWeight.w900,
                fontSize: size * .58,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cmd {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Cmd(this.icon, this.label, this.onTap);
}
