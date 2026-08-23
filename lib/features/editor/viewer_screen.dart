import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

class ViewerScreen extends StatelessWidget {
  final String path;
  final String kind;
  const ViewerScreen({super.key, required this.path, required this.kind});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(path.split('/').last)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(kind == 'PDF' ? Icons.picture_as_pdf : Icons.slideshow, size: 72),
            const SizedBox(height: 16),
            Text('$kind viewing is available through the device viewer in this bootstrap build.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => OpenFilex.open(path), icon: const Icon(Icons.open_in_new), label: const Text('Open file')),
            const SizedBox(height: 8),
            const Text('Native PDF annotation and PPTX slide editing are the next implementation milestone.', textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
