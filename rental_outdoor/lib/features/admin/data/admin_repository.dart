import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_upload.dart';
import '../../../core/utils/image_url.dart';
import '../../catalog/domain/category.dart';
import '../../catalog/domain/equipment.dart';
import '../../catalog/domain/equipment_image.dart';
import '../domain/admin_booking.dart';
import '../domain/admin_dashboard.dart';
import '../domain/admin_report.dart';
import '../domain/admin_user.dart';

/// Semua fitur admin dari Supabase.
///
/// Perhitungan dihitung di client dari hasil query (data masih
/// kecil), dengan rumus yang sama seperti controller PHP lama:
/// - Dashboard: `total_orders` = jumlah booking; `total_revenue` =
///   SUM(subtotal + late_fee + damage_fee) untuk completed;
///   `pending_verification_count`; `active_rentals_count` =
///   confirmed + in_use; `top_equipments` 5 teratas dari
///   booking_items, status booking bukan cancelled/rejected.
/// - Verifikasi: approve = payment approved + booking confirmed;
///   reject = payment rejected + alasan, booking tetap
///   pending_verification kecuali sudah lewat auto_cancel_at.
/// - Mulai sewa: confirmed -> in_use, `total_bookings` alat
///   bertambah sesuai quantity.
/// - Selesaikan: `late_fee = SUM(quantity * price_per_day * 0,5 *
///   late_days)`; `deposit_refund`: good = max(0, deposit_total -
///   late_fee), damaged = max(0, deposit_total - damage_fee -
///   late_fee), lost = 0.
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseServiceProvider)),
);

class AdminRepository {
  AdminRepository(this._sb);

  final SupabaseService _sb;

  // -------------------------------------------------------------------
  // Dashboard
  // -------------------------------------------------------------------

  Future<AdminDashboard> getDashboard() async {
    final bookings = await _allBookings();
    final totalOrders = bookings.length;
    double totalRevenue = 0;
    var pendingVerification = 0;
    var activeRentals = 0;
    for (final booking in bookings) {
      final status = booking['status'] as String? ?? '';
      if (status == 'completed') {
        totalRevenue += (booking['subtotal'] as num? ?? 0).toDouble();
        totalRevenue += (booking['late_fee'] as num? ?? 0).toDouble();
        totalRevenue += (booking['damage_fee'] as num? ?? 0).toDouble();
      }
      if (status == 'pending_verification') pendingVerification++;
      if (status == 'confirmed' || status == 'in_use') activeRentals++;
    }
    final top = await _topEquipments(bookings);
    return AdminDashboard.fromJson({
      'total_orders': totalOrders,
      'total_revenue': totalRevenue,
      'pending_verification_count': pendingVerification,
      'active_rentals_count': activeRentals,
      'top_equipments': top,
    });
  }

  // -------------------------------------------------------------------
  // Pesanan
  // -------------------------------------------------------------------

  Future<AdminBookingsPage> getBookings({
    String? status,
    String? search,
    int page = 1,
    int limit = 10,
  }) async {
    var bookings = await _allBookings();
    if (status != null && status.isNotEmpty) {
      bookings =
          bookings.where((b) => b['status'] == status).toList();
    }
    final users = await _usersById();
    final query = search?.trim().toLowerCase() ?? '';
    if (query.isNotEmpty) {
      bookings = bookings.where((b) {
        final code = (b['booking_code'] as String? ?? '').toLowerCase();
        final user = users[(b['user_id'] as num? ?? 0).toInt()];
        final name = (user?['name'] as String? ?? '').toLowerCase();
        final email = (user?['email'] as String? ?? '').toLowerCase();
        return code.contains(query) ||
            name.contains(query) ||
            email.contains(query);
      }).toList();
    }
    final itemCounts = await _itemCounts();
    final enriched = bookings.map((b) {
      final map = _adminBookingBase(b, users);
      map['item_count'] = itemCounts[(b['id'] as num? ?? 0).toInt()] ?? 0;
      return map;
    }).toList();
    final total = enriched.length;
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 10 : limit;
    final start = (safePage - 1) * safeLimit;
    final pageItems = start >= total
        ? <Map<String, dynamic>>[]
        : enriched.sublist(start, (start + safeLimit).clamp(0, total));
    return AdminBookingsPage.fromJson({
      'bookings': pageItems,
      'pagination': {
        'total': total,
        'page': safePage,
        'limit': safeLimit,
        'total_pages': total == 0 ? 0 : (total / safeLimit).ceil(),
      },
    });
  }

  Future<AdminBooking> getBooking(int id) async {
    final booking = await _sb.guard(
      () => _sb.client.from('bookings').select().eq('id', id).maybeSingle(),
    );
    if (booking == null) {
      throw ApiException(statusCode: 404, message: 'Pesanan tidak ditemukan.');
    }
    final users = await _usersById();
    final map = _adminBookingBase(booking, users);
    map['items'] = await _bookingItems(id);
    map['payments'] = await _bookingPayments(id);
    return AdminBooking.fromJson(map);
  }

  Future<void> verifyBooking(
    int id, {
    required String action,
    String? rejectionReason,
  }) async {
    final adminId = await _sb.requireAppUserId();
    final booking = await _sb.guard(
      () => _sb.client.from('bookings').select().eq('id', id).maybeSingle(),
    );
    if (booking == null) {
      throw ApiException(statusCode: 404, message: 'Pesanan tidak ditemukan.');
    }
    if (booking['status'] != 'pending_verification') {
      throw ApiException(
        statusCode: 400,
        message: 'Hanya pesanan Menunggu Verifikasi yang bisa diverifikasi.',
      );
    }
    final payment = await _lastPayment(id);
    if (payment == null || payment['status'] != 'pending') {
      throw ApiException(
        statusCode: 400,
        message: 'Tidak ada pembayaran yang menunggu verifikasi.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    if (action == 'approve') {
      await _sb.guard(
        () => _sb.client.from('payments').update({
          'status': 'approved',
          'verified_at': now,
          'verified_by': adminId,
        }).eq('id', payment['id']),
      );
      await _sb.guard(
        () => _sb.client
            .from('bookings')
            .update({'status': 'confirmed'})
            .eq('id', id),
      );
    } else if (action == 'reject') {
      if (rejectionReason == null || rejectionReason.trim().isEmpty) {
        throw ApiException(
          statusCode: 400,
          message: 'Alasan penolakan wajib diisi.',
        );
      }
      await _sb.guard(
        () => _sb.client.from('payments').update({
          'status': 'rejected',
          'rejection_reason': rejectionReason.trim(),
          'verified_at': now,
          'verified_by': adminId,
        }).eq('id', payment['id']),
      );
      final autoCancelAt = booking['auto_cancel_at'] as String?;
      final deadline =
          autoCancelAt == null ? null : DateTime.tryParse(autoCancelAt);
      if (deadline != null && !DateTime.now().isBefore(deadline)) {
        await _sb.guard(
          () => _sb.client.from('bookings').update({
            'status': 'cancelled',
            'cancellation_reason':
                'Auto-cancel: pembayaran melewati batas waktu',
          }).eq('id', id),
        );
      }
    } else {
      throw ApiException(
        statusCode: 400,
        message: "Aksi tidak dikenal: '$action'. Gunakan approve atau reject.",
      );
    }
  }

  Future<void> startBooking(int id) async {
    final booking = await _sb.guard(
      () => _sb.client.from('bookings').select().eq('id', id).maybeSingle(),
    );
    if (booking == null) {
      throw ApiException(statusCode: 404, message: 'Pesanan tidak ditemukan.');
    }
    if (booking['status'] != 'confirmed') {
      throw ApiException(
        statusCode: 400,
        message: 'Hanya pesanan Terkonfirmasi yang bisa dimulai.',
      );
    }
    await _sb.guard(
      () => _sb.client
          .from('bookings')
          .update({'status': 'in_use'})
          .eq('id', id),
    );
    final items = await _sb.guard(
      () => _sb.client
          .from('booking_items')
          .select('equipment_id, quantity')
          .eq('booking_id', id),
    );
    for (final item in _rows(items)) {
      final equipmentId = (item['equipment_id'] as num? ?? 0).toInt();
      final quantity = (item['quantity'] as num? ?? 0).toInt();
      final equipment = await _sb.guard(
        () => _sb.client
            .from('equipments')
            .select('total_bookings')
            .eq('id', equipmentId)
            .maybeSingle(),
      );
      final current = (equipment?['total_bookings'] as num? ?? 0).toInt();
      await _sb.guard(
        () => _sb.client
            .from('equipments')
            .update({'total_bookings': current + quantity})
            .eq('id', equipmentId),
      );
    }
  }

  Future<BookingCompleteResult> completeBooking({
    required int id,
    required String returnCondition,
    String? returnNotes,
    double? damageFee,
    required DateTime actualReturnDate,
  }) async {
    final booking = await _sb.guard(
      () => _sb.client.from('bookings').select().eq('id', id).maybeSingle(),
    );
    if (booking == null) {
      throw ApiException(statusCode: 404, message: 'Pesanan tidak ditemukan.');
    }
    if (booking['status'] != 'in_use') {
      throw ApiException(
        statusCode: 400,
        message: 'Hanya pesanan Sedang Disewa yang bisa diselesaikan.',
      );
    }
    if (returnCondition != 'good' &&
        returnCondition != 'damaged' &&
        returnCondition != 'lost') {
      throw ApiException(
        statusCode: 400,
        message: "Kondisi kembali tidak dikenal: '$returnCondition'.",
      );
    }
    final damage = damageFee ?? 0;
    if (returnCondition == 'damaged' && damage <= 0) {
      throw ApiException(
        statusCode: 400,
        message: 'Biaya kerusakan wajib diisi untuk kondisi rusak.',
      );
    }
    final returnDateStr = booking['return_date'] as String? ?? '';
    final returnDate = DateTime.tryParse(returnDateStr);
    final actualDay = DateTime(
      actualReturnDate.year,
      actualReturnDate.month,
      actualReturnDate.day,
    );
    var lateDays = 0;
    if (returnDate != null) {
      final dueDay =
          DateTime(returnDate.year, returnDate.month, returnDate.day);
      final diff = actualDay.difference(dueDay).inDays;
      lateDays = diff > 0 ? diff : 0;
    }
    final items = await _sb.guard(
      () => _sb.client
          .from('booking_items')
          .select('equipment_id, quantity, price_per_day')
          .eq('booking_id', id),
    );
    double lateFee = 0;
    for (final item in _rows(items)) {
      final quantity = (item['quantity'] as num? ?? 0).toDouble();
      final price = (item['price_per_day'] as num? ?? 0).toDouble();
      lateFee += quantity * price * 0.5 * lateDays;
    }
    final depositTotal = (booking['deposit_total'] as num? ?? 0).toDouble();
    double depositRefund;
    switch (returnCondition) {
      case 'damaged':
        depositRefund = depositTotal - damage - lateFee;
        if (depositRefund < 0) depositRefund = 0;
      case 'lost':
        depositRefund = 0;
      case 'good':
      default:
        depositRefund = depositTotal - lateFee;
        if (depositRefund < 0) depositRefund = 0;
    }
    final updated = await _sb.guard(
      () => _sb.client
          .from('bookings')
          .update({
            'status': 'completed',
            'actual_return_date': formatIsoDate(actualReturnDate),
            'return_condition': returnCondition,
            'return_notes': returnNotes?.trim().isEmpty == true
                ? null
                : returnNotes!.trim(),
            'late_days': lateDays,
            'late_fee': lateFee,
            'damage_fee': returnCondition == 'damaged' ? damage : 0,
            'deposit_refund': depositRefund,
          })
          .eq('id', id)
          .select()
          .single(),
    );
    final users = await _usersById();
    final map = _adminBookingBase(updated, users);
    map['items'] = await _bookingItems(id);
    map['payments'] = await _bookingPayments(id);
    return BookingCompleteResult.fromJson({
      'booking': map,
      'late_days': lateDays,
      'late_fee': lateFee,
      'damage_fee': returnCondition == 'damaged' ? damage : 0,
      'deposit_refund': depositRefund,
    });
  }

  // -------------------------------------------------------------------
  // Kategori (CRUD admin)
  // -------------------------------------------------------------------

  Future<Category> createCategory({
    required String name,
    String? description,
    String? icon,
  }) async {
    final row = await _sb.guard(
      () => _sb.client
          .from('categories')
          .insert({
            'name': name.trim(),
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
            if (icon != null && icon.trim().isNotEmpty) 'icon': icon.trim(),
          })
          .select()
          .single(),
    );
    return Category.fromJson(row);
  }

  Future<Category> updateCategory(
    int id, {
    required String name,
    String? description,
    String? icon,
  }) async {
    final row = await _sb.guard(
      () => _sb.client
          .from('categories')
          .update({
            'name': name.trim(),
            if (description != null) 'description': description.trim(),
            if (icon != null) 'icon': icon.trim(),
          })
          .eq('id', id)
          .select()
          .single(),
    );
    return Category.fromJson(row);
  }

  /// Hapus kategori. 409 bila masih dipakai alat.
  Future<void> deleteCategory(int id) async {
    final used = await _sb.guard(
      () => _sb.client
          .from('equipments')
          .select('id')
          .eq('category_id', id)
          .limit(1),
    );
    if (_rows(used).isNotEmpty) {
      throw ApiException(
        statusCode: 409,
        message: 'Kategori masih dipakai oleh alat. Hapus atau pindahkan alatnya dulu.',
      );
    }
    await _sb.guard(() => _sb.client.from('categories').delete().eq('id', id));
  }

  // -------------------------------------------------------------------
  // Alat (CRUD admin)
  // -------------------------------------------------------------------

  Future<Equipment> createEquipment({
    required int categoryId,
    required String name,
    required double pricePerDay,
    required int stock,
    double? deposit,
    String? description,
    bool? isActive,
  }) async {
    final row = await _sb.guard(
      () => _sb.client
          .from('equipments')
          .insert({
            'category_id': categoryId,
            'name': name.trim(),
            'price_per_day': pricePerDay,
            'stock': stock,
            if (deposit != null) 'deposit': deposit,
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
            'is_active': isActive ?? true,
            'total_bookings': 0,
            'rating_avg': 0,
            'rating_count': 0,
          })
          .select()
          .single(),
    );
    final map = Map<String, dynamic>.from(row);
    map['category_name'] = await _categoryName(categoryId);
    return Equipment.fromJson(map);
  }

  Future<Equipment> updateEquipment(
    int id, {
    required int categoryId,
    required String name,
    required double pricePerDay,
    required int stock,
    double? deposit,
    String? description,
    bool? isActive,
  }) async {
    final row = await _sb.guard(
      () => _sb.client
          .from('equipments')
          .update({
            'category_id': categoryId,
            'name': name.trim(),
            'price_per_day': pricePerDay,
            'stock': stock,
            if (deposit != null) 'deposit': deposit,
            if (description != null) 'description': description.trim(),
            if (isActive != null) 'is_active': isActive,
          })
          .eq('id', id)
          .select()
          .single(),
    );
    final map = Map<String, dynamic>.from(row);
    map['category_name'] = await _categoryName(categoryId);
    return Equipment.fromJson(map);
  }

  /// Hapus alat = soft delete (`is_active = false`), seperti PHP lama.
  Future<void> deleteEquipment(int id) async {
    await _sb.guard(
      () => _sb.client
          .from('equipments')
          .update({'is_active': false})
          .eq('id', id),
    );
  }

  // -------------------------------------------------------------------
  // Gambar alat
  // -------------------------------------------------------------------

  /// Unggah gambar ke bucket `equipment-images` dan simpan baris
  /// `equipment_images`. Gambar pertama jadi utama bila belum ada
  /// gambar sama sekali. Path di database memakai bentuk lama
  /// `uploads/equipments/<file>` supaya `resolveImageUrl` memetakan
  /// ke URL storage.
  Future<List<EquipmentImage>> uploadEquipmentImages(
    int equipmentId,
    List<XFile> files,
  ) async {
    final existing = await _sb.guard(
      () => _sb.client
          .from('equipment_images')
          .select('id')
          .eq('equipment_id', equipmentId),
    );
    var sortOrder = _rows(existing).length;
    final uploaded = <EquipmentImage>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final bytes = await file.readAsBytes();
      final mime = detectMimeFromBytes(bytes) ?? 'image/jpeg';
      final extension = extensionFromMime(mime);
      final fileName =
          '${equipmentId}_${DateTime.now().millisecondsSinceEpoch}_$i.$extension';
      await _sb.uploadBytes(
        bucket: 'equipment-images',
        path: fileName,
        bytes: bytes,
        contentType: mime,
      );
      final row = await _sb.guard(
        () => _sb.client
            .from('equipment_images')
            .insert({
              'equipment_id': equipmentId,
              'image_url': 'uploads/equipments/$fileName',
              'is_primary': sortOrder == 0 && i == 0,
              'sort_order': sortOrder,
            })
            .select()
            .single(),
      );
      sortOrder++;
      final map = Map<String, dynamic>.from(row);
      map['image_url'] = resolveImageUrl(map['image_url'] as String?);
      uploaded.add(EquipmentImage.fromJson(map));
    }
    return uploaded;
  }

  /// Hapus gambar: baris dihapus, file di storage dihapus
  /// (kegagalan hapus file diabaikan).
  Future<void> deleteEquipmentImage(int imageId) async {
    final row = await _sb.guard(
      () => _sb.client
          .from('equipment_images')
          .select('image_url')
          .eq('id', imageId)
          .maybeSingle(),
    );
    await _sb.guard(
      () => _sb.client.from('equipment_images').delete().eq('id', imageId),
    );
    final imageUrl = row?['image_url'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      await _sb.removeFromStorage('equipment-images', imageUrl);
    }
  }

  // -------------------------------------------------------------------
  // Pengguna
  // -------------------------------------------------------------------

  Future<AdminUsersPage> getUsers({
    String? role,
    String? search,
    int page = 1,
    int limit = 10,
  }) async {
    final rows = await _sb.guard(
      () => _sb.client.from('users').select().order('created_at', ascending: false).limit(100),
    );
    var users = _rows(rows);
    if (role != null && role.isNotEmpty) {
      users = users.where((u) => u['role'] == role).toList();
    }
    final query = search?.trim().toLowerCase() ?? '';
    if (query.isNotEmpty) {
      users = users.where((u) {
        final name = (u['name'] as String? ?? '').toLowerCase();
        final email = (u['email'] as String? ?? '').toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }
    final total = users.length;
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 10 : limit;
    final start = (safePage - 1) * safeLimit;
    final pageItems = start >= total
        ? <Map<String, dynamic>>[]
        : users.sublist(start, (start + safeLimit).clamp(0, total));
    return AdminUsersPage.fromJson({
      'users': pageItems,
      'pagination': {
        'total': total,
        'page': safePage,
        'limit': safeLimit,
        'total_pages': total == 0 ? 0 : (total / safeLimit).ceil(),
      },
    });
  }

  Future<AdminUser> toggleUserActive(int userId) async {
    final row = await _sb.guard(
      () => _sb.client.from('users').select().eq('id', userId).maybeSingle(),
    );
    if (row == null) {
      throw ApiException(statusCode: 404, message: 'Pengguna tidak ditemukan.');
    }
    final current = row['is_active'] == true;
    final updated = await _sb.guard(
      () => _sb.client
          .from('users')
          .update({'is_active': !current})
          .eq('id', userId)
          .select()
          .single(),
    );
    return AdminUser.fromJson(updated);
  }

  // -------------------------------------------------------------------
  // Laporan
  // -------------------------------------------------------------------

  Future<RevenueReport> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
    String period = 'daily',
  }) async {
    final start = formatIsoDate(startDate);
    final end = formatIsoDate(endDate);
    final bookings = await _allBookings();
    final inRange = bookings.where((b) {
      final created = (b['created_at'] as String? ?? '');
      final day = created.length >= 10 ? created.substring(0, 10) : created;
      return day.compareTo(start) >= 0 && day.compareTo(end) <= 0;
    }).toList();
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final booking in inRange) {
      final created = (booking['created_at'] as String? ?? '');
      final day = created.length >= 10 ? created.substring(0, 10) : created;
      final key = period == 'monthly' && day.length >= 7
          ? day.substring(0, 7)
          : day;
      (grouped[key] ??= []).add(booking);
    }
    final rows = grouped.keys.toList()..sort();
    return RevenueReport.fromJson({
      'start_date': start,
      'end_date': end,
      'period': period,
      'rows': rows.map((key) {
        final group = grouped[key]!;
        var revenue = 0.0;
        var pending = 0;
        for (final booking in group) {
          final status = booking['status'] as String? ?? '';
          if (status == 'completed') {
            revenue += (booking['subtotal'] as num? ?? 0).toDouble();
            revenue += (booking['late_fee'] as num? ?? 0).toDouble();
            revenue += (booking['damage_fee'] as num? ?? 0).toDouble();
          }
          if (status == 'pending_payment' ||
              status == 'pending_verification') {
            pending++;
          }
        }
        return {
          'period': key,
          'orders': group.length,
          'pending_orders': pending,
          'revenue': revenue,
        };
      }).toList(),
    });
  }

  Future<EquipmentReport> getEquipmentReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = formatIsoDate(startDate);
    final end = formatIsoDate(endDate);
    final bookings = await _allBookings();
    final inRange = <int, Map<String, dynamic>>{};
    for (final booking in bookings) {
      final created = (booking['created_at'] as String? ?? '');
      final day = created.length >= 10 ? created.substring(0, 10) : created;
      if (day.compareTo(start) >= 0 && day.compareTo(end) <= 0) {
        inRange[(booking['id'] as num).toInt()] = booking;
      }
    }
    final items = await _sb.guard(
      () => _sb.client.from('booking_items').select().limit(1000),
    );
    final grouped = <int, _EquipmentReportRow>{};
    for (final item in _rows(items)) {
      final bookingId = (item['booking_id'] as num? ?? 0).toInt();
      final booking = inRange[bookingId];
      if (booking == null) continue;
      final equipmentId = (item['equipment_id'] as num? ?? 0).toInt();
      final row = grouped.putIfAbsent(
        equipmentId,
        () => _EquipmentReportRow(equipmentId: equipmentId),
      );
      row.bookingIds.add(bookingId);
      row.totalQuantity += (item['quantity'] as num? ?? 0).toInt();
      if (booking['status'] == 'completed') {
        row.revenue += (item['subtotal'] as num? ?? 0).toDouble();
      }
    }
    final equipments = await _sb.guard(
      () => _sb.client.from('equipments').select('id, name, category_id'),
    );
    final equipmentMap = <int, Map<String, dynamic>>{};
    for (final equipment in _rows(equipments)) {
      equipmentMap[(equipment['id'] as num).toInt()] = equipment;
    }
    final rows = grouped.values.toList()
      ..sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
    final reportRows = <Map<String, dynamic>>[];
    for (final row in rows) {
      final equipment = equipmentMap[row.equipmentId];
      reportRows.add({
        'id': row.equipmentId,
        'name': equipment?['name'] as String? ?? '',
        'category_name': equipment == null
            ? null
            : await _categoryName(
                (equipment['category_id'] as num? ?? 0).toInt(),
              ),
        'bookings_count': row.bookingIds.length,
        'total_quantity': row.totalQuantity,
        'revenue': row.revenue,
      });
    }
    return EquipmentReport.fromJson({'rows': reportRows});
  }

  // -------------------------------------------------------------------
  // Helper
  // -------------------------------------------------------------------

  List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> _allBookings() async {
    final rows = await _sb.guard(
      () => _sb.client
          .from('bookings')
          .select()
          .order('created_at', ascending: false)
          .limit(100),
    );
    return _rows(rows);
  }

  Future<Map<int, Map<String, dynamic>>> _usersById() async {
    final rows = await _sb.guard(
      () => _sb.client.from('users').select('id, name, email, phone, address'),
    );
    final map = <int, Map<String, dynamic>>{};
    for (final row in _rows(rows)) {
      final id = row['id'];
      if (id is num) map[id.toInt()] = row;
    }
    return map;
  }

  Future<String?> _categoryName(int categoryId) async {
    final row = await _sb.guard(
      () => _sb.client
          .from('categories')
          .select('name')
          .eq('id', categoryId)
          .maybeSingle(),
    );
    return row?['name'] as String?;
  }

  Future<Map<int, int>> _itemCounts() async {
    final items = await _sb.guard(
      () => _sb.client.from('booking_items').select('booking_id, quantity'),
    );
    final map = <int, int>{};
    for (final item in _rows(items)) {
      final bookingId = (item['booking_id'] as num? ?? 0).toInt();
      map[bookingId] =
          (map[bookingId] ?? 0) + (item['quantity'] as num? ?? 0).toInt();
    }
    return map;
  }

  Map<String, dynamic> _adminBookingBase(
    Map<String, dynamic> booking,
    Map<int, Map<String, dynamic>> users,
  ) {
    final map = Map<String, dynamic>.from(booking);
    final user = users[(booking['user_id'] as num? ?? 0).toInt()];
    map['user_name'] = user?['name'] as String?;
    map['user_email'] = user?['email'] as String?;
    map['user_phone'] = user?['phone'] as String?;
    map['user_address'] = user?['address'] as String?;
    return map;
  }

  Future<List<Map<String, dynamic>>> _bookingItems(int bookingId) async {
    final items = await _sb.guard(
      () => _sb.client
          .from('booking_items')
          .select()
          .eq('booking_id', bookingId),
    );
    final enriched = <Map<String, dynamic>>[];
    for (final item in _rows(items)) {
      final map = Map<String, dynamic>.from(item);
      final equipment = await _sb.guard(
        () => _sb.client
            .from('equipments')
            .select('name')
            .eq('id', item['equipment_id'])
            .maybeSingle(),
      );
      map['equipment_name'] = equipment?['name'] as String?;
      final primary = await _sb.guard(
        () => _sb.client
            .from('equipment_images')
            .select('image_url')
            .eq('equipment_id', item['equipment_id'])
            .eq('is_primary', true)
            .order('sort_order')
            .limit(1)
            .maybeSingle(),
      );
      final imageUrl = primary?['image_url'] as String?;
      map['primary_image_url'] =
          imageUrl == null ? null : resolveImageUrl(imageUrl);
      enriched.add(map);
    }
    return enriched;
  }

  Future<List<Map<String, dynamic>>> _bookingPayments(int bookingId) async {
    final payments = await _sb.guard(
      () => _sb.client
          .from('payments')
          .select()
          .eq('booking_id', bookingId)
          .order('created_at', ascending: false),
    );
    return _rows(payments).map((payment) {
      final map = Map<String, dynamic>.from(payment);
      final proof = map['payment_proof'] as String?;
      if (proof != null && proof.isNotEmpty) {
        map['payment_proof'] = resolveImageUrl(proof);
      }
      return map;
    }).toList();
  }

  Future<Map<String, dynamic>?> _lastPayment(int bookingId) async {
    final rows = await _sb.guard(
      () => _sb.client
          .from('payments')
          .select()
          .eq('booking_id', bookingId)
          .order('id', ascending: false)
          .limit(1),
    );
    final list = _rows(rows);
    return list.isEmpty ? null : list.first;
  }

  Future<List<Map<String, dynamic>>> _topEquipments(
    List<Map<String, dynamic>> bookings,
  ) async {
    final byId = <int, Map<String, dynamic>>{};
    for (final booking in bookings) {
      byId[(booking['id'] as num).toInt()] = booking;
    }
    final items = await _sb.guard(
      () => _sb.client.from('booking_items').select().limit(1000),
    );
    final totals = <int, int>{};
    for (final item in _rows(items)) {
      final bookingId = (item['booking_id'] as num? ?? 0).toInt();
      final booking = byId[bookingId];
      if (booking == null) continue;
      final status = booking['status'] as String? ?? '';
      if (status == 'cancelled' || status == 'rejected') continue;
      final equipmentId = (item['equipment_id'] as num? ?? 0).toInt();
      totals[equipmentId] =
          (totals[equipmentId] ?? 0) + (item['quantity'] as num? ?? 0).toInt();
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final result = <Map<String, dynamic>>[];
    for (final entry in top) {
      final equipment = await _sb.guard(
        () => _sb.client
            .from('equipments')
            .select('id, name, category_id')
            .eq('id', entry.key)
            .maybeSingle(),
      );
      if (equipment == null) continue;
      result.add({
        'id': entry.key,
        'name': equipment['name'] as String?,
        'total_rentals': entry.value,
        'category_name': await _categoryName(
          (equipment['category_id'] as num? ?? 0).toInt(),
        ),
      });
    }
    return result;
  }
}

class _EquipmentReportRow {
  _EquipmentReportRow({required this.equipmentId});

  final int equipmentId;
  final Set<int> bookingIds = {};
  var totalQuantity = 0;
  var revenue = 0.0;
}
