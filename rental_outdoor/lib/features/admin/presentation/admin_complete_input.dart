/// Validasi isian form **Selesaikan Sewa** (`PUT /admin/bookings/{id}/complete`).
///
/// Fungsi murni tanpa UI supaya mudah diuji. Aturan server
/// (API_DOCS.md bagian 10):
/// - `return_condition` wajib `good` | `damaged` | `lost`,
/// - `damage_fee` wajib dan tidak negatif HANYA saat `damaged`
///   (selain itu server memaksa 0),
/// - `actual_return_date` format `YYYY-MM-DD` (default hari ini),
/// - `late_days` TIDAK pernah dihitung/dikirim dari client.
library;

/// Nilai `return_condition` yang diterima server.
const Set<String> returnConditions = {'good', 'damaged', 'lost'};

/// Label Indonesia untuk tiap kondisi kembali.
String returnConditionLabel(String condition) => switch (condition) {
      'good' => 'Baik',
      'damaged' => 'Rusak',
      'lost' => 'Hilang',
      _ => condition,
    };

/// Validasi seluruh isian form complete.
///
/// Mengembalikan `null` bila valid, atau pesan ramah (Bahasa Indonesia)
/// untuk ditampilkan di bawah isian terkait.
String? validateCompleteInput({
  required String returnCondition,
  required DateTime actualReturnDate,
  required DateTime pickupDate,
  String? damageFeeText,
  String? returnNotes,
}) {
  if (!returnConditions.contains(returnCondition)) {
    return 'Pilih kondisi alat saat kembali.';
  }

  // Perbandingan tanggal saja (tanpa jam) — picker menghasilkan tengah malam.
  final pickupDay = DateTime(pickupDate.year, pickupDate.month, pickupDate.day);
  final returnDay = DateTime(
    actualReturnDate.year,
    actualReturnDate.month,
    actualReturnDate.day,
  );
  if (returnDay.isBefore(pickupDay)) {
    return 'Tanggal kembali tidak boleh sebelum tanggal ambil.';
  }

  if (returnCondition == 'damaged') {
    final text = (damageFeeText ?? '').trim();
    if (text.isEmpty) {
      return 'Biaya kerusakan wajib diisi saat kondisi "Rusak".';
    }
    if (text.startsWith('-')) {
      return 'Biaya kerusakan tidak boleh negatif.';
    }
    if (parseDamageFee(text) == null) {
      return 'Biaya kerusakan harus angka, misalnya 150000.';
    }
  }

  final notes = (returnNotes ?? '').trim();
  if (notes.length > 1000) {
    return 'Catatan kondisi maksimal 1000 karakter.';
  }

  return null;
}

/// Baca nilai biaya kerusakan dari teks isian.
///
/// Menerima angka bulat/desimal titik (`150000`, `150000.50`);
/// `null` bila kosong atau bukan angka (termasuk nilai negatif,
/// supaya tidak pernah terkirim ke server).
double? parseDamageFee(String? text) {
  final value = (text ?? '').trim();
  if (value.isEmpty) return null;
  if (value.startsWith('-')) return null;
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) return null;
  return double.tryParse(value);
}
