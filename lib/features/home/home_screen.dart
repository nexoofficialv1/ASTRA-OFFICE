import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/office_file.dart';
import '../../services/file_type_service.dart';
import '../../services/recent_service.dart';
import '../editor/spreadsheet_screen.dart';
import '../editor/text_editor_screen.dart';
import '../editor/viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const navy = Color(0xFF06152F);
  static const panel = Color(0xFF0D2449);
  final recent = RecentService();
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    items = await recent.getRecent();
    if (mounted) setState(() {});
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx','xlsx','xls','csv','pptx','ppt','pdf','txt','md'],
    );
    final path = result?.files.single.path;
    if (path != null) await _open(path);
  }

  Future<void> _open(String path) async {
    final name = path.split('/').last;
    final type = FileTypeService.fromPath(path);
    await recent.add(path, name, type.name);
    await _refresh();
    if (!mounted) return;
    late Widget page;
    switch (type) {
      case OfficeFileType.document:
        page = TextEditorScreen(path: path, isDocx: true);
        break;
      case OfficeFileType.text:
        page = TextEditorScreen(path: path);
        break;
      case OfficeFileType.spreadsheet:
        page = SpreadsheetScreen(path: path);
        break;
      case OfficeFileType.presentation:
        page = ViewerScreen(path: path, kind: 'Presentation');
        break;
      case OfficeFileType.pdf:
        page = ViewerScreen(path: path, kind: 'PDF');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unsupported file format')),
        );
        return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _refresh();
  }

  void _presentationNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Presentation editor is coming in the editor-core phase.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF08204A), Color(0xFF06152F), Color(0xFF041024)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
              children: [
                _header(),
                const SizedBox(height: 20),
                _hero(),
                const SizedBox(height: 18),
                _cards(),
                const SizedBox(height: 24),
                _title('Recent files', Icons.schedule_rounded),
                const SizedBox(height: 10),
                _recents(),
                const SizedBox(height: 24),
                _title('Quick actions', Icons.bolt_rounded),
                const SizedBox(height: 10),
                _quick(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _createMenu,
        backgroundColor: const Color(0xFF247BFF),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 34),
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF071A38),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: const SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Nav(Icons.home_rounded, 'Home'),
              _Nav(Icons.folder_rounded, 'Files'),
              SizedBox(width: 70),
              _Nav(Icons.history_rounded, 'Recent'),
              _Nav(Icons.grid_view_rounded, 'Tools'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      const AstraLogo(size: 56),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ASTRA OFFICE',
              style: TextStyle(color: Colors.white,fontWeight: FontWeight.w900,letterSpacing: 1.2,fontSize: 24)),
            Text('Create • Edit • Print • Share',
              style: TextStyle(color: Colors.white60,fontSize: 12)),
          ],
        ),
      ),
      _headButton(Icons.search_rounded),
      const SizedBox(width: 8),
      _headButton(Icons.folder_open_rounded),
    ],
  );

  Widget _headButton(IconData icon) => InkWell(
    onTap: _pick,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(28)),
      ),
      child: Icon(icon, color: Colors.white),
    ),
  );

  Widget _hero() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF123A82),Color(0xFF25146F),Color(0xFF071B3D)],
      ),
      border: Border.all(color: const Color(0xFF3D8BFF)),
      boxShadow: const [BoxShadow(color: Color(0x55247BFF),blurRadius: 28,offset: Offset(0,12))],
    ),
    child: const Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('All-in-One\nOffice Suite',
                style: TextStyle(color: Colors.white,fontWeight: FontWeight.w900,fontSize: 28,height: 1.05)),
              SizedBox(height: 10),
              Text('Documents • Spreadsheets • PDF',
                style: TextStyle(color: Colors.white70,fontSize: 13)),
              SizedBox(height: 5),
              Text('Offline-first • Local files',
                style: TextStyle(color: Colors.white54,fontSize: 12)),
            ],
          ),
        ),
        AstraLogo(size: 94),
      ],
    ),
  );

  Widget _cards() => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2,
    childAspectRatio: 1.3,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    children: [
      _card(Icons.description_rounded,'Document','DOCX / TXT',const Color(0xFF287BFF),
        () => Navigator.push(context,MaterialPageRoute(builder: (_) => const TextEditorScreen()))),
      _card(Icons.grid_on_rounded,'Spreadsheet','XLSX / CSV',const Color(0xFF17B267),
        () => Navigator.push(context,MaterialPageRoute(builder: (_) => const SpreadsheetScreen()))),
      _card(Icons.slideshow_rounded,'Presentation','PPTX / PPT',const Color(0xFFFF6B31),_presentationNotice),
      _card(Icons.picture_as_pdf_rounded,'PDF','View / Print',const Color(0xFFB753E5),_pick),
    ],
  );

  Widget _card(IconData icon,String title,String subtitle,Color color,VoidCallback tap) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(150)),
        boxShadow: [BoxShadow(color: color.withAlpha(30),blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 45,height: 45,
            decoration: BoxDecoration(color: color,borderRadius: BorderRadius.circular(13)),
            child: Icon(icon,color: Colors.white,size: 27),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,style: const TextStyle(color: Colors.white,fontWeight: FontWeight.w800,fontSize: 16)),
              Text(subtitle,style: const TextStyle(color: Colors.white54,fontSize: 11)),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _title(String title,IconData icon) => Row(
    children: [
      Icon(icon,color: const Color(0xFF67A9FF),size: 20),
      const SizedBox(width: 8),
      Expanded(child: Text(title,style: const TextStyle(color: Colors.white,fontSize: 19,fontWeight: FontWeight.w800))),
      if (title == 'Recent files') TextButton(onPressed: _pick,child: const Text('Open file')),
    ],
  );

  Widget _recents() {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(color: panel,borderRadius: BorderRadius.circular(18)),
        child: const Center(child: Text('No recent files yet',style: TextStyle(color: Colors.white60))),
      );
    }
    return Column(
      children: items.take(5).map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: InkWell(
          onTap: () => _open(e['path'].toString()),
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: panel,borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFF1C4077))),
            child: Row(
              children: [
                Container(
                  width: 45,height: 45,
                  decoration: BoxDecoration(color: const Color(0xFF287BFF),borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.insert_drive_file_rounded,color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  e['name']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white,fontWeight: FontWeight.w700),
                )),
                const Icon(Icons.more_vert_rounded,color: Colors.white38),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _quick() => Row(
    children: [
      _quickItem(Icons.note_add_rounded,'New Doc',() => Navigator.push(context,MaterialPageRoute(builder: (_) => const TextEditorScreen()))),
      _quickItem(Icons.add_chart_rounded,'New Sheet',() => Navigator.push(context,MaterialPageRoute(builder: (_) => const SpreadsheetScreen()))),
      _quickItem(Icons.folder_open_rounded,'Open',_pick),
      _quickItem(Icons.picture_as_pdf_rounded,'PDF',_pick),
    ],
  );

  Widget _quickItem(IconData icon,String label,VoidCallback tap) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 82,
          decoration: BoxDecoration(
            color: panel,borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF28528C))),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,color: const Color(0xFF62A7FF)),
              const SizedBox(height: 7),
              Text(label,style: const TextStyle(color: Colors.white70,fontSize: 11)),
            ],
          ),
        ),
      ),
    ),
  );

  void _createMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1D3D),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_rounded,color: Color(0xFF2B79FF)),
              title: const Text('New Document'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,MaterialPageRoute(builder: (_) => const TextEditorScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on_rounded,color: Color(0xFF19B66A)),
              title: const Text('New Spreadsheet'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,MaterialPageRoute(builder: (_) => const SpreadsheetScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded,color: Color(0xFFB753E5)),
              title: const Text('Open file'),
              onTap: () {
                Navigator.pop(context);
                _pick();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Nav(this.icon,this.label);

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon,color: Colors.white54,size: 23),
      const SizedBox(height: 2),
      Text(label,style: const TextStyle(color: Colors.white54,fontSize: 10)),
    ],
  );
}

class AstraLogo extends StatelessWidget {
  final double size;
  const AstraLogo({super.key,this.size = 60});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size * .82,
          height: size * .82,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .25),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF4C24),Color(0xFFFFA61A),Color(0xFFE52973)],
            ),
            boxShadow: const [BoxShadow(color: Color(0x66247BFF),blurRadius: 18)],
          ),
        ),
        Transform.translate(
          offset: Offset(-size * .08,size * .12),
          child: Transform.rotate(
            angle: -0.48,
            child: Container(
              width: size * .30,
              height: size * .72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * .15),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B7CFF),Color(0xFF13D4F1),Color(0xFF8D38FF)],
                ),
              ),
            ),
          ),
        ),
        Container(
          width: size * .30,
          height: size * .42,
          decoration: BoxDecoration(
            color: const Color(0xFF071A38),
            borderRadius: BorderRadius.circular(size * .12),
          ),
        ),
      ],
    ),
  );
}
