import '../models/office_file.dart';

class FileTypeService {
  static OfficeFileType fromPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.docx') || p.endsWith('.odt')) return OfficeFileType.document;
    if (p.endsWith('.xlsx') || p.endsWith('.xls') || p.endsWith('.csv')) return OfficeFileType.spreadsheet;
    if (p.endsWith('.pptx') || p.endsWith('.ppt')) return OfficeFileType.presentation;
    if (p.endsWith('.pdf')) return OfficeFileType.pdf;
    if (p.endsWith('.txt') || p.endsWith('.md')) return OfficeFileType.text;
    return OfficeFileType.unknown;
  }
}
