/// Helper parse data dari API dengan AMAN.
///
/// Aturan dari API_DOCS.md:
/// - Semua angka DECIMAL (`price_per_day`, `deposit`, `subtotal`, `grand_total`,
///   `amount`, `rating_avg`, dst.) dan hasil agregasi `SUM()`
///   (`item_count`, `total_rentals`, `revenue`, ...) dikirim sebagai STRING.
/// - Sebagian angka lain dikirim sebagai number (`id`, `stock`, `quantity`,
///   `total_days`, `pagination.total`, ...).
///
/// Karena itu SEMUA pembacaan angka wajib lewat helper ini.
/// DILARANG cast langsung `as int` / `as double`.
library;

/// Parse ke `double`, hasil `null` bila tidak bisa diparse.
double? tryParseDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  final value = raw.toString().trim();
  if (value.isEmpty) return null;
  return num.tryParse(value)?.toDouble();
}

/// Parse ke `int`, hasil `null` bila tidak bisa diparse.
///
/// Menerima string berformat DECIMAL juga, mis. `"75000.00"` -> `75000`.
int? tryParseInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is double) return raw.round();
  final value = raw.toString().trim();
  if (value.isEmpty) return null;
  return num.tryParse(value)?.round();
}

/// Parse ke `double` dengan nilai pengganti bila gagal.
double parseDouble(Object? raw, {double fallback = 0}) =>
    tryParseDouble(raw) ?? fallback;

/// Parse ke `int` dengan nilai pengganti bila gagal.
int parseInt(Object? raw, {int fallback = 0}) =>
    tryParseInt(raw) ?? fallback;

/// Parse boolean dari `bool`, `0/1` (number), atau `"true"/"1"`.
bool parseBool(Object? raw, {bool fallback = false}) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw == null) return fallback;
  final value = raw.toString().trim().toLowerCase();
  if (value == 'true' || value == '1') return true;
  if (value == 'false' || value == '0') return false;
  return fallback;
}

/// Ambil string yang sudah di-trim, `null` bila kosong.
String? parseString(Object? raw) {
  if (raw == null) return null;
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}
