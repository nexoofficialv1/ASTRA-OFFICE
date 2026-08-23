import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
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

  static const navy = Color(0xFF071A38);
  static const panel = Color(0xFF0D2449);

  @override
  void initState() {
    super.initState();
    _controller = QuillController.basic();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  String sidecarPath(String path) => '$path.astra.quill.json';

  Future<void> _load() async {
    _sourcePath = widget.path;

    try {
      if (widget.path != null) {
        final sidecar = File(sidecarPath(widget.path!));

        if (await sidecar.exists()) {
          final raw = await sidecar.readAsString();
          final data = jsonDecode(raw) as List<dynamic>;
          _controller.dispose();
          _controller = QuillController(
            document: Document.fromJson(data),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          final text = widget.isDocx
              ? await DocxService().readPlainText(widget.path!)
              : await File(widget.path!).readAsString();

          final document = Document();
          if (text.isNotEmpty) {
            document.insert(0, text);
          }

          _controller.dispose();
          _controller = QuillController(
            document: document,
            selection: const TextSelection.collapsed(offset: 0),
          );
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
                'New native DOCX package creation will arrive with the DOCX round-trip engine. Use an existing DOCX or save text for this build.',
              ),
            ),
          );
          return;
        }

        await DocxService().savePlainText(_sourcePath!, path, plain);
        await _saveRichSidecar(path);
      } else {
        await File(path).writeAsString(plain, flush: true);
        await _saveRichSidecar(path);
      }

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

  void _showWordCount() {
    final text = _controller.document.toPlainText().trim();
    final words = text.isEmpty
        ? 0
        : text.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length;
    final chars = text.length;

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
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.white60)),
      ],
    );
  }

  void _coming(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is in the next editor milestone.')),
    );
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
                  height: 116,
                  child: TabBarView(
                    controller: _tabs,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _homeRibbon(),
                      _insertRibbon(),
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
                      vertical: 6,
                    ),
                    color: const Color(0xFF5F4A11),
                    child: const Text(
                      'Rich editing is active. Native DOCX formatting round-trip is the next engine milestone.',
                      style: TextStyle(
                        color: Color(0xFFFFE394),
                        fontSize: 11,
                      ),
                    ),
                  ),
                Expanded(
                  child: Container(
                    color: const Color(0xFFCBD1DA),
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 18,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: 900,
                          maxWidth: 720,
                        ),
                        padding: const EdgeInsets.fromLTRB(42, 48, 42, 56),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
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
                _statusBar(),
              ],
            ),
    );
  }

  Widget _homeRibbon() {
    return Container(
      color: panel,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: QuillSimpleToolbar(
        controller: _controller,
        config: const QuillSimpleToolbarConfig(),
      ),
    );
  }

  Widget _insertRibbon() {
    return _ribbonActions([
      _RibbonAction(
        Icons.table_chart_rounded,
        'Table',
        () => _coming('Table insertion'),
      ),
      _RibbonAction(
        Icons.image_rounded,
        'Image',
        () => _coming('Image insertion'),
      ),
      _RibbonAction(
        Icons.horizontal_rule_rounded,
        'Page break',
        () => _coming('Page break'),
      ),
      _RibbonAction(
        Icons.vertical_align_top_rounded,
        'Header',
        () => _coming('Header / Footer'),
      ),
    ]);
  }

  Widget _viewRibbon() {
    return _ribbonActions([
      _RibbonAction(
        Icons.article_outlined,
        'Print layout',
        () {},
      ),
      _RibbonAction(
        Icons.fit_screen_rounded,
        'Page width',
        () {},
      ),
      _RibbonAction(
        Icons.zoom_in_rounded,
        'Zoom',
        () => _coming('Advanced zoom'),
      ),
      _RibbonAction(
        Icons.print_rounded,
        'Print',
        () => _coming('Document print preview'),
      ),
    ]);
  }

  Widget _reviewRibbon() {
    return _ribbonActions([
      _RibbonAction(
        Icons.search_rounded,
        'Find',
        () => _coming('Find / Replace'),
      ),
      _RibbonAction(
        Icons.calculate_outlined,
        'Word count',
        _showWordCount,
      ),
      _RibbonAction(
        Icons.spellcheck_rounded,
        'Spelling',
        () => _coming('Spelling review'),
      ),
      _RibbonAction(
        Icons.comment_outlined,
        'Comment',
        () => _coming('Comments'),
      ),
    ]);
  }

  Widget _ribbonActions(List<_RibbonAction> actions) {
    return Container(
      color: panel,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: actions
            .map(
              (action) => Expanded(
                child: InkWell(
                  onTap: action.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          action.icon,
                          color: const Color(0xFF7BB4FF),
                          size: 25,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          action.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
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
          const SizedBox(width: 18),
          Text(
            'Words: $words',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const Spacer(),
          const Icon(
            Icons.zoom_out_rounded,
            color: Colors.white38,
            size: 18,
          ),
          const SizedBox(width: 8),
          const Text(
            '100%',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.zoom_in_rounded,
            color: Colors.white38,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _RibbonAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RibbonAction(this.icon, this.label, this.onTap);
}
