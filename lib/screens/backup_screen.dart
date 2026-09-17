import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../db/app_database.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? dbPath;
  int? dbSize;
  bool busy = false;

  @override
  void initState() { super.initState(); _refreshInfo(); }

  Future<void> _refreshInfo() async {
    try {
      final path = p.join(await getDatabasesPath(), 'kasir_sekolah.db');
      dbPath = path;
      final f = File(path);
      if (await f.exists()) {
        dbSize = await f.length();
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _backupSaveFile() async {
    setState(() => busy = true);
    try {
      final src = File(p.join(await getDatabasesPath(), 'kasir_sekolah.db'));
      if (!await src.exists()) throw Exception('Database belum dibuat. Lakukan transaksi dulu.');
      final bytes = await src.readAsBytes();
      final name = 'kasir_sekolah_backup_${DateTime.now().toIso8601String().substring(0,19).replaceAll(':','-')}.db';
      final picked = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan Backup',
        fileName: name,
        bytes: bytes,
      );
      if (picked != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup tersimpan: $picked')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal backup: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _backupShare() async {
    setState(() => busy = true);
    try {
      final src = File(p.join(await getDatabasesPath(), 'kasir_sekolah.db'));
      if (!await src.exists()) throw Exception('Database belum dibuat.');
      // share_plus butuh XFile, copy ke temp dengan nama jelas
      final tmp = File('${Directory.systemTemp.path}/kasir_backup_${DateTime.now().millisecondsSinceEpoch}.db');
      await tmp.writeAsBytes(await src.readAsBytes());
      await Share.shareXFiles([XFile(tmp.path)], text: 'Backup Kasir Sekolah - ${DateTime.now().toIso8601String().substring(0,10)}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih Drive/WA/Email untuk menyimpan backup')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal share: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restorePick() async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Pulihkan dari Backup?'),
      content: const Text('Data sekarang akan DIGANTI dengan file backup. Pastikan file .db berasal dari aplikasi ini. Lanjutkan?'),
      actions: [TextButton(onPressed: ()=> Navigator.pop(context,false), child: const Text('Batal')), FilledButton(onPressed: ()=> Navigator.pop(context,true), child: const Text('Ya, Pulihkan'))],
    ));
    if (confirm != true) return;
    setState(() => busy = true);
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (res == null) { setState(()=> busy=false); return; }
      Uint8List? bytes = res.files.single.bytes;
      String? path = res.files.single.path;
      if (bytes == null && path != null) bytes = await File(path).readAsBytes();
      if (bytes == null) throw Exception('Gagal membaca file');
      // validasi header SQLite
      if (bytes.length < 16 || String.fromCharCodes(bytes.sublist(0,6)) != 'SQLite') {
        throw Exception('File bukan database SQLite (.db) yang valid');
      }
      final dbPathFull = p.join(await getDatabasesPath(), 'kasir_sekolah.db');
      // tutup DB dulu
      try { final db = await AppDatabase.database; await db.close(); } catch(_){}
      AppDatabase.resetForRestore();
      final dst = File(dbPathFull);
      await dst.writeAsBytes(bytes, flush: true);
      // verifikasi bisa dibuka
      final check = await openDatabase(dbPathFull, readOnly: true);
      await check.rawQuery('SELECT count(*) FROM sqlite_master');
      await check.close();
      // reopen via AppDatabase
      await AppDatabase.database;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore berhasil! Tutup-buka app jika perlu refresh halaman.')));
        _refreshInfo();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal restore: $e')));
      // coba reopen db lama jika ada
      try { await AppDatabase.database; } catch(_){}
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _fmt(int? b) {
    if (b == null) return '-';
    if (b < 1024) return '$b B';
    if (b < 1024*1024) return '${(b/1024).toStringAsFixed(1)} KB';
    return '${(b/1024/1024).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: busy ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children:[const Icon(Icons.sd_storage, color: Colors.indigo), const SizedBox(width:8), const Text('Database Lokal', style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height:8),
          Text(dbPath ?? '-', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          const SizedBox(height:4),
          Text('Ukuran: ${_fmt(dbSize)}', style: const TextStyle(color: Colors.black54, fontSize:12)),
          const SizedBox(height:8),
          const Text('Data disimpan 100% di HP (offline). Backup rutin mencegah hilang saat HP rusak/reset.', style: TextStyle(fontSize:12, color: Colors.black54)),
        ]))),
        const SizedBox(height:12),
        const Text('Backup', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height:8),
        FilledButton.icon(onPressed: _backupSaveFile, icon: const Icon(Icons.save_alt), label: const Text('Simpan Backup ke File (.db)')),
        const SizedBox(height:8),
        OutlinedButton.icon(onPressed: _backupShare, icon: const Icon(Icons.share), label: const Text('Bagikan ke Drive / WA / Email')),
        const SizedBox(height:4),
        const Text('Saran: backup mingguan ke Google Drive. File .db berisi semua transaksi ribuan data.', style: TextStyle(fontSize:11, color: Colors.black45)),
        const SizedBox(height:16),
        const Text('Restore', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height:8),
        OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.deepOrange), onPressed: _restorePick, icon: const Icon(Icons.restore), label: const Text('Pulihkan dari File Backup (.db)')),
        const SizedBox(height:24),
        const Divider(),
        const Text('Tips jangka panjang', style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)),
        const SizedBox(height:6),
        const Text('• Backup sebelum update aplikasi\n• Simpan 2 copy: di HP + di Drive\n• Export Excel di menu Laporan juga bisa jadi cadangan ringan', style: TextStyle(fontSize:11, color: Colors.black54)),
        const SizedBox(height:12),
        Center(child: TextButton.icon(onPressed: _refreshInfo, icon: const Icon(Icons.refresh, size:16), label: const Text('Refresh info'))),
      ]),
    );
  }
}
