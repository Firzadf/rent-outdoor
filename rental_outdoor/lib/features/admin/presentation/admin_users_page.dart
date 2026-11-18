import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/admin_repository.dart';
import '../domain/admin_user.dart';
import '../../../core/widgets/depth.dart';

/// Halaman kelola pengguna admin.
///
/// GET /admin/users (filter role, pencarian, paginasi).
/// PUT /admin/users/{id}/toggle-active dengan dialog konfirmasi.
/// Tombol toggle-active disembunyikan untuk akun admin yang sedang login.
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  String? _roleFilter;
  String _search = '';
  int _currentPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<AdminUser> _users = [];
  int _totalPages = 0;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 200 &&
        !_loadingMore &&
        _currentPage < _totalPages) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 1;
    });

    try {
      final result = await ref.read(adminRepositoryProvider).getUsers(
            role: _roleFilter,
            search: _search,
            page: 1,
          );
      if (!mounted) return;
      setState(() {
        _users = result.items;
        _totalPages = result.pagination.totalPages;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data pengguna. Coba lagi.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _currentPage >= _totalPages) return;

    setState(() => _loadingMore = true);
    try {
      final result = await ref.read(adminRepositoryProvider).getUsers(
            role: _roleFilter,
            search: _search,
            page: _currentPage + 1,
          );
      if (!mounted) return;
      setState(() {
        _users.addAll(result.items);
        _currentPage = result.pagination.page;
        _totalPages = result.pagination.totalPages;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search = value.trim();
      _loadData();
    });
  }

  Future<void> _toggleActive(AdminUser user) async {
    if (_toggling) return;
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == user.id) return;

    final action = user.isActive ? 'Nonaktifkan' : 'Aktifkan';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$action Pengguna?'),
        content: Text(
          '${user.name} (${user.email}) akan di${action.toLowerCase()}.\n'
          '${user.isActive ? "Pengguna tidak akan bisa login." : "Pengguna bisa login kembali."}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: user.isActive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _toggling = true);
    try {
      final updated =
          await ref.read(adminRepositoryProvider).toggleUserActive(user.id);
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          _users[index] = updated;
        }
      });
      _showMessage(
        '${updated.name} ${updated.isActive ? "diaktifkan" : "dinonaktifkan"}',
      );
    } on ApiException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pengguna'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(null, 'Semua'),
                      const SizedBox(width: 8),
                      _filterChip('customer', 'Customer'),
                      const SizedBox(width: 8),
                      _filterChip('admin', 'Admin'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView.list()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _loadData)
                    : _users.isEmpty
                        ? const EmptyView(
                            message: 'Tidak ada pengguna ditemukan.',
                            icon: Icons.people_outline,
                          )
                        : RefreshIndicator(
                            onRefresh: () async => _loadData(),
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _users.length + (_loadingMore ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) {
                                if (i >= _users.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final user = _users[i];
                                final isSelf = user.id == currentUserId;

                                return DepthCard(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          theme.colorScheme.primaryContainer,
                                      child: Text(
                                        user.name.isNotEmpty
                                            ? user.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        if (isSelf) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme
                                                  .colorScheme.tertiaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Saya',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onTertiaryContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(user.email),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: user.role == 'admin'
                                                    ? theme.colorScheme
                                                        .tertiaryContainer
                                                    : theme.colorScheme
                                                        .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                user.role == 'admin'
                                                    ? 'Admin'
                                                    : 'Customer',
                                                style: theme
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              user.isActive
                                                  ? Icons.check_circle_outline
                                                  : Icons.cancel_outlined,
                                              size: 14,
                                              color: user.isActive
                                                  ? Colors.green
                                                  : theme.colorScheme.error,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              user.isActive
                                                  ? 'Aktif'
                                                  : 'Nonaktif',
                                              style: theme.textTheme.labelSmall,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: isSelf
                                        ? null
                                        : Switch(
                                            value: user.isActive,
                                            onChanged: _toggling
                                                ? null
                                                : (_) => _toggleActive(user),
                                          ),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String? role, String label) {
    final selected = _roleFilter == role;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        _roleFilter = role;
        _loadData();
      },
    );
  }
}
