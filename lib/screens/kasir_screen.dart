import 'package:flutter/material.dart';
import '../db/app_database.dart';
import '../utils/format.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
    final today=DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snapshot = List<Map<String,dynamic>>.from(keranjang);
    final capTotal = total; final capProfit = profit; final capItems = totalItem;
    final capStudentName = studentName; final capMetode = metode;
    int saleId = 0;
    await db.transaction((txn) async {
      saleId=await txn.insert('sales',{'number':number,'sale_date':today,'student_id':studentId,'total_items':capItems,'total_amount':capTotal,'payment_method':capMetode,'amount_paid': isPiutang?0:bayar,'status': isPiutang?'Belum Lunas':'Lunas','profit':capProfit,'custom_customer_name': capStudentName, 'created_at':DateTime.now().toIso8601String(),'updated_at':DateTime.now().toIso8601String()});
      for(var it in snapshot){ await txn.insert('sale_items',{'sale_id':saleId,'product_id':it['product_id'],'quantity':it['quantity'],'selling_price':it['selling_price'],'cost_price':it['cost_price'],'subtotal':it['subtotal'],'profit':it['profit'],'created_at':DateTime.now().toIso8601String(),'updated_at':DateTime.now().toIso8601String()}); }
    });
    final kembalian = isPiutang? 0 : bayar - capTotal;
    setState(()=> keranjang.clear());
    bayarCtrl.clear();
    if(!mounted) return;
    final saleMap = {'id': saleId, 'number': number, 'sale_date': today, 'student_name': capStudentName, 'custom_customer_name': capStudentName, 'total_items': capItems, 'total_amount': capTotal, 'payment_method': capMetode, 'amount_paid': isPiutang?0:bayar, 'status': isPiutang?'Belum Lunas':'Lunas', 'profit': capProfit};
    showDialog(context: context, barrierDismissible: false, builder:(dCtx)=> AlertDialog(
      title: const Row(children:[Icon(Icons.check_circle, color: Colors.green), SizedBox(width:8), Text('Transaksi berhasil')]),
      content: Text('$number\nTotal: ${rupiah(capTotal)}\nBayar: ${rupiah(isPiutang?0:bayar)}\n${isPiutang? 'Piutang: ${rupiah(capTotal)}': 'Kembalian: ${rupiah(kembalian)}'}'),
      actions:[
        TextButton(onPressed: ()=> Navigator.pop(dCtx), child: const Text('Tutup')),
        FilledButton.icon(onPressed: () async { Navigator.pop(dCtx); await _cetakKwitansi(saleMap, snapshot); }, icon: const Icon(Icons.print, size:16), label: const Text('Cetak Kwitansi')),
      ],
    ));
  }

  Future<void> _cetakKwitansi(Map<String,dynamic> s, List<Map<String,dynamic>> items) async {
    try {
      final doc = pw.Document();
      final fmt = DateFormat('dd MMMM yyyy', 'id_ID');
      final dateStr = s['sale_date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      DateTime dt; try { dt = DateTime.parse(dateStr); } catch(_){ dt = DateTime.now(); }
      doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), build: (c)=> pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children:[
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children:[
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children:[
            pw.Text('SIT INSANTAMA RANGKASBITUNG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:13, color: PdfColor.fromHex('#4C3F6D'))),
            pw.Text('Jl. Siliwangi, Kp. Cileuweung RT/RW 002/005, Rangkasbitung - Kab. Lebak, Banten', style: const pw.TextStyle(fontSize:7, color: PdfColors.grey600)),
            pw.SizedBox(height:2),
            pw.Text('KWITANSI', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:16, color: PdfColor.fromHex('#4C3F6D'))),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children:[
            pw.Text(s['number'].toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:10)),
            pw.Text(fmt.format(dt), style: const pw.TextStyle(fontSize:8)),
            pw.Text("${s['payment_method']} \u2022 ${s['status']}", style: const pw.TextStyle(fontSize:8, color: PdfColors.grey600)),
          ]),
        ]),
        pw.Divider(thickness:1.5, color: PdfColor.fromHex('#4C3F6D')),
        pw.SizedBox(height:6),
        pw.Text("Pelanggan: ${(s['student_name'] ?? s['custom_customer_name'] ?? 'Umum').toString()}", style: const pw.TextStyle(fontSize:9)),
        pw.SizedBox(height:8),
        pw.TableHelper.fromTextArray(
          headers:['No','Barang','Qty','Harga','Subtotal'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:8, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey800),
          cellStyle: const pw.TextStyle(fontSize:8),
          data: [for(int i=0;i<items.length;i++) [ "${i+1}", (items[i]['name'] ?? items[i]['pname'] ?? '-').toString(), items[i]['quantity'].toString(), rupiah(items[i]['selling_price']), rupiah(items[i]['subtotal'])] ],
        ),
        pw.SizedBox(height:10),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children:[
          pw.Text("Total Item: ${s['total_items']}  \u2022  Total Belanja: ${rupiah(s['total_amount'])}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize:10)),
          pw.Text("Bayar: ${rupiah(s['amount_paid'])}  \u2022  Kembalian/Piutang: ${rupiah((s['amount_paid'] as int? ?? 0) - (s['total_amount'] as int? ?? 0))}", style: const pw.TextStyle(fontSize:8, color: PdfColors.grey700)),
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
      await Printing.layoutPdf(onLayout: (f)=> doc.save());
    } catch(e){
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal cetak: $e')));
    }
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
