import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/docx_service.dart';

class TextEditorScreen extends StatefulWidget {
  final String? path;
  final bool isDocx;
  const TextEditorScreen({super.key, this.path, this.isDocx = false});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  String? _sourcePath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _sourcePath = widget.path;
    if (widget.path != null) {
      try {
        _controller.text = widget.isDocx
            ? await DocxService().readPlainText(widget.path!)
            : await File(widget.path!).readAsString();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open failed: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveAs() async {
    final defaultName = widget.isDocx ? 'Document.docx' : 'Document.txt';
    final path = await FilePicker.platform.saveFile(dialogTitle: 'Save as', fileName: defaultName);
    if (path == null) return;
    if (widget.isDocx) {
      if (_sourcePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New DOCX package creation is scheduled for Phase 1.1. Save as TXT for now.')));
        return;
      }
      await DocxService().savePlainText(_sourcePath!, path, _controller.text);
    } else {
      await File(path).writeAsString(_controller.text, flush: true);
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $path')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.path == null ? 'New Document' : widget.path!.split('/').last),
        actions: [IconButton(onPressed: _saveAs, icon: const Icon(Icons.save_as))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              if (widget.isDocx)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: Colors.amber.shade100,
                  child: const Text('Compatibility mode: advanced DOCX formatting may be simplified when saved.'),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _controller,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText: 'Start typing…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
            ]),
    );
  }
}
