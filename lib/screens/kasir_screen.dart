import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../utils/format.dart';
import 'package:intl/intl.dart';
class KasirScreen extends StatefulWidget { const KasirScreen({super.key}); @override State<KasirScreen> createState()=> _KasirScreenState(); }
class _KasirScreenState extends State<KasirScreen> {
  List<Map<String,dynamic>> keranjang=[];
  int? studentId; String? studentName;
  String metode='Tunai'; final bayarCtrl=TextEditingController();
  int get total => keranjang.fold(0,(s,e)=> s + (e['subtotal'] as int));
  int get profit => keranjang.fold(0,(s,e)=> s + (e['profit'] as int));
  int get totalItem => keranjang.fold(0,(s,e)=> s + (e['quantity'] as int));
  Future<void> _pickBarang() async {
    final db=await AppDatabase.database;
    final prods=await db.query('products', orderBy:'name');
    if(!mounted) return;
    showModalBottomSheet(context: context, isScrollControlled:true, builder:(ctx){
      String q=''; String kat='Semua';
      final cats=['Semua', ...{for(var p in prods) p['category'] as String}];
      return StatefulBuilder(builder:(ctx,setM){
        final filtered=prods.where((p){
          final matchQ = q.isEmpty || (p['name'] as String).toLowerCase().contains(q.toLowerCase()) || (p['code'] as String).toLowerCase().contains(q.toLowerCase());
          final matchKat = kat=='Semua' || p['category']==kat;
          return matchQ && matchKat;
        }).toList();
        return DraggableScrollableSheet(expand:false, initialChildSize:0.85, builder:(_,ctrl)=> Column(children:[
          Padding(padding: const EdgeInsets.all(12), child: Column(children:[
            TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText:'Cari kode / nama...', border: OutlineInputBorder()), onChanged:(v)=> setM(()=> q=v)),
            const SizedBox(height:8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: cats.map((c)=> Padding(padding: const EdgeInsets.only(right:6), child: ChoiceChip(label:Text(c), selected:kat==c, onSelected:(_)=> setM(()=> kat=c)))).toList())),
          ])),
          Expanded(child: ListView.builder(controller:ctrl, itemCount: filtered.length, itemBuilder:(_,i){
            final p=filtered[i];
            return FutureBuilder<int>(future: AppDatabase.sisaStok(db, p['id'] as int), builder:(_,snap){
              final stok=snap.data??0; final low= stok <= (p['min_stock'] as int);
              return ListTile(
                title: Text(p['name'] as String, style: const TextStyle(fontWeight:FontWeight.w600)),
                subtitle: Text('${p['code']} • ${p['category']} • Stok $stok • ${rupiah(p['selling_price'])}'),
                trailing: stok<=0? const Chip(label: Text('Habis')): (low? const Chip(label: Text('Menipis'), backgroundColor: Color(0xFFFFF3CD)): null),
                enabled: stok>0,
                onTap: stok<=0? null: ()=> _tambahKeKeranjang(p, stok),
              );
            });
          })),
        ]));
      });
    });
  }
  void _tambahKeKeranjang(Map<String,dynamic> p, int sisa){
    int qty=1;
    showDialog(context: context, builder:(ctx)=> AlertDialog(
      title: Text(p['name'] as String),
      content: StatefulBuilder(builder:(ctx2,setD)=> Column(mainAxisSize: MainAxisSize.min, children:[
        Text('Stok tersedia: $sisa • Harga: ${rupiah(p['selling_price'])}'),
        const SizedBox(height:12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children:[
          IconButton(onPressed: qty>1? ()=> setD(()=> qty--): null, icon: const Icon(Icons.remove_circle_outline)),
          Text('$qty', style: const TextStyle(fontSize:20, fontWeight:FontWeight.bold)),
          IconButton(onPressed: qty < sisa? ()=> setD(()=> qty++): null, icon: const Icon(Icons.add_circle_outline)),
        ])
      ])),
      actions:[
        TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed:(){
          final subtotal= qty * (p['selling_price'] as int);
          final prof= qty * ((p['selling_price'] as int) - (p['cost_price'] as int));
          setState((){
            final idx=keranjang.indexWhere((e)=> e['product_id']==p['id']);
            if(idx>=0){ keranjang[idx]['quantity']+=qty; keranjang[idx]['subtotal']+=subtotal; keranjang[idx]['profit']+=prof; }
            else keranjang.add({'product_id':p['id'],'name':p['name'],'code':p['code'],'quantity':qty,'selling_price':p['selling_price'],'cost_price':p['cost_price'],'subtotal':subtotal,'profit':prof});
          });
          Navigator.pop(ctx); Navigator.pop(context);
        }, child: const Text('Tambah')),
      ],
    ));
  }
  Future<void> _pickSiswa() async {
    final db=await AppDatabase.database;
    final list=await db.query('students', where:'active=1', orderBy:'name');
    if(!mounted) return;
    showModalBottomSheet(context: context, builder:(ctx)=> ListView(
      children:[
        const ListTile(title: Text('Tanpa siswa (Umum)', style: TextStyle(fontWeight:FontWeight.bold))),
        ...list.map((s)=> ListTile(title:Text(s['name'] as String), subtitle: Text('${s['code']} • ${s['class_name']}'), onTap:(){ setState(()=> {studentId=s['id'] as int, studentName=s['name'] as String}); Navigator.pop(ctx);})),
        ListTile(title: const Text('Hapus pilihan'), leading: const Icon(Icons.clear), onTap:(){ setState(()=> {studentId=null, studentName=null}); Navigator.pop(ctx);}),
      ],
    ));
  }
  Future<void> _simpan() async {
    if(keranjang.isEmpty) return;
    final db=await AppDatabase.database;
    final bayar=int.tryParse(bayarCtrl.text.replaceAll(RegExp(r'[^0-9]'),''))??0;
    if(metode!='Piutang' && bayar < total){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nominal bayar kurang'))); return; }
    final isPiutang=metode=='Piutang';
    final number='TRX-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}';
    final today=DateTime.now().toIso8601String().substring(0,10);
    await db.transaction((txn) async {
      final saleId=await txn.insert('sales',{'number':number,'sale_date':today,'student_id':studentId,'total_items':totalItem,'total_amount':total,'payment_method':metode,'amount_paid': isPiutang?0:bayar,'status': isPiutang?'Belum Lunas':'Lunas','profit':profit,'custom_customer_name': studentName, 'created_at':DateTime.now().toIso8601String(),'updated_at':DateTime.now().toIso8601String()});
      for(var it in keranjang){ await txn.insert('sale_items',{'sale_id':saleId,'product_id':it['product_id'],'quantity':it['quantity'],'selling_price':it['selling_price'],'cost_price':it['cost_price'],'subtotal':it['subtotal'],'profit':it['profit'],'created_at':DateTime.now().toIso8601String(),'updated_at':DateTime.now().toIso8601String()}); }
    });
    final kembalian = isPiutang? 0 : bayar - total;
    setState(()=> keranjang.clear());
    bayarCtrl.clear();
    if(!mounted) return;
    showDialog(context: context, builder:(_)=> AlertDialog(
      title: const Text('Transaksi berhasil'),
      content: Text('$number\nTotal: ${rupiah(total)}\nBayar: ${rupiah(isPiutang?0:bayar)}\n${isPiutang? 'Piutang: ${rupiah(total)}': 'Kembalian: ${rupiah(kembalian)}'}'),
      actions:[FilledButton(onPressed: ()=> Navigator.pop(context), child: const Text('OK'))],
    ));
  }
  @override Widget build(BuildContext context){
    final kembalian = (int.tryParse(bayarCtrl.text.replaceAll(RegExp(r'[^0-9]'),''))??0) - total;
    return Scaffold(
      appBar: AppBar(title: const Text('Kasir'), actions:[ Padding(padding: const EdgeInsets.only(right:4), child: Badge(label: Text(keranjang.length.toString()), isLabelVisible: keranjang.isNotEmpty, child: IconButton(icon: const Icon(Icons.shopping_cart), onPressed: (){})))]),
      body: Column(children:[
        Card(margin: const EdgeInsets.all(12), child: Padding(padding: const EdgeInsets.all(12), child: Column(children:[
          InkWell(onTap: _pickSiswa, child: InputDecorator(decoration: const InputDecoration(labelText:'Siswa / Pelanggan', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)), child: Text(studentName ?? 'Umum - ketuk untuk pilih siswa'))),
          const SizedBox(height:8),
          DropdownButtonFormField<String>(value:metode, decoration: const InputDecoration(labelText:'Metode Bayar', border: OutlineInputBorder()), items: const [DropdownMenuItem(value:'Tunai', child: Text('Tunai')), DropdownMenuItem(value:'Transfer', child: Text('Transfer')), DropdownMenuItem(value:'QRIS', child: Text('QRIS')), DropdownMenuItem(value:'Piutang', child: Text('Piutang'))], onChanged:(v)=> setState(()=> metode=v!)),
          if(metode!='Piutang') ...[
            const SizedBox(height:8),
            TextField(controller: bayarCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText:'Nominal Bayar', border: OutlineInputBorder(), prefixText:'Rp '), onChanged:(_)=> setState(()=> {})),
            if(bayarCtrl.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top:6), child: Text(kembalian>=0? 'Kembalian: ${rupiah(kembalian)}':'Kurang: ${rupiah(-kembalian)}', style: TextStyle(color: kembalian>=0? Colors.green: Colors.red, fontWeight: FontWeight.bold))),
          ] else Container(margin: const EdgeInsets.only(top:8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)), child: Row(children:[const Icon(Icons.info_outline, size:16, color:Colors.orange), const SizedBox(width:6), Text('Piutang: ${rupiah(total)} akan tercatat di Piutang', style: const TextStyle(color:Colors.orange))])) ,
        ]))),
        Expanded(child: keranjang.isEmpty? const Center(child: Text('Keranjang kosong\nTap + untuk tambah barang', textAlign: TextAlign.center)): ListView.separated(padding: const EdgeInsets.symmetric(horizontal:12), itemCount: keranjang.length, separatorBuilder:(_,__)=> const Divider(height:1), itemBuilder:(_,i){
          final it=keranjang[i];
          return ListTile(title: Text(it['name']), subtitle: Text("${it['quantity']} x ${rupiah(it['selling_price'])}"), trailing: Row(mainAxisSize: MainAxisSize.min, children:[ Text(rupiah(it['subtotal']), style: const TextStyle(fontWeight:FontWeight.bold)), IconButton(icon: const Icon(Icons.delete_outline, color:Colors.red), onPressed: ()=> setState(()=> keranjang.removeAt(i)))]));
        })),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, boxShadow:[BoxShadow(color: Colors.black12, blurRadius:8)]), child: Column(children:[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[ Text('Total ($totalItem item)', style: const TextStyle(color:Colors.black54)), Text(rupiah(total), style: const TextStyle(fontSize:18, fontWeight:FontWeight.bold))]),
          const SizedBox(height:8),
          SizedBox(width:double.infinity, child: FilledButton.icon(onPressed: keranjang.isEmpty? null: _simpan, icon: const Icon(Icons.save), label: Text(metode=='Piutang'? 'Simpan sebagai Piutang':'Simpan & Bayar'))),
        ])),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _pickBarang, icon: const Icon(Icons.add), label: const Text('Barang')),
    );
  }
}
