import 'package:flutter/material.dart';

import '../../services/native_office_engine.dart';
import 'text_editor_screen.dart';

class FullFidelityOpenScreen extends StatefulWidget {
  final String path;

  const FullFidelityOpenScreen({
    super.key,
    required this.path,
  });

  @override
  State<FullFidelityOpenScreen> createState() =>
      _FullFidelityOpenScreenState();
}

class _FullFidelityOpenScreenState extends State<FullFidelityOpenScreen> {
  static const wordBlue = Color(0xFF185ABD);
  final engine = const NativeOfficeEngine();

  bool _launching = false;
  String? _message;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openOriginal();
    });
  }

  Future<void> _openOriginal() async {
    if (_launching) return;

    setState(() {
      _launching = true;
      _message = null;
    });

    try {
      await engine.openOriginal(widget.path);
      if (!mounted) return;
      setState(() {
        _message =
            'Original-layout mode launched. Return here for ASTRA Quick Edit.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'No compatible Office renderer could open this file. '
            'Use Quick Edit or install an Office-compatible renderer.';
      });
    } finally {
      if (mounted) {
        setState(() => _launching = false);
      }
    }
  }

  Future<void> _quickEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextEditorScreen(
          path: widget.path,
          isDocx: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.path.split('/').last;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: wordBlue,
        foregroundColor: Colors.white,
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD8DDE6)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: wordBlue,
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Original Layout',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Recommended for DOCX files. Opens the saved Office layout '
                    'with a compatible Office renderer so fonts, tables, spacing, '
                    'images, headers, margins and page layout are not flattened '
                    'into plain text.',
                    style: TextStyle(
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: wordBlue,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _launching ? null : _openOriginal,
              icon: _launching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.open_in_new_rounded),
              label: Text(
                _launching
                    ? 'Opening original layout...'
                    : 'Open Original Layout',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _quickEdit,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('ASTRA Quick Edit'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(
                _message!,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 10),
            const Text(
              'Native engine migration',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This branch keeps Original Layout and Quick Edit separate while '
              'the native Office engine is being embedded. It prevents ASTRA '
              'from flattening the DOCX before you see it.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
