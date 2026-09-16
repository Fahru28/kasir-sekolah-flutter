import 'package:intl/intl.dart';
String rupiah(dynamic n) {
  if (n == null) return 'Rp0';
  return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(n);
}
String tgl(String? iso) {
  if (iso == null) return '-';
  try { return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso)); } catch(_){ return iso; }
}
