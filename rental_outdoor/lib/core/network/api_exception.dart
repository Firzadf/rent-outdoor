/// Satu kelas error untuk semua kegagalan API (lihat API_DOCS.md).
///
/// - [statusCode] = kode HTTP asli (400, 401, 403, 404, 409, 422, 500, ...).
/// - [statusCode] `0` = bukan error server: timeout / tidak ada koneksi.
/// - [message] = pesan ramah untuk ditampilkan ke pengguna
///   (hasil `message` dari server bila ada, jika tidak pesan baku).
/// - [fieldErrors] = error per field (dari `data`/`errors` pada respons 422).
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.fieldErrors = const {},
  });

  /// Error jaringan (timeout / tidak ada koneksi / gagal total).
  factory ApiException.network(String message) =>
      ApiException(statusCode: 0, message: message);

  final int statusCode;
  final String message;
  final Map<String, List<String>> fieldErrors;

  bool get isNetworkError => statusCode == 0;

  /// Ambil pesan error pertama untuk field tertentu, mis. `email`.
  String? fieldError(String field) {
    final errors = fieldErrors[field];
    if (errors == null || errors.isEmpty) return null;
    return errors.first;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
