import 'package:flutter/material.dart';
import '../db/app_database.dart';
import 'package:intl/intl.dart';
import '../utils/format.dart';
class SalesScreen extends StatefulWidget { const SalesScreen({super.key}); @override State<SalesScreen> createState()=> _SalesScreenState();}
class _SalesScreenState extends State<SalesScreen> {
  List<Map<String,dynamic>> data=[];
  @override void initState(){ super.initState(); _load();}
  int _limit=50; bool _hasMore=true; bool _loadingMore=false;
  Future<void> _load({bool more=false}) async {
    if(!more){ _limit=50; _hasMore=true; }
    if(_loadingMore) return;
    _loadingMore=true; final db=await AppDatabase.database;
    final rows=await db.rawQuery('SELECT s.*, st.name as student_name FROM sales s LEFT JOIN students st ON st.id=s.student_id ORDER BY s.id DESC LIMIT ?', [_limit+1]);
    _hasMore = rows.length > _limit;
    data = _hasMore ? rows.sublist(0,_limit) : rows;
    _loadingMore=false; if(mounted) setState((){}); }
  Future<void> _loadMore() async { if(!_hasMore) return; _limit+=50; await _load(more:true); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('Penjualan')), body: data.isEmpty? const Center(child: Text('Belum ada transaksi')): Column(children:[
      Expanded(child: RefreshIndicator(onRefresh: ()=> _load(), child: ListView.builder(itemCount: data.length, itemBuilder:(_,i){
        final s=data[i];
        return Card(margin: const EdgeInsets.symmetric(horizontal:12, vertical:4), child: ListTile(
          title: Text(s['number'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily:'monospace')),
          subtitle: Text("${tgl(s['sale_date'] as String)} • ${s['student_name']?? s['custom_customer_name']?? 'Umum'} • ${s['total_items']} item • ${s['payment_method']}"),
          trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children:[
            Text(rupiah(s['total_amount']), style: const TextStyle(fontWeight: FontWeight.bold)),
            Chip(label: Text(s['status'] as String, style: const TextStyle(fontSize:11)), backgroundColor: s['status']=='Lunas'? Colors.green.shade100: Colors.orange.shade100, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
          ]),
          onTap: ()=> _detail(s),
        ));
      }))),
      if(_hasMore) Padding(padding: const EdgeInsets.all(12), child: Center(child: OutlinedButton.icon(onPressed: _loadMore, icon: const Icon(Icons.expand_more), label: Text('Muat 50 lagi (${data.length} tampil)')))),
    ]));
  }

  void _detail(Map<String,dynamic> s) async {
    final db=await AppDatabase.database;
    final items=await db.rawQuery('SELECT si.*, p.name as pname FROM sale_items si JOIN products p ON p.id=si.product_id WHERE si.sale_id=?', [s['id']]);
    if(!mounted) return;
    showModalBottomSheet(context: context, isScrollControlled:true, builder:(_)=> DraggableScrollableSheet(expand:false, initialChildSize:0.8, builder:(_,ctrl)=> ListView(controller:ctrl, padding: const EdgeInsets.all(16), children:[
      Text(s['number'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize:18)), Text("${tgl(s['sale_date'] as String)} • ${s['student_name']??'Umum'} • ${s['payment_method']} • ${s['status']}"),
      const Divider(height:16),
      ...items.map((it)=> ListTile(title: Text(it['pname'] as String), subtitle: Text("${it['quantity']} x ${rupiah(it['selling_price'])}"), trailing: Text(rupiah(it['subtotal'])))),
      const Divider(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[ const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), Text(rupiah(s['total_amount']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize:16))]),
      Text("Keuntungan: ${rupiah(s['profit'])} • Bayar: ${rupiah(s['amount_paid'])}", style: const TextStyle(color: Colors.black54)),
      const SizedBox(height:12),
      FilledButton.icon(onPressed: ()=> Navigator.pop(context), icon: const Icon(Icons.close), label: const Text('Tutup')),
    ])));
  }
}
