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
                    subtitle: Text("NIS \${s['nis']} \u2022 Kelas \${s['class_name']}\nWali: \${s['guardian_name']} \u2022 \${s['phone']}"),
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
      'Kode',
      'NIS',
      'Nama',
      'Kelas',
      'Nama Wali',
      'WA',
      'Alamat',
    ]);
    sheet.appendRow([
      'A-011',
      '1011',
      'Contoh Siswa',
      '1A',
      'Wali Contoh',
      '08123456700',
      'Jl. Contoh 1',
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
        final codeVal = cv(0).isEmpty ? 'A-\${DateTime.now().millisecondsSinceEpoch}' : cv(0);
        final existing = await db.query('students', where: 'code=?', whereArgs: [codeVal]);
        if (existing.isNotEmpty) {
          await db.update('students', {
            'nis': cv(1),
            'name': cv(2),
            'class_name': cv(3).isEmpty ? '1A' : cv(3),
            'guardian_name': cv(4),
            'phone': cv(5),
            'address': cv(6),
            'updated_at': DateTime.now().toIso8601String(),
          }, where: 'code=?', whereArgs: [codeVal]);
        } else {
          await db.insert('students', {
            'code': codeVal,
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
        }
        ok++;
      } catch (e) {
        debugPrint('Import siswa baris \$i gagal: \$e');
      }
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
              if (name.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama wajib diisi')));
                return;
              }
              try {
                final db = await AppDatabase.database;
                await db.insert('students', {
                  'code': code.text.trim().isEmpty ? 'A-\${DateTime.now().millisecondsSinceEpoch}' : code.text.trim(),
                  'nis': nis.text.trim(),
                  'name': name.text.trim(),
                  'class_name': kelas.text.trim().isEmpty ? '1A' : kelas.text.trim(),
                  'guardian_name': wali.text.trim(),
                  'phone': wa.text.trim(),
                  'address': alamat.text.trim(),
                  'active': 1,
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                });
                if (context.mounted) Navigator.pop(context);
                _load();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Siswa ditambahkan')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal simpan: \$e')));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _edit(Map<String, dynamic> s) {
    final nis = TextEditingController(text: s['nis'] as String);
    final name = TextEditingController(text: s['name'] as String);
    final kelas = TextEditingController(text: s['class_name'] as String);
    final wali = TextEditingController(text: s['guardian_name'] as String);
    final wa = TextEditingController(text: s['phone'] as String);
    final alamat = TextEditingController(text: s['address'] as String);
    bool aktif = (s['active'] as int) == 1;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(s['name'] as String),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nis, decoration: const InputDecoration(labelText: 'NIS')),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama *')),
                TextField(controller: kelas, decoration: const InputDecoration(labelText: 'Kelas')),
                TextField(controller: wali, decoration: const InputDecoration(labelText: 'Nama Wali')),
                TextField(controller: wa, decoration: const InputDecoration(labelText: 'WA')),
                TextField(controller: alamat, decoration: const InputDecoration(labelText: 'Alamat')),
                const SizedBox(height: 8),
                SwitchListTile(value: aktif, title: Text(aktif ? 'Aktif' : 'Nonaktif'), onChanged: (v) => setS(() => aktif = v)),
                const SizedBox(height: 4),
                Text('Kode: ${s['code']}  •  NIS: ${s['nis']}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final db = await AppDatabase.database;
                await db.update('students', {'nis': nis.text.trim(), 'name': name.text.trim(), 'class_name': kelas.text.trim(), 'guardian_name': wali.text.trim(), 'phone': wa.text.trim(), 'address': alamat.text.trim(), 'active': aktif ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id=?', whereArgs: [s['id']]);
                if (context.mounted) Navigator.pop(context);
                _load();
              },
              child: const Text('Simpan'),
            ),
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Hapus Siswa?'), content: Text('${s['name']} akan dihapus'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Hapus'))]));
                if (ok != true) return;
                try {
                  final db = await AppDatabase.database;
                  await db.delete('students', where: 'id=?', whereArgs: [s['id']]);
                  if (context.mounted) Navigator.pop(context);
                  _load();
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal hapus: masih dipakai transaksi')));
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
