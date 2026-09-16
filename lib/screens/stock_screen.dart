import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../utils/format.dart';
class StockScreen extends StatefulWidget { const StockScreen({super.key}); @override State<StockScreen> createState()=> _StockScreenState();}
class _StockScreenState extends State<StockScreen> {
  List<Map<String,dynamic>> data=[];
  @override void initState(){ super.initState(); _load();}
  Future<void> _load() async { final db=await AppDatabase.database; data=await db.rawQuery('SELECT se.*, p.name as pname, p.code as pcode FROM stock_entries se JOIN products p ON p.id=se.product_id ORDER BY se.id DESC'); setState((){}); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('Barang Masuk')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Tambah')),
      body: data.isEmpty? const Center(child: Text('Belum ada barang masuk')): ListView.builder(itemCount: data.length, itemBuilder:(_,i){
        final r=data[i];
        return ListTile(title: Text("${r['pcode']} - ${r['pname']}"), subtitle: Text("${r['number']} • ${tgl(r['entry_date'] as String)} • ${r['supplier']} • Qty ${r['quantity']}"), trailing: Text(rupiah((r['quantity'] as int)*(r['cost_price'] as int)), style: const TextStyle(fontWeight: FontWeight.bold)));
      }),
    );
  }
  void _add() async {
    final db=await AppDatabase.database; final prods=await db.query('products', orderBy:'name');
    int? pid; final qty=TextEditingController(), sup=TextEditingController(text:'Toko ATK'), note=TextEditingController();
    showDialog(context: context, builder:(_)=> StatefulBuilder(builder:(ctx,setS)=> AlertDialog(title: const Text('Tambah Barang Masuk'), content: SingleChildScrollView(child: Column(children:[
      DropdownButtonFormField<int>(value: pid, hint: const Text('Pilih barang'), items: prods.map((p)=> DropdownMenuItem<int>(value: p['id'] as int, child: Text("${p['code']} - ${p['name']}"))).toList(), onChanged:(v)=> setS(()=> pid=v), decoration: const InputDecoration(border: OutlineInputBorder())),
      const SizedBox(height:8), TextField(controller: qty, decoration: const InputDecoration(labelText:'Jumlah', border: OutlineInputBorder()), keyboardType: TextInputType.number),
      const SizedBox(height:8), TextField(controller: sup, decoration: const InputDecoration(labelText:'Supplier')),
      TextField(controller: note, decoration: const InputDecoration(labelText:'Keterangan')),
    ])), actions:[
      TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Batal')),
      FilledButton(onPressed: () async {
        if(pid==null) return; final q=int.tryParse(qty.text)??0; if(q<=0) return;
        final p=prods.firstWhere((e)=> e['id']==pid);
        await db.insert('stock_entries',{'number':'IN-${DateTime.now().millisecondsSinceEpoch}','entry_date':DateTime.now().toIso8601String().substring(0,10),'supplier':sup.text,'product_id':pid,'quantity':q,'cost_price':p['cost_price'],'note':note.text,'created_at':DateTime.now().toIso8601String(),'updated_at':DateTime.now().toIso8601String()});
        Navigator.pop(context); _load();
      }, child: const Text('Simpan')),
    ])));
  }
}
