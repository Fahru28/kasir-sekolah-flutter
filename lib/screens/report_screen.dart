import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../utils/format.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportScreen extends StatefulWidget { const ReportScreen({super.key}); @override State<ReportScreen> createState()=> _ReportScreenState(); }
class _ReportScreenState extends State<ReportScreen> {
  DateTime from = DateTime.now().subtract(const Duration(days:30));
  DateTime to = DateTime.now();
  List<Map<String,dynamic>> sales=[];
  int totalOmzet=0, totalProfit=0, totalTrx=0, tunai=0, transfer=0, piutang=0;
  List<MapEntry<String,int>> topProducts=[];
  Map<String,int> byCatMakanan={'qty':0,'omzet':0,'profit':0};
  Map<String,int> byCatBarang={'qty':0,'omzet':0,'profit':0};
  bool loading=true;

  @override void initState(){ super.initState(); _load(); }

  Future<void> _pickFrom() async {
    final d=await showDatePicker(context: context, initialDate: from, firstDate: DateTime(2024), lastDate: DateTime(2030));
    if(d!=null){ setState(()=> from=d); _load(); }
  }
  Future<void> _pickTo() async {
    final d=await showDatePicker(context: context, initialDate: to, firstDate: DateTime(2024), lastDate: DateTime(2030));
    if(d!=null){ setState(()=> to=d); _load(); }
  }

  Future<void> _load() async {
    setState(()=> loading=true);
    final db=await AppDatabase.database;
    final fStr=DateFormat('yyyy-MM-dd').format(from);
    final tStr=DateFormat('yyyy-MM-dd').format(to);
    final rows=await db.rawQuery('SELECT s.*, st.name as student_name FROM sales s LEFT JOIN students st ON st.id=s.student_id WHERE s.sale_date BETWEEN ? AND ? ORDER BY s.sale_date DESC, s.id DESC', [fStr,tStr]);
    int omzet=0, profit=0, tTunai=0, tTransfer=0, tPiutang=0;
    for(var r in rows){
      omzet+= (r['total_amount'] as int? ?? 0);
      profit+= (r['profit'] as int? ?? 0);
      final pm=(r['payment_method'] as String? ?? '');
      if(pm=='Tunai') tTunai+= (r['total_amount'] as int? ?? 0);
      else if(pm=='Transfer' || pm=='QRIS') tTransfer+= (r['total_amount'] as int? ?? 0);
      else if(pm=='Piutang') tPiutang+= (r['total_amount'] as int? ?? 0);
    }
    // top products
    final topRows=await db.rawQuery('SELECT p.name as name, COALESCE(SUM(si.quantity),0) as qty FROM sale_items si JOIN sales s ON s.id=si.sale_id JOIN products p ON p.id=si.product_id WHERE s.sale_date BETWEEN ? AND ? GROUP BY p.name ORDER BY qty DESC LIMIT 5', [fStr,tStr]);
    final tops=topRows.map((e)=> MapEntry(e['name'] as String, (e['qty'] as int? ?? 0))).toList();

    // by category
    final catRows=await db.rawQuery('SELECT p.category as cat, si.quantity as qty, si.subtotal as sub, si.profit as pf FROM sale_items si JOIN sales s ON s.id=si.sale_id JOIN products p ON p.id=si.product_id WHERE s.sale_date BETWEEN ? AND ?', [fStr,tStr]);
    var mQty=0,mOmzet=0,mProfit=0,bQty=0,bOmzet=0,bProfit=0;
    for(var r in catRows){
      final cat=(r['cat'] as String? ?? '').trim();
      final isMakan= cat=='Makanan' || cat=='Minuman';
      final q=(r['qty'] as int? ?? 0);
      final sub=(r['sub'] as int? ?? 0);
      final pf=(r['pf'] as int? ?? 0);
      if(isMakan){ mQty+=q; mOmzet+=sub; mProfit+=pf; } else { bQty+=q; bOmzet+=sub; bProfit+=pf; }
    }
    setState((){
      sales=rows; totalOmzet=omzet; totalProfit=profit; totalTrx=rows.length;
      tunai=tTunai; transfer=tTransfer; piutang=tPiutang;
      topProducts=tops;
      byCatMakanan={'qty':mQty,'omzet':mOmzet,'profit':mProfit};
      byCatBarang={'qty':bQty,'omzet':bOmzet,'profit':bProfit};
      loading=false;
    });
  }

  Future<void> _printPdf() async {
    final doc=pw.Document();
    final fFmt=DateFormat('dd MMM yyyy', 'id_ID');
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(24), build: (c)=> [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children:[
          pw.Text('SIT INSANTAMA RANGKASBITUNG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:14, color: PdfColor.fromHex('#4C3F6D'))),
          pw.Text('Jl. Siliwangi, Kp. Cileuweung RT/RW 002/005, Kec. Rangkasbitung, Kab. Lebak, Banten', style: const pw.TextStyle(fontSize:7, color: PdfColors.grey700)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children:[
          pw.Text('LAPORAN PENJUALAN', style: pw.TextStyle(fontWeight:pw.FontWeight.bold, fontSize:9)),
          pw.Text('Periode: ${fFmt.format(from)} - ${fFmt.format(to)}', style: const pw.TextStyle(fontSize:8)),
          pw.Text('Dicetak: ${fFmt.format(DateTime.now())} • $totalTrx transaksi', style: const pw.TextStyle(fontSize:7, color: PdfColors.grey600)),
        ]),
      ]),
      pw.Divider(color: PdfColor.fromHex('#4C3F6D'), thickness:2),
      pw.SizedBox(height:8),
      pw.TableHelper.fromTextArray(
        headers:['Ringkasan','Nilai','Rincian','Nilai'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:8, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
        cellStyle: const pw.TextStyle(fontSize:8),
        data:[
          ['Total Omzet', rupiah(totalOmzet), 'Tunai', rupiah(tunai)],
          ['Total Transaksi', '$totalTrx trx', 'Transfer/QRIS', rupiah(transfer)],
          ['Total Keuntungan', rupiah(totalProfit), 'Piutang', rupiah(piutang)],
          ['Margin', totalOmzet>0 ? '${(totalProfit/totalOmzet*100).toStringAsFixed(1)}%' : '-', 'Barang terlaris', topProducts.isEmpty? '-' : (topProducts.map((e)=> '${e.key} (${e.value})').join(', ').length>45? topProducts.map((e)=> '${e.key} (${e.value})').join(', ').substring(0,45)+'...' : topProducts.map((e)=> '${e.key} (${e.value})').join(', '))],
        ],
      ),
      pw.SizedBox(height:12),
      pw.Text('Rincian per Kategori', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:9)),
      pw.SizedBox(height:4),
      pw.TableHelper.fromTextArray(
        headers:['Kategori','Qty','Omzet','Laba'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:8, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
        cellStyle: const pw.TextStyle(fontSize:8),
        data:[
          ['Makanan & Minuman','${byCatMakanan['qty']} item', rupiah(byCatMakanan['omzet']), rupiah(byCatMakanan['profit'])],
          ['Barang (ATK/Seragam)','${byCatBarang['qty']} item', rupiah(byCatBarang['omzet']), rupiah(byCatBarang['profit'])],
          ['TOTAL','${(byCatMakanan['qty']!+byCatBarang['qty']!)} item', rupiah(byCatMakanan['omzet']!+byCatBarang['omzet']!), rupiah(byCatMakanan['profit']!+byCatBarang['profit']!)],
        ],
      ),
      pw.SizedBox(height:12),
      pw.Text('Detail Transaksi', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:9)),
      pw.SizedBox(height:4),
      pw.TableHelper.fromTextArray(
        headers:['Tgl','No','Siswa','Item','Total','Laba','Metode','Status'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:7, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
        cellStyle: const pw.TextStyle(fontSize:7),
        data: sales.map((s)=> [
          s['sale_date'].toString(), s['number'].toString(), (s['student_name'] ?? s['custom_customer_name'] ?? 'Umum').toString(),
          s['total_items'].toString(), rupiah(s['total_amount']), rupiah(s['profit']), s['payment_method'].toString(), s['status'].toString()
        ]).toList(),
      ),
      pw.SizedBox(height:24),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(children:[
        pw.Text('Rangkasbitung, ${fFmt.format(DateTime.now())}', style: const pw.TextStyle(fontSize:8)),
        pw.SizedBox(height:28),
        pw.Text('Kepala Unit / Bendahara', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:8)),
        pw.Text('SIT Insantama Rangkasbitung', style: const pw.TextStyle(fontSize:7, color: PdfColors.grey600)),
      ])),
    ]));
    await Printing.layoutPdf(onLayout: (f)=> doc.save());
  }

  @override Widget build(BuildContext c){
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Penjualan Harian'), actions:[IconButton(icon: const Icon(Icons.print), onPressed: _printPdf, tooltip:'Cetak PDF')]),
      body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children:[
        Row(children:[
          Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.calendar_today, size:16), label: Text(DateFormat('dd/MM/yyyy').format(from)), onPressed: _pickFrom)),
          const SizedBox(width:8),
          Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.calendar_today, size:16), label: Text(DateFormat('dd/MM/yyyy').format(to)), onPressed: _pickTo)),
          const SizedBox(width:8),
          FilledButton.icon(icon: const Icon(Icons.print, size:16), label: const Text('Cetak'), onPressed: _printPdf),
        ]),
        const SizedBox(height:12),
        GridView.count(crossAxisCount:2, shrinkWrap:true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing:8, mainAxisSpacing:8, childAspectRatio:1.55, children:[
          _stat('Total Omzet', rupiah(totalOmzet), '$totalTrx transaksi', Colors.indigo),
          _stat('Total Keuntungan', rupiah(totalProfit), 'Laba kotor', Colors.green),
          _stat('Tunai / Transfer / Piutang', '${rupiah(tunai)} / ${rupiah(transfer)} / ${rupiah(piutang)}', 'Per metode', Colors.teal),
          _stat('Barang Terlaris', topProducts.isEmpty? '-' : topProducts.map((e)=> '${e.key} (${e.value})').join(', '), 'Top 5', Colors.orange),
        ]),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Row(children:[Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.restaurant, size:14, color: Colors.orange)), const SizedBox(width:8), const Expanded(child: Text('Makanan & Minuman', style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)))]),
            const SizedBox(height:8),
            Text('${byCatMakanan['qty']} item', style: const TextStyle(fontSize:11, color: Colors.black54)),
            const SizedBox(height:4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[ Text('Omzet', style: TextStyle(fontSize:11, color: Colors.grey.shade600)), Text(rupiah(byCatMakanan['omzet']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize:12))]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[ Text('Laba', style: TextStyle(fontSize:11, color: Colors.grey.shade600)), Text(rupiah(byCatMakanan['profit']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize:12, color: Colors.green))]),
          ])))),
          const SizedBox(width:8),
          Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Row(children:[Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.lightBlue.shade100, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.inventory_2, size:14, color: Colors.lightBlue)), const SizedBox(width:8), const Expanded(child: Text('Barang', style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)))]),
            const SizedBox(height:8),
            Text('${byCatBarang['qty']} item', style: const TextStyle(fontSize:11, color: Colors.black54)),
            const SizedBox(height:4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[ Text('Omzet', style: TextStyle(fontSize:11, color: Colors.grey.shade600)), Text(rupiah(byCatBarang['omzet']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize:12))]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[ Text('Laba', style: TextStyle(fontSize:11, color: Colors.grey.shade600)), Text(rupiah(byCatBarang['profit']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize:12, color: Colors.green))]),
          ])))),
        ]),
        const SizedBox(height:12),
        Text('Transaksi (${sales.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height:8),
        ...sales.map((s)=> Card(child: ListTile(dense:true, title: Text(s['number'] as String, style: const TextStyle(fontFamily:'monospace', fontWeight: FontWeight.bold, fontSize:12)), subtitle: Text("${s['sale_date']} • ${s['student_name'] ?? s['custom_customer_name'] ?? 'Umum'} • ${s['total_items']} item"), trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children:[Text(rupiah(s['total_amount']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize:12)), Text(s['status'] as String, style: TextStyle(fontSize:10, color: s['status']=='Lunas'? Colors.green : Colors.orange))]), onTap: ()=> _showDetail(s)))),
        if(sales.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Tidak ada penjualan pada periode ini'))),
      ])),
    );
  }
  void _showDetail(Map<String, dynamic> sale) {
    final customer = sale['student_name'] ?? sale['custom_customer_name'] ?? 'Umum';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sale['number']?.toString() ?? 'Detail Transaksi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tanggal: ${sale['sale_date'] ?? '-'}'),
            Text('Pelanggan: $customer'),
            Text('Jumlah item: ${sale['total_items'] ?? 0}'),
            Text('Total: ${rupiah(sale['total_amount'] ?? 0)}'),
            Text('Laba: ${rupiah(sale['profit'] ?? 0)}'),
            Text('Metode: ${sale['payment_method'] ?? '-'}'),
            Text('Status: ${sale['status'] ?? '-'}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup')),
        ],
      ),
    );
  }
  Widget _stat(String t,String v,String sub,Color c)=> Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[ Text(t, style: const TextStyle(fontSize:11, color: Colors.black54), maxLines:1, overflow: TextOverflow.ellipsis), const SizedBox(height:4), Text(v, style: TextStyle(fontWeight: FontWeight.bold, color:c, fontSize:12), maxLines:2, overflow: TextOverflow.ellipsis), Text(sub, style: const TextStyle(fontSize:10, color: Colors.black38), maxLines:1, overflow: TextOverflow.ellipsis) ])));
}
