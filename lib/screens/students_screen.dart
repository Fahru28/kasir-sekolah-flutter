import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import '../db/app_database.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  List<Map<String, dynamic>> data = [];
  String q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.database;
    data = await db.query('students', orderBy: 'name');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filtered = data.where((s) {
      final mq = q.isEmpty ||
          (s['name'] as String).toLowerCase().contains(q.toLowerCase()) ||
          (s['code'] as String).toLowerCase().contains(q.toLowerCase()) ||
          (s['nis'] as String).toLowerCase().contains(q.toLowerCase());
      return mq;
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Siswa'),
        actions: [
          IconButton(icon: const Icon(Icons.download), tooltip: 'Template', onPressed: _downloadTemplate),
          IconButton(icon: const Icon(Icons.upload_file), tooltip: 'Import Excel', onPressed: _importExcel),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.person_add), label: const Text('Tambah')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari nama / NIS / kode...', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final s = filtered[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(child: Text((s['name'] as String).substring(0, 1))),
                    title: Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("\${s['code']} \u2022 NIS \${s['nis']} \u2022 Kelas \${s['class_name']}\nWali: \${s['guardian_name']} \u2022 \${s['phone']}"),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text((s['active'] as int) == 1 ? 'Aktif' : 'Nonaktif'),
                      backgroundColor: (s['active'] as int) == 1 ? Colors.green.shade100 : Colors.grey.shade200,
                    ),
                    onTap: () => _edit(s),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['Siswa'];
    sheet.appendRow([
      TextCellValue('Kode'),
      TextCellValue('NIS'),
      TextCellValue('Nama'),
      TextCellValue('Kelas'),
      TextCellValue('Nama Wali'),
      TextCellValue('WA'),
      TextCellValue('Alamat'),
    ]);
    sheet.appendRow([
      TextCellValue('A-011'),
      TextCellValue('1011'),
      TextCellValue('Contoh Siswa'),
      TextCellValue('1A'),
      TextCellValue('Wali Contoh'),
      TextCellValue('08123456700'),
      TextCellValue('Jl. Contoh 1'),
    ]);
    final bytes = excel.save();
    if (bytes == null) return;
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Template Siswa',
      fileName: 'template_siswa.xlsx',
      bytes: Uint8List.fromList(bytes),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tersimpan: $result')));
    }
  }

  Future<void> _importExcel() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final excel = Excel.decodeBytes(result.files.single.bytes!);
    final sheet = excel.tables[excel.tables.keys.first]!;
    final db = await AppDatabase.database;
    int ok = 0;
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      String cv(int idx) => row.length > idx && row[idx]?.value != null ? row[idx]!.value.toString().trim() : '';
      if (cv(2).isEmpty) continue;
      try {
        await db.insert('students', {
          'code': cv(0).isEmpty ? 'A-\${DateTime.now().millisecondsSinceEpoch}' : cv(0),
          'nis': cv(1),
          'name': cv(2),
          'class_name': cv(3).isEmpty ? '1A' : cv(3),
          'guardian_name': cv(4),
          'phone': cv(5),
          'address': cv(6),
          'active': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        ok++;
      } catch (_) {}
    }
    _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import selesai: $ok baris')));
  }

  void _add() {
    final code = TextEditingController();
    final nis = TextEditingController();
    final name = TextEditingController();
    final kelas = TextEditingController(text: '1A');
    final wali = TextEditingController();
    final wa = TextEditingController();
    final alamat = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Siswa'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: code, decoration: const InputDecoration(labelText: 'Kode (A-011)')),
              TextField(controller: nis, decoration: const InputDecoration(labelText: 'NIS')),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama Anak')),
              TextField(controller: kelas, decoration: const InputDecoration(labelText: 'Kelas')),
              TextField(controller: wali, decoration: const InputDecoration(labelText: 'Nama Wali')),
              TextField(controller: wa, decoration: const InputDecoration(labelText: 'WA')),
              TextField(controller: alamat, decoration: const InputDecoration(labelText: 'Alamat')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final db = await AppDatabase.database;
              await db.insert('students', {
                'code': code.text,
                'nis': nis.text,
                'name': name.text,
                'class_name': kelas.text,
                'guardian_name': wali.text,
                'phone': wa.text,
                'address': alamat.text,
                'active': 1,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              });
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _edit(Map<String, dynamic> s) {
    final name = TextEditingController(text: s['name'] as String);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s['name'] as String),
        content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final db = await AppDatabase.database;
              await db.update('students', {'name': name.text}, where: 'id=?', whereArgs: [s['id']]);
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Simpan'),
          ),
          TextButton(
            onPressed: () async {
              final db = await AppDatabase.database;
              await db.delete('students', where: 'id=?', whereArgs: [s['id']]);
              if (context.mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
