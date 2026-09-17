import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static Database? _db;
  static void resetForRestore(){ _db=null; }
  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }
  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'kasir_sekolah.db');
    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _onUpgrade, onConfigure: (db) async {
      await db.execute('PRAGMA journal_mode=WAL');
      await db.execute('PRAGMA foreign_keys=ON');
    }, onOpen: (db) async {
      await db.execute('PRAGMA journal_mode=WAL');
    });
  }
  static Future _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) await _createIndexes(db);
  }
  static Future _createIndexes(Database db) async {
    // index paling penting untuk ribuan transaksi jangka panjang
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_sale_date ON sales(sale_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_student ON sales(student_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_entries_product ON stock_entries(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_entries_date ON stock_entries(entry_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_debt_payments_sale ON debt_payments(sale_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_code ON products(code)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_category ON products(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_students_code ON students(code)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_students_active ON students(active)');
  }
  static Future _createDB(Database db, int version) async {
    // students - sesuai schema.rb
    await db.execute('''
      CREATE TABLE students(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE,
        nis TEXT,
        name TEXT,
        class_name TEXT,
        guardian_name TEXT,
        phone TEXT,
        address TEXT,
        active INTEGER DEFAULT 1,
        created_at TEXT, updated_at TEXT
      )''');
    // products
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE,
        name TEXT,
        category TEXT,
        unit TEXT,
        cost_price INTEGER,
        selling_price INTEGER,
        initial_stock INTEGER,
        min_stock INTEGER,
        created_at TEXT, updated_at TEXT
      )''');
    // sales
    await db.execute('''
      CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT UNIQUE,
        sale_date TEXT,
        student_id INTEGER,
        total_items INTEGER,
        total_amount INTEGER,
        payment_method TEXT,
        amount_paid INTEGER,
        status TEXT,
        profit INTEGER,
        custom_customer_name TEXT,
        created_at TEXT, updated_at TEXT,
        FOREIGN KEY(student_id) REFERENCES students(id)
      )''');
    // sale_items
    await db.execute('''
      CREATE TABLE sale_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER, product_id INTEGER,
        quantity INTEGER, selling_price INTEGER, cost_price INTEGER,
        subtotal INTEGER, profit INTEGER,
        created_at TEXT, updated_at TEXT,
        FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id)
      )''');
    // stock_entries
    await db.execute('''
      CREATE TABLE stock_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT, entry_date TEXT, supplier TEXT,
        product_id INTEGER, quantity INTEGER, cost_price INTEGER, note TEXT,
        created_at TEXT, updated_at TEXT,
        FOREIGN KEY(product_id) REFERENCES products(id)
      )''');
    // debt_payments
    await db.execute('''
      CREATE TABLE debt_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER, payment_date TEXT, amount INTEGER, note TEXT,
        created_at TEXT, updated_at TEXT,
        FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE
      )''');
    // orders + order_items (sesuai schema.rb - keep parity)
    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT, customer_class TEXT, customer_phone TEXT,
        note TEXT, status TEXT, total_amount INTEGER,
        sale_id INTEGER, created_at TEXT, updated_at TEXT,
        FOREIGN KEY(sale_id) REFERENCES sales(id)
      )''');
    await db.execute('''
      CREATE TABLE order_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER, product_id INTEGER,
        quantity INTEGER, price INTEGER, subtotal INTEGER,
        created_at TEXT, updated_at TEXT,
        FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id)
      )''');
    await _seed(db);
  }
  static Future _seed(Database db) async {
    final now = DateTime.now().toIso8601String();
    // 10 siswa dari Data_Anak
    final students = [
      ['A-001','1001','Budi Santoso','1A','Agus Santoso','08123456701','Jl. Merdeka 1'],
      ['A-002','1002','Siti Aminah','1B','Ahmad','08123456702','Jl. Sudirman 2'],
      ['A-003','1003','Andi Wijaya','2A','Budi W','08123456703','Jl. Mawar 3'],
      ['A-004','1004','Rina Melati','2B','Hasan','08123456704','Jl. Melati 4'],
      ['A-005','1005','Dika Pratama','3A','Joko','08123456705','Jl. Anggrek 5'],
      ['A-006','1006','Nisa Kamil','3B','Kamil','08123456706','Jl. Kenanga 6'],
      ['A-007','1007','Fajar Siddiq','1A','Siddiq','08123456707','Jl. Kamboja 7'],
      ['A-008','1008','Lestari','1B','Parno','08123456708','Jl. Dahlia 8'],
      ['A-009','1009','Reza Rahadian','2A','Rahman','08123456709','Jl. Flamboyan 9'],
      ['A-010','1010','Ayu Ting','2B','Ting','08123456710','Jl. Teratai 10'],
    ];
    for (var s in students) {
      await db.insert('students', {'code':s[0],'nis':s[1],'name':s[2],'class_name':s[3],'guardian_name':s[4],'phone':s[5],'address':s[6],'active':1,'created_at':now,'updated_at':now});
    }
    // 15 barang dari Data_Barang
    final products = [
      ['B-001','Buku Tulis Sinar','Alat Tulis','Pcs',3000,4000,50,10],
      ['B-002','Pensil 2B','Alat Tulis','Pcs',1000,2000,100,20],
      ['B-003','Penghapus','Alat Tulis','Pcs',500,1000,50,10],
      ['B-004','Penggaris 30cm','Alat Tulis','Pcs',1500,2500,30,5],
      ['B-005','Air Mineral 600ml','Minuman','Botol',2500,3500,100,20],
      ['B-006','Susu Coklat','Minuman','Kotak',3500,5000,50,10],
      ['B-007','Roti Coklat','Makanan','Bungkus',2000,3000,40,10],
      ['B-008','Biskuit','Makanan','Bungkus',1500,2500,60,15],
      ['B-009','Nasi Kuning','Makanan','Bungkus',5000,7000,20,5],
      ['B-010','Seragam SD Putih','Seragam','Pcs',45000,60000,20,5],
      ['B-011','Seragam SD Merah','Seragam','Pcs',45000,60000,20,5],
      ['B-012','Dasi SD','Seragam','Pcs',5000,10000,30,10],
      ['B-013','Topi SD','Seragam','Pcs',10000,15000,30,10],
      ['B-014','Buku Gambar A4','Alat Tulis','Pcs',4000,6000,40,10],
      ['B-015','Spidol Hitam','Alat Tulis','Pcs',6000,8500,25,5],
    ];
    for (var p in products) {
      await db.insert('products', {'code':p[0],'name':p[1],'category':p[2],'unit':p[3],'cost_price':p[4],'selling_price':p[5],'initial_stock':p[6],'min_stock':p[7],'created_at':now,'updated_at':now});
    }
    // 2 Barang_Masuk seed
    await db.insert('stock_entries', {'number':'IN-001','entry_date':'2026-09-01','supplier':'Toko ATK','product_id':1,'quantity':50,'cost_price':3000,'note':'Stok Bulanan','created_at':now,'updated_at':now});
    await db.insert('stock_entries', {'number':'IN-002','entry_date':'2026-09-01','supplier':'Toko ATK','product_id':2,'quantity':100,'cost_price':1000,'note':'Stok Bulanan','created_at':now,'updated_at':now});
  }
  static Future<Map<int,int>> stocksMap(Database db) async {
    final prods = await db.query('products', columns:['id','initial_stock']);
    final masukRows = await db.rawQuery('SELECT product_id as pid, COALESCE(SUM(quantity),0) as tot FROM stock_entries GROUP BY product_id');
    final keluarRows = await db.rawQuery('SELECT product_id as pid, COALESCE(SUM(quantity),0) as tot FROM sale_items GROUP BY product_id');
    final masuk = {for(var r in masukRows) (r['pid'] as int): (r['tot'] as int? ?? 0)};
    final keluar = {for(var r in keluarRows) (r['pid'] as int): (r['tot'] as int? ?? 0)};
    return {for(var p in prods) (p['id'] as int): ((p['initial_stock'] as int? ?? 0) + (masuk[p['id']] ?? 0) - (keluar[p['id']] ?? 0))};
  }
  static Future<int> sisaStok(Database db, int productId) async {
    final p = (await db.query('products', where:'id=?', whereArgs:[productId])).first;
    final masuk = Sqflite.firstIntValue(await db.rawQuery('SELECT COALESCE(SUM(quantity),0) FROM stock_entries WHERE product_id=?',[productId]))??0;
    final keluar = Sqflite.firstIntValue(await db.rawQuery('SELECT COALESCE(SUM(quantity),0) FROM sale_items WHERE product_id=?',[productId]))??0;
    return (p['initial_stock'] as int) + masuk - keluar;
  }
  static Future<int> totalPiutang(Database db) async {
    // Piutang = sales piutang - debt_payments
    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(s.total_amount - COALESCE(p.bayar,0)),0) as sisa
      FROM sales s LEFT JOIN (SELECT sale_id, SUM(amount) as bayar FROM debt_payments GROUP BY sale_id) p ON p.sale_id=s.id
      WHERE s.payment_method='Piutang' AND s.status != 'Lunas'
    ''');
    return (res.first['sisa'] as int?) ?? 0;
  }
}
