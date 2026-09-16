import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../utils/format.dart';
class DashboardScreen extends StatefulWidget { final VoidCallback? onKasir; const DashboardScreen({super.key, this.onKasir}); @override State<DashboardScreen> createState()=> _DashboardScreenState(); }
class _DashboardScreenState extends State<DashboardScreen> {
  Map<String,int> stats={'harian':0,'transaksi':0,'profit':0,'piutang':0,'tipis':0};
  @override void initState(){ super.initState(); _load();}
  Future<void> _load() async {
    final db = await AppDatabase.database;
    final today = DateTime.now().toIso8601String().substring(0,10);
    final penjualanHari = _firstInt(await db.rawQuery("SELECT COALESCE(SUM(total_amount),0) FROM sales WHERE sale_date=?",[today]))??0;
    final trxHari = _firstInt(await db.rawQuery("SELECT COUNT(*) FROM sales WHERE sale_date=?",[today]))??0;
    final profitHari = _firstInt(await db.rawQuery("SELECT COALESCE(SUM(profit),0) FROM sales WHERE sale_date=?",[today]))??0;
    final piutang = await AppDatabase.totalPiutang(db);
    // stok menipis
    final prods = await db.query('products');
    int tipis=0;
    for(var p in prods){ final sisa=await AppDatabase.sisaStok(db, p['id'] as int); if(sisa <= (p['min_stock'] as int)) tipis++; }
    setState(()=> stats={'harian':penjualanHari,'transaksi':trxHari,'profit':profitHari,'piutang':piutang,'tipis':tipis});
  }
  int _firstInt(List<Map<String,dynamic>> r){ if(r.isEmpty) return 0; final v=r.first.values.first; if(v is int) return v; if(v is num) return v.toInt(); return 0; }
  @override Widget build(BuildContext context){
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children:[
      Text('Dashboard Kasir Sekolah', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height:12),
      GridView.count(crossAxisCount:2, shrinkWrap:true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing:12, mainAxisSpacing:12, childAspectRatio:1.6, children:[
        _card(Icons.payments,'Penjualan Hari Ini',rupiah(stats['harian']),Colors.indigo),
        _card(Icons.receipt_long,'Transaksi Hari Ini','${stats['transaksi']} trx',Colors.teal),
        _card(Icons.trending_up,'Keuntungan Hari Ini',rupiah(stats['profit']),Colors.green),
        _card(Icons.warning_amber,'Piutang Berjalan',rupiah(stats['piutang']),Colors.orange),
        _card(Icons.inventory_2,'Stok Menipis','${stats['tipis']} barang',Colors.red),
      ]),
      const SizedBox(height:16),
      FilledButton.icon(onPressed: (){ if(widget.onKasir!=null) widget.onKasir!(); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buka tab Kasir di bawah'))); }, icon: const Icon(Icons.point_of_sale), label: const Text('Buka Kasir')),
    ]));
  }
  Widget _card(IconData icon,String title,String value,Color c){
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
      Icon(icon,color:c), const SizedBox(height:8), Text(title, style: const TextStyle(fontSize:12, color:Colors.black54)), const SizedBox(height:4), Text(value, style: TextStyle(fontWeight:FontWeight.bold, color:c, fontSize:16)),
    ])));
  }
}
