/// Pemetaan pesan server berbahasa Inggris yang UMUM ke Bahasa Indonesia.
///
/// Satu-satunya tempat pemetaan dilakukan (dipakai [ApiClient] saat
/// membangun [ApiException]). Pesan validasi spesifik dari server
/// (mis. "The email field is required.") dibiarkan apa adanya supaya
/// pengguna tetap melihat detail yang relevan.
String friendlyServerMessage(String raw, {int? statusCode}) {
  final message = raw.trim();
  if (message.isEmpty) return _fallback(statusCode);

  final key = _normalize(message);

  for (final entry in _genericMessages.entries) {
    if (key == entry.key) return entry.value;
  }

  // Pola umum yang tidak persis sama (mis. "Too many attempts. Please try
  // again in 60 seconds.").
  if (key.startsWith('too many attempts') ||
      key.startsWith('too many login attempts')) {
    return 'Terlalu banyak percobaan. Coba lagi nanti.';
  }
  if (key.startsWith('server error') ||
      key.startsWith('internal server error')) {
    return 'Server sedang bermasalah. Coba lagi nanti.';
  }

  return message;
}

/// Pesan baku berdasarkan kode status (fallback ketika server tidak
/// mengirim pesan yang bisa dipakai).
String fallbackMessageForStatus(int? statusCode) => _fallback(statusCode);

String _fallback(int? statusCode) {
  switch (statusCode) {
    case 400:
      return 'Permintaan tidak valid. Periksa data Anda.';
    case 401:
      return 'Sesi Anda telah berakhir. Silakan login kembali.';
    case 403:
      return 'Anda tidak memiliki akses untuk melakukan ini.';
    case 404:
      return 'Data tidak ditemukan.';
    case 409:
      return 'Data sudah ada atau konflik dengan data lain.';
    case 422:
      return 'Data yang dikirim tidak valid.';
    case 429:
      return 'Terlalu banyak percobaan. Coba lagi nanti.';
    case 500:
    case 502:
    case 503:
      return 'Server sedang bermasalah. Coba lagi nanti.';
    default:
      return 'Terjadi kesalahan. Coba lagi.';
  }
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'[.!]+$'), '')
    .trim();

const Map<String, String> _genericMessages = {
  'unauthenticated': 'Sesi Anda telah berakhir. Silakan login kembali.',
  'unauthenticated request': 'Sesi Anda telah berakhir. Silakan login kembali.',
  'unauthorized': 'Sesi Anda telah berakhir. Silakan login kembali.',
  'invalid token': 'Sesi Anda telah berakhir. Silakan login kembali.',
  'token expired': 'Sesi Anda telah berakhir. Silakan login kembali.',
  'forbidden': 'Anda tidak memiliki akses untuk melakukan ini.',
  'this action is unauthorized': 'Anda tidak memiliki akses untuk melakukan ini.',
  'you are not authorized to access this resource':
      'Anda tidak memiliki akses untuk melakukan ini.',
  'not found': 'Data tidak ditemukan.',
  'resource not found': 'Data tidak ditemukan.',
  'the requested resource was not found': 'Data tidak ditemukan.',
  'validation failed': 'Data yang dikirim tidak valid.',
  'the given data was invalid': 'Data yang dikirim tidak valid.',
  'invalid data': 'Data yang dikirim tidak valid.',
  'invalid credentials': 'Email atau password salah.',
  'invalid email or password': 'Email atau password salah.',
  'these credentials do not match our records.':
      'Email atau password salah.',
  'the provided credentials are incorrect': 'Email atau password salah.',
  'email or password is incorrect': 'Email atau password salah.',
  'the email has already been taken': 'Email sudah terdaftar.',
  'email already exists': 'Email sudah terdaftar.',
  'account is inactive': 'Akun Anda tidak aktif. Hubungi admin.',
  'your account has been deactivated':
      'Akun Anda tidak aktif. Hubungi admin.',
  'your account is inactive': 'Akun Anda tidak aktif. Hubungi admin.',
  'internal server error': 'Server sedang bermasalah. Coba lagi nanti.',
  'server error': 'Server sedang bermasalah. Coba lagi nanti.',
  'bad request': 'Permintaan tidak valid. Periksa data Anda.',
  'method not allowed': 'Aksi ini tidak didukung.',
  'request failed': 'Permintaan gagal. Coba lagi.',
  'something went wrong': 'Terjadi kesalahan. Coba lagi.',
  'network error': 'Tidak dapat terhubung ke server. Coba lagi.',
  'file too large': 'Ukuran file terlalu besar.',
  'invalid file type': 'Format file tidak didukung.',
  'the file must be an image': 'File harus berupa gambar.',
};
