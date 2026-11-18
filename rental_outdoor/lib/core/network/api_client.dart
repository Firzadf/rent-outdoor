import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'server_message.dart';

/// Klien HTTP (dio) + interceptor Authorization + pemetaan SEMUA error
/// ke [ApiException].
///
/// Alur pakai:
/// ```dart
/// final data = await api.postData('/auth/login', data: {...}); // payload `data`
/// ```
/// Semua metode melempar [ApiException] bila gagal (termasuk timeout
/// dan tidak ada koneksi) sehingga UI cukup `on ApiException`.
class ApiClient {
  ApiClient({required this.tokenStorage, Dio? client}) {
    dio = client ??
        Dio(
          BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            connectTimeout: AppConstants.connectTimeout,
            receiveTimeout: AppConstants.receiveTimeout,
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
          ),
        );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Token dibaca di SETIAP request (bukan disalin sekali ke
          // BaseOptions.headers / instance dio) sehingga selalu terbaru.
          final token = await tokenStorage.read();

          // Hapus dulu: header per-request tidak boleh mewarisi nilai lama.
          options.headers.remove('Authorization');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
      ),
    );
  }

  final TokenStorage tokenStorage;
  late final Dio dio;

  final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast();

  /// Dipancarkan saat server menjawab 401 (token kedaluwarsa/tidak valid)
  /// supaya sesi bisa diakhiri.
  Stream<void> get unauthorized => _unauthorizedController.stream;

  /// Endpoint yang membalas 401 TETAPI bukan berarti sesi habis
  /// (401 = input user salah, mis. password lama salah di
  /// `PUT /user/change-password`).
  static const Set<String> _nonSessionPaths = {'/user/change-password'};

  // ---------------------------------------------------------------------
  // Request helpers: mengembalikan isi `data` dari envelope
  // { success, message, data }
  // ---------------------------------------------------------------------

  Future<dynamic> getData(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _unwrap(
        () => dio.get<dynamic>(path, queryParameters: queryParameters),
      );

  Future<dynamic> postData(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _unwrap(
        () => dio.post<dynamic>(path, data: data, queryParameters: queryParameters),
      );

  Future<dynamic> putData(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _unwrap(
        () => dio.put<dynamic>(path, data: data, queryParameters: queryParameters),
      );

  Future<dynamic> deleteData(String path) =>
      _unwrap(() => dio.delete<dynamic>(path));

  /// POST multipart (upload gambar).
  Future<dynamic> upload(String path, FormData formData) =>
      _unwrap(() => dio.post<dynamic>(path, data: formData));

  Future<dynamic> _unwrap(
    Future<Response<dynamic>> Function() run,
  ) async {
    final response = await execute(run);
    final body = response.data;
    if (body is Map<String, dynamic>) return body['data'];
    return body; // array (mis. /categories) atau null
  }

  // ---------------------------------------------------------------------
  // Eksekusi + pemetaan error
  // ---------------------------------------------------------------------

  Future<T> execute<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw mapException(e);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException.network(noConnectionMessage);
    } on TimeoutException {
      throw ApiException.network(timeoutMessage);
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Terjadi kesalahan tak terduga. Coba lagi.',
      );
    }
  }

  static const String noConnectionMessage =
      'Tidak ada koneksi ke server. Pastikan perangkat terhubung ke internet.';
  static const String timeoutMessage =
      'Koneksi ke server terlalu lama. Coba lagi.';

  /// Ubah [DioException] menjadi [ApiException] (ramah ke pengguna).
  ApiException mapException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException.network(timeoutMessage);
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        if (e.error is SocketException ||
            e.error is HandshakeException ||
            e.error is HttpException ||
            e.response == null) {
          return ApiException.network(noConnectionMessage);
        }
        return _fromResponse(e.response);
      case DioExceptionType.badCertificate:
        return ApiException.network(
          'Koneksi ke server tidak aman. Periksa konfigurasi server.',
        );
      case DioExceptionType.cancel:
        return ApiException(statusCode: 0, message: 'Permintaan dibatalkan.');
      case DioExceptionType.badResponse:
        return _fromResponse(e.response);
    }
  }

  ApiException _fromResponse(Response<dynamic>? response) {
    final statusCode = response?.statusCode ?? 0;
    var message = fallbackMessageForStatus(statusCode);
    var fieldErrors = const <String, List<String>>{};

    final body = response?.data;
    if (body is Map<String, dynamic>) {
      final serverMessage = body['message'];
      if (serverMessage is String && serverMessage.trim().isNotEmpty) {
        message = friendlyServerMessage(
          serverMessage,
          statusCode: statusCode,
        );
      }
      final extracted = _extractFieldErrors(body);
      if (extracted.isNotEmpty) fieldErrors = extracted;
    }

    if (statusCode == 401 && _isSessionPath(response?.requestOptions.path)) {
      unawaited(_handleUnauthorized());
    }

    return ApiException(
      statusCode: statusCode,
      message: message,
      fieldErrors: fieldErrors,
    );
  }

  bool _isSessionPath(String? path) {
    if (path == null) return true;
    final normalized = path.split('?').first;
    return !_nonSessionPaths.contains(normalized);
  }

  Future<void> _handleUnauthorized() async {
    await tokenStorage.delete();
    if (!_unauthorizedController.isClosed) {
      _unauthorizedController.add(null);
    }
  }

  /// Error validasi 422 punya bentuk:
  /// `data: { "field": ["pesan", ...] }` (kadang lewat key `errors`).
  Map<String, List<String>> _extractFieldErrors(Map<String, dynamic> body) {
    for (final key in const ['data', 'errors']) {
      final value = body[key];
      if (value is Map) {
        final errors = <String, List<String>>{};
        value.forEach((field, messages) {
          if (messages is List) {
            errors[field.toString()] =
                messages.map((e) => e.toString()).toList();
          } else if (messages is String) {
            errors[field.toString()] = [messages];
          }
        });
        if (errors.isNotEmpty) return errors;
      }
    }
    return const {};
  }

  void dispose() {
    unawaited(_unauthorizedController.close());
    dio.close(force: true);
  }
}
