import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_repository.dart';
import '../domain/equipment.dart';

/// Alat populer (`GET /equipments/popular?limit=6`) untuk Beranda.
///
/// Data publik (bukan per-user) — tidak perlu invalidasi sesi.
final popularEquipmentsProvider =
    AsyncNotifierProvider<PopularEquipmentsController, List<Equipment>>(
  PopularEquipmentsController.new,
);

class PopularEquipmentsController extends AsyncNotifier<List<Equipment>> {
  @override
  Future<List<Equipment>> build() =>
      ref.read(catalogRepositoryProvider).getPopular(limit: 6);
}
