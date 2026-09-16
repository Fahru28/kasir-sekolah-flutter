import 'package:flutter/material.dart';
import '../db/app_database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
class StudentsScreen extends StatefulWidget { const StudentsScreen({super.key}); @override State<StudentsScreen> createState()=> _StudentsScreenState();}
class _StudentsScreenState extends State<StudentsScreen> {
  List<Map<String,dynamic>> data=[]; String q='';
  @override void initState(){ super.initState(); _load();}
  Future<void> _load() async { final db=await AppDatabase.database; data=await db.query('students', orderBy:'name'); setState((){}); }
  @override Widget build(BuildContext context){
    final filtered=data.where((s)=> q.isEmpty || (s['name'] as String).toLowerCase().contains(q.toLowerCase()) || (s['code'] as String).toLowerCase().contains(q.toLowerCase()) || (s['nis'] as String).contains(q)).toList();
    return Scaffold(appBar: AppBar(title: const Text('Data Anak'), actions: [
        IconButton(icon: const Icon(Icons.download), tooltip:'Template', onPressed: _downloadTemplate),
        IconButton(icon: const Icon(Icons.upload_file), tooltip:'Import Excel', onPressed: _importExcel),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.person_add), label: const Text('Tambah')),
      body: Column(children:[
        Padding(padding: const EdgeInsets.all(12), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText:'Cari nama / NIS / kode...', border: OutlineInputBorder()), onChanged:(v)=> setState(()=> q=v))),
        Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder:(_,i){
          final s=filtered[i];
          return Card(margin: const EdgeInsets.symmetric(horizontal:12, vertical:4), child: ListTile(
            leading: CircleAvatar(child: Text((s['name'] as String).substring(0,1))),
            title: Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${s['code']} • NIS ${s['nis']} • Kelas ${s['class_name']}\nWali: ${s['guardian_name']} • ${s['phone']}"),
            isThreeLine:true,
            trailing: Chip(label: Text((s['active'] as int)==1?'Aktif':'Nonaktif'), backgroundColor: (s['active'] as int)==1? Colors.green.shade100: Colors.grey.shade200),
            onTap: ()=> _edit(s),
          ));
        })),
      ]),
    );
  }
  void _add(){
    final code=TextEditingController(), nis=TextEditingController(), name=TextEditingController(), kelas=TextEditingController(text:'1A'), wali=TextEditingController(), wa=TextEditingController(), alamat=TextEditingController();
    showDialog(context: context, builder:(_)=> AlertDialog(title: const Text('Tambah Siswa'), content: SingleChildScrollView(child: Column(children:[
      TextField(controller: code, decoration: const InputDecoration(labelText:'Kode (A-011)')), TextField(controller: nis, decoration: const InputDecoration(labelText:'NIS')), TextField(controller: name, decoration: const InputDecoration(labelText:'Nama Anak')),
      TextField(controller: kelas, decoration: const InputDecoration(labelText:'Kelas')), TextField(controller: wali, decoration: const InputDecoration(labelText:'Nama Wali')), TextField(controller: wa, decoration: const InputDecoration(labelText:'WA')), TextField(controller: alamat, decoration: const InputDecoration(labelText:'Alamat')),
    ])), actions:[ TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Batal')), FilledButton(onPressed: () async {
      final db=await AppDatabase.database;
      await db.insert('students',{'code':code.text,'nis':nis.text,'name':name.text,'class_name':kelas.text,'guardian_name':wali.text,'phone':wa.text,'address':alamat.text,'active':1,'created_at':DateTime.now().toIso8601String(),'updated_at':DateTime.now().toIso8601String()});
      Navigator.pop(context); _load();
    }, child: const Text('Simpan'))]));
  }
  void _edit(Map<String,dynamic> s){
    final name=TextEditingController(text: s['name'] as String);
    showDialog(context: context, builder:(_)=> AlertDialog(title: Text(s['name'] as String), content: TextField(controller: name, decoration: const InputDecoration(labelText:'Nama')), actions:[
      TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Batal')),
      FilledButton(onPressed: () async { final db=await AppDatabase.database; await db.update('students',{'name':name.text}, where:'id=?', whereArgs:[s['id']]); Navigator.pop(context); _load();}, child: const Text('Simpan')),
      TextButton(onPressed: () async { final db=await AppDatabase.database; await db.delete('students', where:'id=?', whereArgs:[s['id']]); Navigator.pop(context); _load();}, child: const Text('Hapus', style: TextStyle(color:Colors.red))),
    ]));
  }
}
