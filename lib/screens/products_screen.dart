import 'package:flutter/material.dart';
import '../db/app_database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import '../utils/format.dart';
class ProductsScreen extends StatefulWidget { const ProductsScreen({super.key}); @override State<ProductsScreen> createState()=> _ProductsScreenState();}
class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String,dynamic>> data=[]; String q=''; String kat='Semua';
  @override void initState(){ super.initState(); _load();}
  Future<void> _load() async { final db=await AppDatabase.database; data=await db.query('products', orderBy:'name'); setState((){}); }
  @override Widget build(BuildContext context){
    final cats=['Semua', ...{for(var p in data) p['category'] as String}];
    final filtered=data.where((p){
      final mq=q.isEmpty || (p['name'] as String).toLowerCase().contains(q.toLowerCase()) || (p['code'] as String).toLowerCase().contains(q.toLowerCase());
      final mk=kat=='Semua'|| p['category']==kat; return mq&&mk;
    }).toList();
    return Scaffold(appBar: AppBar(title: const Text('Data Barang'), actions: [
        IconButton(icon: const Icon(Icons.download), tooltip:'Template', onPressed: _downloadTemplate),
        IconButton(icon: const Icon(Icons.upload_file), tooltip:'Import Excel', onPressed: _importExcel),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addDialog, icon: const Icon(Icons.add), label: const Text('Tambah')),
      body: Column(children:[
        Padding(padding: const EdgeInsets.all(12), child: Column(children:[
          TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText:'Cari kode / nama...', border: OutlineInputBorder()), onChanged:(v)=> setState(()=> q=v)),
          const SizedBox(height:8), SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: cats.map((c)=> Padding(padding: const EdgeInsets.only(right:6), child: ChoiceChip(label:Text(c), selected:kat==c, onSelected:(_)=> setState(()=> kat=c)))).toList())),
        ])),
        Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder:(_,i){
          final p=filtered[i];
          return FutureBuilder<int>(future: () async { final db=await AppDatabase.database; return AppDatabase.sisaStok(db, p['id'] as int);}(), builder:(_,s2){
              final stok=s2.data??0; final low=stok <= (p['min_stock'] as int);
              return Card(margin: const EdgeInsets.symmetric(horizontal:12, vertical:4), child: ListTile(
                title: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p['code']} • ${p['category']} • ${p['unit']}\nModal ${rupiah(p['cost_price'])} • Jual ${rupiah(p['selling_price'])}'),
                isThreeLine:true,
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
                  Text('$stok', style: TextStyle(fontWeight:FontWeight.bold, color: stok<=0? Colors.red: low? Colors.orange: Colors.green, fontSize:18)),
                  Text(stok<=0? 'Habis': low? 'Menipis':'Aman', style: TextStyle(fontSize:11, color: stok<=0? Colors.red: low? Colors.orange: Colors.green)),
                ]),
                onTap: ()=> _editStok(p, stok),
              ));
            });
        })),
      ]),
    );
  }
  void _addDialog(){
    final code=TextEditingController(), name=TextEditingController(), cat=TextEditingController(text:'Alat Tulis'), unit=TextEditingController(text:'Pcs'), modal=TextEditingController(), jual=TextEditingController(), awal=TextEditingController(text:'0'), min=TextEditingController(text:'5');
    showDialog(context: context, builder:(_)=> AlertDialog(title: const Text('Tambah Barang'), content: SingleChildScrollView(child: Column(children:[
      TextField(controller: code, decoration: const InputDecoration(labelText:'Kode (B-016)')), TextField(controller: name, decoration: const InputDecoration(labelText:'Nama')),
      TextField(controller: cat, decoration: const InputDecoration(labelText:'Kategori')), TextField(controller: unit, decoration: const InputDecoration(labelText:'Satuan')),
      TextField(controller: modal, decoration: const InputDecoration(labelText:'Harga Modal'), keyboardType: TextInputType.number),
      TextField(controller: jual, decoration: const InputDecoration(labelText:'Harga Jual'), keyboardType: TextInputType.number),
      TextField(controller: awal, decoration: const InputDecoration(labelText:'Stok Awal'), keyboardType: TextInputType.number),
      TextField(controller: min, decoration: const InputDecoration(labelText:'Min Stok'), keyboardType: TextInputType.number),
    ])), actions:[ TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Batal')), FilledButton(onPressed: () async {
      final db=await AppDatabase.database;
      await db.insert('products',{'code':code.text,'name':name.text,'category':cat.text,'unit':unit.text,'cost_price':int.tryParse(modal.text)??0,'selling_price':int.tryParse(jual.text)??0,'initial_stock':int.tryParse(awal.text)??0,'min_stock':int.tryParse(min.text)??5,'created_at':DateTime.now().toIso8601String(),'updated_at':DateTime.now().toIso8601String()});
      Navigator.pop(context); _load();
    }, child: const Text('Simpan'))]));
  }
  void _editStok(Map<String,dynamic> p, int stok){
    final qty=TextEditingController(), note=TextEditingController();
    showDialog(context: context, builder:(_)=> AlertDialog(title: Text('Kelola Stok - ${p['name']}'), content: Column(mainAxisSize: MainAxisSize.min, children:[
      Text('Stok sekarang: $stok'), const SizedBox(height:8),
      TextField(controller: qty, decoration: const InputDecoration(labelText:'Tambah stok (+)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
      const SizedBox(height:8), TextField(controller: note, decoration: const InputDecoration(labelText:'Catatan (supplier)')),
    ]), actions:[ TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Batal')), FilledButton(onPressed: () async {
      final q=int.tryParse(qty.text)??0; if(q<=0) return;
      final db=await AppDatabase.database;
      await db.insert('stock_entries',{'number':'IN-${DateTime.now().millisecondsSinceEpoch}','entry_date':DateTime.now().toIso8601String().substring(0,10),'supplier':note.text.isEmpty?'Manual':note.text,'product_id':p['id'],'quantity':q,'cost_price':p['cost_price'],'note':note.text,'created_at':DateTime.now().toIso8601String(),'updated_at':DateTime.now().toIso8601String()});
      Navigator.pop(context); _load(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stok +$q berhasil')));
    }, child: const Text('Tambah'))]));
  }
}
