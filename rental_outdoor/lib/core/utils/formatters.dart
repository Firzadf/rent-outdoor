import 'package:intl/intl.dart';

/// Format tampilan (Bahasa Indonesia).
///
/// - Rupiah: `Rp 75.000`
/// - Tanggal: `8 Okt 2026`
///
/// Locale data `id_ID` diinisialisasi di `main()` melalui
/// `initializeDateFormatting('id_ID')` sebelum `runApp`.
final NumberFormat _rupiahFormat = NumberFormat('#,##0', 'id_ID');
final DateFormat _dateFormat = DateFormat('d MMM yyyy', 'id_ID');
final DateFormat _dateTimeFormat = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
final DateFormat _isoDate = DateFormat('yyyy-MM-dd');
final DateFormat _isoDateTime = DateFormat('yyyy-MM-dd HH:mm:ss');

/// Format angka menjadi Rupiah, mis. `75000` -> `Rp 75.000`.
String formatRupiah(num? value) => 'Rp ${_rupiahFormat.format(value ?? 0)}';

/// Format tanggal ISO (`YYYY-MM-DD` atau `YYYY-MM-DD HH:mm:ss`)
/// menjadi `8 Okt 2026`. Bila gagal, teks asli dikembalikan.
String formatDate(Object? value) {
  final raw = _normalize(value);
  if (raw == null) return '-';
  try {
    final day = raw.length >= 10 ? raw.substring(0, 10) : raw;
    return _dateFormat.format(_isoDate.parseStrict(day));
  } catch (_) {
    return raw;
  }
}

/// Format tanggal+waktu ISO menjadi `8 Okt 2026, 13:24`.
String formatDateTime(Object? value) {
  final raw = _normalize(value);
  if (raw == null) return '-';
  try {
    final moment = raw.length >= 19 ? raw.substring(0, 19) : raw;
    return _dateTimeFormat.format(_isoDateTime.parseStrict(moment));
  } catch (_) {
    return formatDate(value);
  }
}

/// Format [DateTime] menjadi `YYYY-MM-DD` untuk query API
/// (mis. `?pickup_date=2026-11-01`).
String formatIsoDate(DateTime date) => _isoDate.format(date);

String? _normalize(Object? value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  return raw.isEmpty ? null : raw;
}
