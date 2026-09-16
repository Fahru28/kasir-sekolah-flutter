import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/kasir_screen.dart';
import 'screens/products_screen.dart';
import 'screens/students_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/debt_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/report_screen.dart';

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
    final pages=[DashboardScreen(onKasir: goToKasir), const KasirScreen(), const ProductsScreen(), const StudentsScreen(), const SalesScreen(), const DebtScreen(), const StockScreen(), const ReportScreen()];
    return Scaffold(
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected:(v)=> setState(()=> idx=v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label:'Dashboard'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label:'Kasir'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label:'Barang'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label:'Siswa'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label:'Jual'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label:'Piutang'),
          NavigationDestination(icon: Icon(Icons.input_outlined), selectedIcon: Icon(Icons.input), label:'Masuk'),
          NavigationDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment), label:'Laporan'),
        ],
      ),
    );
  }
}
