import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/gem_model.dart';
import '../services/gems_service.dart';

// ─── NEW GEMS SCREEN ──────────────────────────────────────────────────────────
// Shows the specific gems from a notification batch (tapped from notification).
// ─────────────────────────────────────────────────────────────────────────────

class NewGemsScreen extends ConsumerStatefulWidget {
  const NewGemsScreen({
    super.key,
    required this.gemIds,
    required this.city,
  });

  final List<String> gemIds;
  final String city;

  @override
  ConsumerState<NewGemsScreen> createState() => _NewGemsScreenState();
}

class _NewGemsScreenState extends ConsumerState<NewGemsScreen> {
  List<GemModel> _gems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGems();
  }

  Future<void> _loadGems() async {
    setState(() => _loading = true);
    final service = ref.read(gemsServiceProvider);
    final results = await Future.wait(
      widget.gemIds.map((id) => service.getGemById(id)),
    );
    if (mounted) {
      setState(() {
        _gems    = results.whereType<GemModel>().toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New in ${widget.city}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            if (!_loading)
              Text(
                '${_gems.length} spot${_gems.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.lightOnSurfaceVar,
                ),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _gems.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadGems,
                  color: AppColors.teal,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _gems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _GemCard(gem: _gems[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.diamond_outlined, size: 64, color: AppColors.lightOutline),
          SizedBox(height: 16),
          Text(
            'These gems are no longer available',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              color: AppColors.lightOnSurfaceVar,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GEM CARD ─────────────────────────────────────────────────────────────────

class _GemCard extends StatelessWidget {
  const _GemCard({required this.gem});
  final GemModel gem;

  @override
  Widget build(BuildContext context) {
    final hasRatings = gem.ratingCount > 0;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.gemDetailOf(gem.id)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)),
              child: SizedBox(
                width: 100,
                height: 110,
                child: gem.photos.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: gem.photos.first,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => _photoPlaceholder(),
                        errorWidget: (_, _, _) => _photoPlaceholder(),
                      )
                    : _photoPlaceholder(),
              ),
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        gem.category,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Name
                    Text(
                      gem.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Rating row
                    if (hasRatings) ...[
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFFFC107)),
                          const SizedBox(width: 3),
                          Text(
                            gem.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${gem.ratingCount} ${gem.ratingCount == 1 ? 'review' : 'reviews'})',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: AppColors.lightOnSurfaceVar,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'No reviews yet — be the first!',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.lightOnSurfaceVar,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Upvotes + explore
                    Row(
                      children: [
                        const Icon(Icons.thumb_up_alt_outlined,
                            size: 13, color: AppColors.lightOnSurfaceVar),
                        const SizedBox(width: 4),
                        Text(
                          '${gem.upvotes}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.lightOnSurfaceVar,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Explore →',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: AppColors.teal.withAlpha(20),
      child: const Center(
        child: Icon(Icons.diamond_rounded, color: AppColors.teal, size: 32),
      ),
    );
  }
}
