enum OfficeFileType { document, spreadsheet, presentation, pdf, text, unknown }

class OfficeFile {
  final String path;
  final String name;
  final OfficeFileType type;
  final DateTime openedAt;

  const OfficeFile({
    required this.path,
    required this.name,
    required this.type,
    required this.openedAt,
  });
}
