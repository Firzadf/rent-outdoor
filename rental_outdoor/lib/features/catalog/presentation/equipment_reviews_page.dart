import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/rating_stars.dart';
import '../domain/review.dart';
import 'equipment_reviews_provider.dart';
import '../../../core/widgets/depth.dart';

/// Semua ulasan satu alat (`GET /equipments/{id}/reviews`) —
/// daftar berpaginasi dengan infinite scroll + pull-to-refresh.
class EquipmentReviewsPage extends ConsumerStatefulWidget {
  const EquipmentReviewsPage({super.key, required this.equipmentId});

  final int equipmentId;

  @override
  ConsumerState<EquipmentReviewsPage> createState() =>
      _EquipmentReviewsPageState();
}

class _EquipmentReviewsPageState extends ConsumerState<EquipmentReviewsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(equipmentReviewsProvider(widget.equipmentId).notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(equipmentReviewsProvider(widget.equipmentId));
    try {
      await ref.read(equipmentReviewsProvider(widget.equipmentId).future);
    } catch (_) {
      // Error sudah tampil di state provider.
    }
  }

  void _retry() => ref.invalidate(equipmentReviewsProvider(widget.equipmentId));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(equipmentReviewsProvider(widget.equipmentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Semua Ulasan')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: state.when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: false,
            loading: () => const LoadingView.list(),
            error: (error, _) => _fullMessage(
              ErrorView(
                message: friendlyErrorMessage(error),
                onRetry: _retry,
              ),
            ),
            data: (data) {
              if (data.items.isEmpty) {
                return _fullMessage(
                  const EmptyView(
                    message: 'Belum ada ulasan untuk alat ini.',
                    icon: Icons.rate_review_outlined,
                  ),
                );
              }
              return _buildList(data);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildList(ReviewsListState data) {
    final showFooter = data.loadingMore || data.loadMoreError != null;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.separated(
            itemCount: data.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _reviewCard(data.items[index]),
          ),
        ),
        if (showFooter)
          SliverToBoxAdapter(
            child: data.loadMoreError == null
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            data.loadMoreError!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(equipmentReviewsProvider(
                                        widget.equipmentId)
                                    .notifier)
                                .loadMore(),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _fullMessage(Widget child) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: child,
        ),
      ],
    );
  }

  Widget _reviewCard(Review review) {
    final theme = Theme.of(context);
    final url = resolveImageUrl(review.profileImage);

    return DepthCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: url.isEmpty
                  ? Text(
                      review.initials,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: Text(
                              review.initials,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.userName ?? 'Pengguna',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      RatingStars(rating: review.rating.toDouble(), size: 15),
                    ],
                  ),
                  if (review.comment != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      review.comment!,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    formatDate(review.createdAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
