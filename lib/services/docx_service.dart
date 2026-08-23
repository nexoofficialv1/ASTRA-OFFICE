import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';

class DocxService {
  Future<String> readPlainText(String path) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final doc = archive.findFile('word/document.xml');
    if (doc == null) throw Exception('Invalid DOCX: word/document.xml missing');
    final xml = XmlDocument.parse(String.fromCharCodes(doc.content as List<int>));
    final paragraphs = xml.findAllElements('w:p').map((p) {
      return p.findAllElements('w:t').map((t) => t.innerText).join();
    }).toList();
    return paragraphs.join('\n');
  }

  /// Phase-1 safe-save: rewrites textual runs while retaining the original package.
  /// Advanced formatting may not survive perfectly; UI must warn before overwrite.
  Future<void> savePlainText(String sourcePath, String targetPath, String text) async {
    final bytes = await File(sourcePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final doc = archive.findFile('word/document.xml');
    if (doc == null) throw Exception('Invalid DOCX');

    final xml = XmlDocument.parse(String.fromCharCodes(doc.content as List<int>));
    final body = xml.findAllElements('w:body').first;
    final bodyChildren = body.children.toList();
    for (final node in bodyChildren) {
      if (node is XmlElement && node.name.qualified == 'w:p') node.remove();
    }
    final ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
    final lines = text.split('\n');
    for (final line in lines.reversed) {
      final p = XmlElement(XmlName('w:p'), [], [
        XmlElement(XmlName('w:r'), [], [
          XmlElement(XmlName('w:t'), [XmlAttribute(XmlName('xml:space'), 'preserve')], [XmlText(line)])
        ])
      ]);
      body.children.insert(0, p);
    }

    final replacement = ArchiveFile('word/document.xml', xml.toXmlString().length, xml.toXmlString().codeUnits);
    archive.files.removeWhere((f) => f.name == 'word/document.xml');
    archive.addFile(replacement);
    final out = ZipEncoder().encode(archive);
    if (out == null) throw Exception('Could not encode DOCX');
    await File(targetPath).writeAsBytes(out, flush: true);
  }
}
