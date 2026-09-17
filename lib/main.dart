import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/kasir_screen.dart';
import 'screens/products_screen.dart';
import 'screens/students_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/debt_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/report_screen.dart';
import 'screens/backup_screen.dart';

void main() => runApp(const KasirApp());

class KasirApp extends StatelessWidget {
  const KasirApp({super.key});
  @override Widget build(BuildContext context){
    return MaterialApp(
      title: 'Kasir Sekolah',
      theme: ThemeData(useMaterial3:true, colorSchemeSeed: Colors.indigo),
      debugShowCheckedModeBanner:false,
      home: const HomeTabs(),
    );
  }
}

class HomeTabs extends StatefulWidget { const HomeTabs({super.key}); @override State<HomeTabs> createState()=> _HomeTabsState();}
class _HomeTabsState extends State<HomeTabs> {
  int idx=0;
  void goToKasir(){ setState(()=> idx=1); }
  @override Widget build(BuildContext context){
    final pages=[DashboardScreen(onKasir: goToKasir), const KasirScreen(), const ProductsScreen(), const StudentsScreen(), const SalesScreen(), const DebtScreen(), const StockScreen(), const ReportScreen(), const BackupScreen()];
    return Scaffold(
      body: pages[idx],
      drawer: Drawer(child: ListView(padding: EdgeInsets.zero, children:[
        DrawerHeader(decoration: const BoxDecoration(color: Color(0xFF4F46E5)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[const Text('Kasir Sekolah', style: TextStyle(color: Colors.white, fontSize:20, fontWeight: FontWeight.bold)), const SizedBox(height:6), Text('SIT Insantama • ${['Dashboard','Kasir','Barang','Siswa','Jual','Piutang','Masuk','Laporan','Backup'][idx]}', style: const TextStyle(color: Colors.white70, fontSize:12)) ])),
        ...List.generate(9, (i){
          const labels=['Dashboard','Kasir','Barang','Siswa','Penjualan','Piutang','Stok Masuk','Laporan','Backup & Restore'];
          const icons=[Icons.dashboard, Icons.point_of_sale, Icons.inventory_2, Icons.people, Icons.receipt_long, Icons.account_balance_wallet, Icons.input, Icons.assessment, Icons.backup];
          return ListTile(leading: Icon(icons[i]), title: Text(labels[i]), selected: idx==i, selectedTileColor: const Color(0xFFEEF2FF), onTap: (){ Navigator.pop(context); setState(()=> idx=i); });
        }),
      ])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx > 4 ? 0 : idx,
        onDestinationSelected:(v)=> setState(()=> idx=v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label:'Dashboard'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label:'Kasir'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label:'Barang'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label:'Siswa'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label:'Penjualan'),
        ],
      ),
    );
  }
}
