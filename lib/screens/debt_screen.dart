import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../utils/format.dart';
class DebtScreen extends StatefulWidget { const DebtScreen({super.key}); @override State<DebtScreen> createState()=> _DebtScreenState();}
class _DebtScreenState extends State<DebtScreen> {
  List<Map<String,dynamic>> data=[];
  @override void initState(){ super.initState(); _load();}
  Future<void> _load() async {
    final db=await AppDatabase.database;
    data=await db.rawQuery('''
      SELECT s.*, st.name as student_name, COALESCE(p.bayar,0) as sudah_bayar, (s.total_amount - COALESCE(p.bayar,0)) as sisa
      FROM sales s LEFT JOIN students st ON st.id=s.student_id
      LEFT JOIN (SELECT sale_id, SUM(amount) as bayar FROM debt_payments GROUP BY sale_id) p ON p.sale_id=s.id
      WHERE s.payment_method='Piutang' ORDER BY s.sale_date DESC
    ''');
    setState((){});
  }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('Piutang')),
      body: data.isEmpty? const Center(child: Text('Tidak ada piutang')): ListView.builder(itemCount: data.length, itemBuilder:(_,i){
        final s=data[i]; final sisa=s['sisa'] as int; final lunas=sisa<=0;
        return Card(margin: const EdgeInsets.symmetric(horizontal:12, vertical:4), color: lunas? Colors.green.shade50: Colors.orange.shade50, child: ListTile(
          title: Text("${s['student_name']??'Umum'} • ${s['number']}"),
          subtitle: Text("Total ${rupiah(s['total_amount'])} • Dibayar ${rupiah(s['sudah_bayar'])} • Sisa ${rupiah(sisa)}\n${tgl(s['sale_date'] as String)}"),
          isThreeLine:true,
          trailing: lunas? const Chip(label: Text('Lunas'), backgroundColor: Colors.green): FilledButton(onPressed: ()=> _bayar(s), child: const Text('Bayar')),
        ));
      }),
    );
  }
  void _bayar(Map<String,dynamic> s){
    final ctrl=TextEditingController(text: '${s['sisa']}'), note=TextEditingController();
    showDialog(context: context, builder:(_)=> AlertDialog(title: Text('Bayar Piutang - ${s['number']}'), content: Column(mainAxisSize: MainAxisSize.min, children:[
      Text("Sisa: ${rupiah(s['sisa'])}"), const SizedBox(height:8),
      TextField(controller: ctrl, decoration: const InputDecoration(labelText:'Jumlah bayar', prefixText:'Rp ', border: OutlineInputBorder()), keyboardType: TextInputType.number),
      const SizedBox(height:8), TextField(controller: note, decoration: const InputDecoration(labelText:'Catatan')),
    ]), actions:[
      TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Batal')),
      FilledButton(onPressed: () async {
        final amt=int.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9]'),''))??0; if(amt<=0) return;
        final db=await AppDatabase.database;
        await db.insert('debt_payments',{'sale_id':s['id'],'payment_date':DateTime.now().toIso8601String().substring(0,10),'amount':amt,'note':note.text,'created_at':DateTime.now().toIso8601String(),'updated_at':DateTime.now().toIso8601String()});
        final sisaNew=(s['sisa'] as int)-amt;
        if(sisaNew<=0){ await db.update('sales',{'status':'Lunas'}, where:'id=?', whereArgs:[s['id']]); }
        else if(amt>0){ await db.update('sales',{'status':'Sebagian'}, where:'id=?', whereArgs:[s['id']]); }
        Navigator.pop(context); _load();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pembayaran ${rupiah(amt)} tercatat')));
      }, child: const Text('Simpan'))]));
  }
}
