/// Logika durasi & validasi sewa.
///
/// Aturan dari API_DOCS.md ("Aturan Hitung"):
/// - `total_days` = `return_date - pickup_date` dalam hari, TANPA +1,
///   minimal 1.
/// - Tanggal lampau / `return_date <= pickup_date` ditolak.
///
/// Angka hasil server tetap yang dipercaya untuk perhitungan uang;
/// helper ini hanya untuk tampilan dan validasi UI (termasuk test).
library;

/// Waktu diabaikan — hanya tanggal murni (tahun, bulan, tanggal).
DateTime _dateOnly(DateTime value) => DateTime(
      value.year,
      value.month,
      value.day,
    );

/// Durasi sewa dalam hari: `return_date - pickup_date` (tanpa +1).
///
/// Contoh: ambil 1 Nov, kembali 3 Nov -> `2`.
/// Bila tanggal kembali sebelum tanggal ambil -> hasil negatif
/// (dianggap tidak valid oleh [isValidRentalRange]).
int calculateTotalDays(DateTime pickupDate, DateTime returnDate) =>
    _dateOnly(returnDate).difference(_dateOnly(pickupDate)).inDays;

/// Validasi range sewa sesuai aturan server:
/// - tanggal ambil tidak boleh sebelum hari ini ([today], default hari ini),
/// - `return_date` harus SETELAH `pickup_date` (minimal 1 malam).
///
/// Hanya mengecek aturan tanggal — stok dicek server lewat
/// `GET /equipments/{id}/availability`.
bool isValidRentalRange(
  DateTime pickupDate,
  DateTime returnDate, {
  DateTime? today,
}) {
  final now = _dateOnly(today ?? DateTime.now());
  final pickup = _dateOnly(pickupDate);
  final ret = _dateOnly(returnDate);
  if (pickup.isBefore(now)) return false; // tanggal lampau
  return ret.isAfter(pickup); // minimal 1 malam
}
