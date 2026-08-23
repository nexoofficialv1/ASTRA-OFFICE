import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/office_file.dart';
import '../../services/file_type_service.dart';
import '../../services/recent_service.dart';
import '../editor/text_editor_screen.dart';
import '../editor/spreadsheet_screen.dart';
import '../editor/viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final recent = RecentService();
  List<Map<String,dynamic>> items = [];

  @override
  void initState(){ super.initState(); _refresh(); }
  Future<void> _refresh() async { items = await recent.getRecent(); if (mounted) setState((){}); }

  Future<void> _openPicker() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['docx','xlsx','xls','csv','pptx','ppt','pdf','txt','md']);
    final path = result?.files.single.path;
    if(path == null) return;
    await _open(path);
  }

  Future<void> _open(String path) async {
    final name = path.split('/').last;
    final type = FileTypeService.fromPath(path);
    await recent.add(path, name, type.name);
    await _refresh();
    if (!mounted) return;
    Widget page;
    switch(type){
      case OfficeFileType.document: page = TextEditorScreen(path:path,isDocx:true); break;
      case OfficeFileType.text: page = TextEditorScreen(path:path); break;
      case OfficeFileType.spreadsheet: page = SpreadsheetScreen(path:path); break;
      case OfficeFileType.presentation: page = ViewerScreen(path:path,kind:'Presentation'); break;
      case OfficeFileType.pdf: page = ViewerScreen(path:path,kind:'PDF'); break;
      default: ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Unsupported file format'))); return;
    }
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>page));
  }

  Widget _tile(IconData icon,String title,String subtitle,VoidCallback onTap){
    return Card(child:ListTile(leading:CircleAvatar(child:Icon(icon)),title:Text(title),subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_right),onTap:onTap));
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(title:const Text('ASTRA OFFICE'),actions:[IconButton(onPressed:_openPicker,icon:const Icon(Icons.folder_open))]),
      floatingActionButton:FloatingActionButton.extended(onPressed:(){showModalBottomSheet(context:context,builder:(context)=>SafeArea(child:Wrap(children:[
        ListTile(leading:const Icon(Icons.description),title:const Text('New Document'),onTap:(){Navigator.pop(context);Navigator.push(context,MaterialPageRoute(builder:(_)=>const TextEditorScreen()));}),
        ListTile(leading:const Icon(Icons.grid_on),title:const Text('New Spreadsheet'),onTap:(){Navigator.pop(context);Navigator.push(context,MaterialPageRoute(builder:(_)=>const SpreadsheetScreen()));}),
        const ListTile(leading:Icon(Icons.slideshow),title:Text('New Presentation'),subtitle:Text('Editor coming in next milestone')),
      ])));},icon:const Icon(Icons.add),label:const Text('Create')),
      body:RefreshIndicator(onRefresh:_refresh,child:ListView(padding:const EdgeInsets.all(16),children:[
        const Text('Create & edit',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
        const SizedBox(height:8),
        _tile(Icons.description,'Documents','DOCX / TXT editing',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const TextEditorScreen()))),
        _tile(Icons.grid_on,'Spreadsheets','XLSX create / open / edit / save',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SpreadsheetScreen()))),
        _tile(Icons.slideshow,'Presentations','PPT/PPTX open; editor next',_openPicker),
        _tile(Icons.picture_as_pdf,'PDF','Open PDF; annotation next',_openPicker),
        const SizedBox(height:18),
        const Text('Recent files',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        if(items.isEmpty) const Padding(padding:EdgeInsets.symmetric(vertical:28),child:Center(child:Text('No recent files'))),
        ...items.map((e)=>Card(child:ListTile(title:Text(e['name']?.toString()??''),subtitle:Text(e['type']?.toString()??''),onTap:()=>_open(e['path'].toString())))),
        const SizedBox(height:80),
      ])),
    );
  }
}
