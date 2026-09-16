import 'package:flutter/material.dart';
import '../db/app_database.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../utils/format.dart';
class SalesScreen extends StatefulWidget { const SalesScreen({super.key}); @override State<SalesScreen> createState()=> _SalesScreenState();}
class _SalesScreenState extends State<SalesScreen> {
  List<Map<String,dynamic>> data=[];
  @override void initState(){ super.initState(); _load();}
  Future<void> _load() async { final db=await AppDatabase.database; data=await db.rawQuery('SELECT s.*, st.name as student_name FROM sales s LEFT JOIN students st ON st.id=s.student_id ORDER BY s.id DESC'); setState((){}); }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: const Text('Penjualan')), body: data.isEmpty? const Center(child: Text('Belum ada transaksi')): RefreshIndicator(onRefresh: _load, child: ListView.builder(itemCount: data.length, itemBuilder:(_,i){
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
    })));
  }
  Future<void> _printKwitansi(Map<String,dynamic> s, List<Map<String,dynamic>> items) async {
    final doc = pw.Document();
    final fmt = DateFormat('dd MMMM yyyy', 'id_ID');
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), build: (c)=> pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children:[
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children:[
          pw.Text('SIT INSANTAMA RANGKASBITUNG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:13, color: PdfColor.fromHex('#4C3F6D'))),
          pw.Text('Jl. Siliwangi, Kp. Cileuweung RT/RW 002/005, Rangkasbitung - Kab. Lebak, Banten', style: const pw.TextStyle(fontSize:7, color: PdfColors.grey600)),
          pw.SizedBox(height:2),
          pw.Text('KWITANSI', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:16, color: PdfColor.fromHex('#4C3F6D'))),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children:[
          pw.Text(s['number'] as String, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:10)),
          pw.Text(fmt.format(DateTime.tryParse(s['sale_date'] as String) ?? DateTime.now()), style: const pw.TextStyle(fontSize:8)),
          pw.Text("${s['payment_method']} • ${s['status']}", style: const pw.TextStyle(fontSize:8, color: PdfColors.grey600)),
        ]),
      ]),
      pw.Divider(thickness:1.5, color: PdfColor.fromHex('#4C3F6D')),
      pw.SizedBox(height:6),
      pw.Text("Siswa: ${(s['student_name'] ?? s['custom_customer_name'] ?? 'Umum').toString()}${s['class_name']!=null ? ' ('+s['class_name'].toString()+')' : ''}", style: const pw.TextStyle(fontSize:9)),
      pw.SizedBox(height:8),
      pw.TableHelper.fromTextArray(
        headers:['No','Barang','Qty','Harga','Subtotal'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:8, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
        cellStyle: const pw.TextStyle(fontSize:8),
        data: [for(int i=0;i<items.length;i++) [ "${i+1}", items[i]['pname'].toString(), items[i]['quantity'].toString(), rupiah(items[i]['selling_price']), rupiah(items[i]['subtotal'])] ],
      ),
      pw.SizedBox(height:10),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children:[
        pw.Text("Total Item: ${s['total_items']}  •  Total Belanja: ${rupiah(s['total_amount'])}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:10)),
        pw.Text("Bayar: ${rupiah(s['amount_paid'])}  •  Kembalian/Piutang: ${rupiah((s['amount_paid'] as int? ?? 0) - (s['total_amount'] as int? ?? 0))}", style: const pw.TextStyle(fontSize:8, color: PdfColors.grey700)),
        pw.Text("Keuntungan: ${rupiah(s['profit'])}", style: const pw.TextStyle(fontSize:7, color: PdfColors.grey600)),
      ])),
      pw.Spacer(),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(children:[
        pw.Text("Rangkasbitung, ${fmt.format(DateTime.now())}", style: const pw.TextStyle(fontSize:8)),
        pw.SizedBox(height:30),
        pw.Text("Kasir / Bendahara", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:8)),
        pw.Text("SIT Insantama", style: const pw.TextStyle(fontSize:7, color: PdfColors.grey600)),
      ])),
    ])));
    try {
      await Printing.layoutPdf(onLayout: (f)=> doc.save());
    } catch(e){
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal cetak: $e')));
    }
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
      Row(children:[ Expanded(child: OutlinedButton.icon(onPressed: () async { final db2=await AppDatabase.database; final its=await db2.rawQuery('SELECT si.*, p.name as pname FROM sale_items si JOIN products p ON p.id=si.product_id WHERE si.sale_id=?', [s['id']]); await _printKwitansi(s, its); }, icon: const Icon(Icons.print), label: const Text('Cetak Kwitansi'))), const SizedBox(width:8), Expanded(child: FilledButton.icon(onPressed: ()=> Navigator.pop(context), icon: const Icon(Icons.close), label: const Text('Tutup')))]),
    ])));
  }
}
