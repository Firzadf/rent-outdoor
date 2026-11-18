import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_repository.dart';
import '../domain/equipment.dart';

/// Detail satu alat `GET /equipments/{id}` (publik).
///
/// Family per `equipmentId`, autoDispose: dibuang saat halaman detail
/// ditutup. BUKAN provider per-user, jadi tidak perlu didaftarkan di
/// pengamat sesi.
final equipmentDetailProvider = AsyncNotifierProvider.autoDispose
    .family<EquipmentDetailController, Equipment, int>(
  EquipmentDetailController.new,
);

class EquipmentDetailController extends AsyncNotifier<Equipment> {
  EquipmentDetailController(this.equipmentId);

  /// Argumen family (ID alat) lewat konsep Riverpod 3: constructor.
  final int equipmentId;

  @override
  Future<Equipment> build() =>
      ref.read(catalogRepositoryProvider).getDetail(equipmentId);
}
