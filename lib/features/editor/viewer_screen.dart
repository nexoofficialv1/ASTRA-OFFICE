import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';

class ViewerScreen extends StatelessWidget {
  final String path;
  final String kind;

  const ViewerScreen({
    super.key,
    required this.path,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = path.split('/').last;

    if (kind == 'PDF') {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            fileName,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: 'Print',
              icon: const Icon(Icons.print),
              onPressed: () async {
                final bytes = await File(path).readAsBytes();
                await Printing.layoutPdf(
                  onLayout: (_) async => bytes,
                  name: fileName,
                );
              },
            ),
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share),
              onPressed: () async {
                final bytes = await File(path).readAsBytes();
                await Printing.sharePdf(
                  bytes: bytes,
                  filename: fileName,
                );
              },
            ),
          ],
        ),
        body: PdfPreview(
          canChangePageFormat: false,
          canChangeOrientation: false,
          allowPrinting: true,
          allowSharing: true,
          pdfFileName: fileName,
          build: (_) => File(path).readAsBytes(),
          loadingWidget: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fileName,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.slideshow, size: 72),
              const SizedBox(height: 16),
              Text(
                '$kind native editing is under development.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => OpenFilex.open(path),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open with device app'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
