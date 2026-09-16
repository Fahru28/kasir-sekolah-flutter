# kasir-sekolah-flutter

Kasir Sekolah 100% Offline - Flutter + SQLite
Sesuai schema Rails: students, products, sales, sale_items, stock_entries, debt_payments

## Fitur (tanpa Pesanan)
- Dashboard (penjualan hari ini, keuntungan, piutang, stok menipis)
- Kasir (keranjang, Tunai/Transfer/QRIS/Piutang)
- Data Barang + Data Siswa (import Excel + template)
- Penjualan (riwayat + kwitansi PDF)
- Piutang (bayar -> debt_payments)
- Barang Masuk (IN-xxx)
- Laporan Harian (periode, omzet/laba, per kategori, cetak PDF)

## Build APK
Push ke main -> GitHub Actions otomatis build APK, atau klik Actions -> Build APK -> Run workflow.
Download di Artifacts: kasir-sekolah-apk

```bash
flutter pub get
flutter run
flutter build apk --release
```
