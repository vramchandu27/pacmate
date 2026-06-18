import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/api/gemini_api_service.dart';
import '../../../core/config/env_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../services/packing_service.dart';

String _destinationMapUrl(String destination) {
  final key = EnvConfig.googleMapsKey;
  if (destination.isEmpty || key.isEmpty) return '';
  final encoded = Uri.encodeComponent(destination);
  return 'https://maps.googleapis.com/maps/api/staticmap'
      '?center=$encoded&zoom=11&size=800x400&scale=2&maptype=roadmap&key=$key';
}

// ─── PROVIDERS ────────────────────────────────────────────────────────────────

final _packingCategoryProvider = StateProvider<String>((ref) => 'All');

// ─── PACKING LIST SCREEN ─────────────────────────────────────────────────────

class PackingListScreen extends ConsumerStatefulWidget {
  const PackingListScreen({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<PackingListScreen> createState() => _PackingListScreenState();
}

class _PackingListScreenState extends ConsumerState<PackingListScreen>
    with TickerProviderStateMixin {
  late AnimationController _aiController;
  late AnimationController _confettiController;
  late AnimationController _readyEntranceController;
  late AnimationController _readyBounceController;
  late Animation<Offset>   _readySlideAnim;
  late Animation<double>   _readyBounceAnim;
  bool _isGenerating = false;
  bool _prevAllDone  = false;
  bool _showConfetti = false;
  bool _markedReady  = false;
  String? _ownerUid;

  @override
  void initState() {
    super.initState();
    _aiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _readyEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _readyBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _readySlideAnim = Tween<Offset>(
      begin: const Offset(0, 2.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _readyEntranceController,
      curve: Curves.easeOutBack,
    ));
    _readyBounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.90), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.08), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0),  weight: 40),
    ]).animate(CurvedAnimation(
      parent: _readyBounceController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _aiController.dispose();
    _confettiController.dispose();
    _readyEntranceController.dispose();
    _readyBounceController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final listAsync        = ref.watch(packingListProvider(widget.listId));
    final selectedCategory = ref.watch(_packingCategoryProvider);

    return listAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          title: const Text('Packing List',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(backgroundColor: AppColors.navy, foregroundColor: Colors.white),
        body: const Center(
          child: Text(AppStrings.somethingWrong,
              style: TextStyle(fontFamily: 'Poppins')),
        ),
      ),
      data: (listData) {
        if (listData == null) {
          return Scaffold(
            appBar: AppBar(
                backgroundColor: AppColors.navy, foregroundColor: Colors.white),
            body: const Center(
              child: Text('List not found.',
                  style: TextStyle(fontFamily: 'Poppins')),
            ),
          );
        }

        final rawItems   = List<Map<String, dynamic>>.from(listData['items'] as List? ?? []);
        final normalized = _normalizeItems(rawItems);
        final total      = normalized.length;
        final packed     = normalized.where((i) => i['packed'] == true).length;
        final progress   = total > 0 ? packed / total : 0.0;
        final allDone      = total > 0 && packed == total;
        final isOwner      = listData['userId'] == ref.read(packingServiceProvider).currentUid;
        final firestoreReady = listData['markedReady'] as bool? ?? false;
        final showReady    = packed > 0 && !firestoreReady && !_markedReady;

        // Keep ownerUid in sync so _onReadyTap can reference it
        _ownerUid = listData['userId'] as String?;

        final destination = listData['destination'] as String? ?? '';
        final listName    = listData['name'] as String? ?? 'Packing List';
        final mapUrl      = _destinationMapUrl(destination);
        final subtitle    = allDone
            ? '🎉 All packed! Ready to go'
            : 'Tap items as you pack · $packed/$total done';

        // Slide up the Ready button when all items are packed (and not yet confirmed)
        if (showReady && !_prevAllDone) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _readyEntranceController.forward(from: 0);
          });
        }
        _prevAllDone = showReady;

        final filtered = _filterItems(normalized, selectedCategory);
        final grouped  = _groupByCategory(filtered);

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildSliverAppBar(
                    context: context,
                    title: listName,
                    subtitle: subtitle,
                    mapUrl: mapUrl,
                    destination: destination,
                    progress: progress,
                    allDone: allDone,
                    ownerListData: isOwner ? listData : null,
                    rawItems: rawItems,
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _CategoryChipDelegate(
                      selectedCategory: selectedCategory,
                      onSelect: (cat) =>
                          ref.read(_packingCategoryProvider.notifier).state = cat,
                    ),
                  ),
                  if (total == 0)
                    SliverFillRemaining(child: _buildEmptyState())
                  else ...[
                    for (final entry in grouped.entries) ...[
                      SliverToBoxAdapter(
                        child: _buildCategoryHeader(entry.key, entry.value),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _buildItemRow(entry.value[i], rawItems),
                          childCount: entry.value.length,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: false,
                        ),
                      ),
                    ],
                    SliverToBoxAdapter(child: SizedBox(height: showReady ? 180 : 100)),
                  ],
                ],
              ),
              if (_showConfetti)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Lottie.asset(
                      AppLottie.confetti,
                      controller: _confettiController,
                      repeat: false,
                      errorBuilder: (context, e, stack) => const SizedBox(),
                      onLoaded: (comp) {
                        _confettiController
                          ..duration = comp.duration
                          ..forward(from: 0);
                      },
                    ),
                  ),
                ),
              if (showReady) _buildReadyBar(context),
            ],
          ),
          floatingActionButtonLocation: showReady
              ? FloatingActionButtonLocation.startFloat
              : FloatingActionButtonLocation.endFloat,
          floatingActionButton: FloatingActionButton(
                  heroTag: 'packing_add_fab',
                  onPressed: () => _addCustomItem(rawItems, selectedCategory),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  child: const Icon(Icons.add_rounded, size: 28),
                ),
        );
      },
    );
  }

  // ── Sliver app bar ─────────────────────────────────────────────────────────

  Widget _buildSliverAppBar({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String mapUrl,
    required String destination,
    required double progress,
    required bool allDone,
    required Map<String, dynamic>? ownerListData,
    required List<Map<String, dynamic>> rawItems,
  }) {
    return SliverAppBar(
      expandedHeight: 230.0,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(60),
            shape: BoxShape.circle,
          ),
          child: const Icon(
              Icons.arrow_back_ios_new_rounded, size: 17, color: Colors.white),
        ),
      ),
      actions: [
        if (ownerListData != null)
          Tooltip(
            message: 'Share with Trip Mate',
            child: _circleAction(
              icon: Icons.person_add_outlined,
              onTap: () => _showShareSheet(ownerListData),
            ),
          ),
        if (ownerListData != null)
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(60),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_vert_rounded,
                  color: Colors.white, size: 20),
            ),
            onSelected: (v) {
              if (v == 'template') _showSaveAsTemplateDialog();
              if (v == 'markAll') _markAllPacked(ownerListData);
              if (v == 'delete') _deleteList();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'template',
                child: Row(children: [
                  Icon(Icons.bookmark_add_outlined,
                      size: 20, color: AppColors.primary),
                  SizedBox(width: 12),
                  Text('Save as Template',
                      style: TextStyle(fontFamily: 'Poppins')),
                ]),
              ),
              const PopupMenuItem(
                value: 'markAll',
                child: Row(children: [
                  Icon(Icons.checklist_rounded,
                      size: 20, color: AppColors.success),
                  SizedBox(width: 12),
                  Text('Mark All Packed',
                      style: TextStyle(fontFamily: 'Poppins')),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 20, color: AppColors.danger),
                  SizedBox(width: 12),
                  Text('Delete List',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: AppColors.danger)),
                ]),
              ),
            ],
          )
        else
          _circleAction(
            icon: Icons.delete_outline_rounded,
            color: AppColors.danger,
            onTap: _deleteList,
          ),
        const SizedBox(width: 6),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(14),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withAlpha(60),
              valueColor: AlwaysStoppedAnimation<Color>(
                allDone ? AppColors.success : Colors.white,
              ),
              minHeight: 5,
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: _buildHeroBackground(
          mapUrl, destination, title, subtitle, allDone),
      ),
    );
  }

  Widget _circleAction({
    IconData? icon,
    Widget? child,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(60),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: child ??
              Icon(icon!, color: color, size: 19),
        ),
      ),
    );
  }

  // ── Hero background ────────────────────────────────────────────────────────

  Widget _buildHeroBackground(
    String? coverUrl,
    String destination,
    String title,
    String subtitle,
    bool allDone,
  ) {
    final hasCover  = coverUrl != null && coverUrl.isNotEmpty;
    final initial   = destination.isNotEmpty ? destination[0].toUpperCase() : '?';
    const gradients = [
      AppColors.primary, AppColors.teal, AppColors.purple,
      AppColors.warning, AppColors.success,
    ];
    final gradColor = destination.isNotEmpty
        ? gradients[destination.codeUnitAt(0) % gradients.length]
        : AppColors.primary;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Photo or gradient fallback ─────────────────────────────────────
        if (hasCover)
          CachedNetworkImage(
            imageUrl: coverUrl,
            fit: BoxFit.cover,
            placeholder: (ctx, url) => _gradientFallback(gradColor, initial),
            errorWidget: (ctx, url, err) => _gradientFallback(gradColor, initial),
          )
        else
          _gradientFallback(gradColor, initial),

        // ── Top shadow so action buttons are readable ──────────────────────
        Positioned(
          left: 0, right: 0, top: 0,
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withAlpha(110), Colors.transparent],
              ),
            ),
          ),
        ),

        // ── Bottom gradient so title text is readable ──────────────────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withAlpha(200), Colors.transparent],
              ),
            ),
          ),
        ),

        // ── Destination + list name overlay ───────────────────────────────
        Positioned(
          left: 20, right: 20, bottom: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (destination.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.place_rounded,
                        color: Colors.white70, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      destination,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: allDone ? AppColors.success : Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradientFallback(Color color, String initial) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withAlpha(200)],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.9, 0.0),
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 160,
            fontWeight: FontWeight.w900,
            color: Colors.white.withAlpha(18),
          ),
        ),
      ),
    );
  }

  // ── Item list ──────────────────────────────────────────────────────────────

  Widget _buildCategoryHeader(
    String category,
    List<Map<String, dynamic>> items,
  ) {
    final packedCount = items.where((i) => i['packed'] == true).length;
    final catColor    = _categoryColor(category);
    final allDone     = packedCount == items.length && items.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: catColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _capitalize(category),
              style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13,
                fontWeight: FontWeight.w700, color: catColor,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: allDone
                  ? AppColors.success.withAlpha(20)
                  : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$packedCount/${items.length}',
              style: TextStyle(
                fontFamily: 'Poppins', fontSize: 12,
                fontWeight: FontWeight.w600,
                color: allDone
                    ? AppColors.success
                    : AppColors.lightOnSurfaceVar,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> rawItems,
  ) {
    final isPacked    = item['packed'] as bool? ?? false;
    final index       = item['_index'] as int;
    final isImportant = item['isImportant'] as bool? ?? false;
    final name        = item['name'] as String? ?? '';
    final quantity    = item['quantity'] as int? ?? 1;
    final category    = item['category'] as String? ?? '';
    final showQty     = category == 'Clothing';

    final accentColor = isPacked
        ? AppColors.success
        : _categoryColor(category);

    return GestureDetector(
      onTap: () => _toggleItem(index, rawItems),
      onLongPress: () => _showItemOptions(index, item, rawItems),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isPacked ? AppColors.success.withAlpha(12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPacked
                ? AppColors.success.withAlpha(60)
                : AppColors.lightOutline,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 4,
                  color: accentColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: isPacked
                                ? AppColors.success
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPacked
                                  ? AppColors.success
                                  : AppColors.lightOutline,
                              width: 2,
                            ),
                          ),
                          child: isPacked
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isPacked
                                  ? AppColors.lightOnSurfaceVar
                                  : AppColors.navy,
                              decoration: isPacked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (isImportant && !isPacked) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withAlpha(15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Must', style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            )),
                          ),
                        ],
                        if (showQty) ...[
                        const SizedBox(width: 8),
                        // ── Inline quantity controls ─────────────────────
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _updateQuantity(
                              index, quantity - 1, rawItems),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: quantity > 1
                                  ? AppColors.primary.withAlpha(15)
                                  : AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: quantity > 1
                                    ? AppColors.primary.withAlpha(60)
                                    : AppColors.lightOutline,
                              ),
                            ),
                            child: Icon(Icons.remove_rounded,
                                size: 15,
                                color: quantity > 1
                                    ? AppColors.primary
                                    : AppColors.lightOnSurfaceVar),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '$quantity',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _updateQuantity(
                              index, quantity + 1, rawItems),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.primary.withAlpha(60)),
                            ),
                            child: const Icon(Icons.add_rounded,
                                size: 15, color: AppColors.primary),
                          ),
                        ),
                        ],
                        if (isPacked) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.luggage_rounded,
                  size: 50, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nothing packed yet',
              style: TextStyle(
                fontFamily: 'Poppins', fontSize: 20,
                fontWeight: FontWeight.w700, color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Let AI build your perfect packing list\nin seconds based on your destination.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins', fontSize: 14,
                color: AppColors.lightOnSurfaceVar, height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateAIList,
                icon: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 20),
                label: const Text(
                  'Generate with AI',
                  style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 15,
                    fontWeight: FontWeight.w600, color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withAlpha(120),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'or tap + to add items manually',
              style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13,
                color: AppColors.lightOnSurfaceVar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  List<Map<String, dynamic>> _normalizeItems(List<Map<String, dynamic>> raw) {
    return raw.asMap().entries.map((e) {
      final item = Map<String, dynamic>.from(e.value);
      item['_index'] = e.key;
      final cat = item['category'] as String?;
      final normalized = cat != null && cat.isNotEmpty ? _titleCase(cat) : 'Miscellaneous';
      item['category'] = normalized == 'Other' ? 'Miscellaneous' : normalized;
      item['packed'] ??= false;
      return item;
    }).toList();
  }

  List<Map<String, dynamic>> _filterItems(
      List<Map<String, dynamic>> items, String category) {
    if (category == 'All') return items;
    return items.where((i) => i['category'] == category).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupByCategory(
      List<Map<String, dynamic>> items) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final cat = item['category'] as String? ?? 'Miscellaneous';
      grouped.putIfAbsent(cat, () => []).add(item);
    }
    return grouped;
  }

  // ── Ready to Go ───────────────────────────────────────────────────────────

  Widget _buildReadyBar(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottomPad + 20,
      child: SlideTransition(
        position: _readySlideAnim,
        child: ScaleTransition(
          scale: _readyBounceAnim,
          child: GestureDetector(
            onTap: _onReadyTap,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.success, AppColors.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withAlpha(90),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Ready to Go!',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onReadyTap() async {
    // Hide the button immediately so it won't reappear on re-open
    setState(() => _markedReady = true);
    // Persist to Firestore so it stays hidden across sessions
    try {
      await ref.read(packingServiceProvider).markReady(
            widget.listId,
            ownerUid: _ownerUid,
          );
    } catch (_) {}
    await _readyBounceController.forward(from: 0);
    if (!mounted) return;
    setState(() => _showConfetti = true);
    _confettiController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) context.pop();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Color _categoryColor(String category) => switch (category.toLowerCase()) {
        'documents'   => AppColors.primary,
        'clothing'    => AppColors.success,
        'toiletries'  => AppColors.teal,
        'electronics' => AppColors.purple,
        'health'      => AppColors.danger,
        'gear'        => AppColors.warning,
        'essentials'  => AppColors.warning,
        _             => AppColors.primary,
      };

  // ── Firestore actions ──────────────────────────────────────────────────────

  Future<void> _deleteList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete List?', style: TextStyle(
          fontFamily: 'Poppins', fontWeight: FontWeight.w600,
        )),
        content: const Text('This packing list will be permanently deleted.',
            style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(packingServiceProvider).deletePackingList(widget.listId);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(AppStrings.somethingWrong),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _markAllPacked(Map<String, dynamic> listData) async {
    final rawItems =
        List<Map<String, dynamic>>.from(listData['items'] as List? ?? []);
    final updated = rawItems
        .map((item) => Map<String, dynamic>.from(item)..['packed'] = true)
        .toList();
    try {
      await ref.read(packingServiceProvider).updateItems(widget.listId, updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(AppStrings.somethingWrong,
              style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  void _showItemOptions(
    int index,
    Map<String, dynamic> item,
    List<Map<String, dynamic>> rawItems,
  ) {
    final name   = item['name'] as String? ?? '';
    int quantity = item['quantity'] as int? ?? 1;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightOutline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(name, style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 16,
                fontWeight: FontWeight.w600, color: AppColors.navy,
              )),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Quantity', style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 14,
                    fontWeight: FontWeight.w500, color: AppColors.navy,
                  )),
                  const Spacer(),
                  IconButton(
                    onPressed: quantity > 1
                        ? () => setSheet(() => quantity--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    color: AppColors.primary,
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text('$quantity', style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 18,
                      fontWeight: FontWeight.w700, color: AppColors.navy,
                    )),
                  ),
                  IconButton(
                    onPressed: () => setSheet(() => quantity++),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _updateQuantity(index, quantity, rawItems);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Save', style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600,
                  )),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _deleteItem(index, rawItems);
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger),
                  label: const Text('Remove Item', style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  )),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateQuantity(
    int index, int quantity, List<Map<String, dynamic>> rawItems) async {
    if (quantity < 1) return;
    final updated = rawItems.asMap().entries.map((e) {
      final item = Map<String, dynamic>.from(e.value)..remove('_index');
      if (e.key == index) item['quantity'] = quantity;
      return item;
    }).toList();
    try {
      await ref.read(packingServiceProvider).updateItems(widget.listId, updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(AppStrings.somethingWrong,
              style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _deleteItem(
    int index, List<Map<String, dynamic>> rawItems) async {
    final updated = rawItems.asMap().entries
        .where((e) => e.key != index)
        .map((e) => Map<String, dynamic>.from(e.value)..remove('_index'))
        .toList();
    try {
      await ref.read(packingServiceProvider).updateItems(widget.listId, updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(AppStrings.somethingWrong,
              style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _toggleItem(
    int index, List<Map<String, dynamic>> rawItems) async {
    final updated = rawItems.asMap().entries.map((e) {
      final item = Map<String, dynamic>.from(e.value)..remove('_index');
      if (e.key == index) item['packed'] = !(item['packed'] as bool? ?? false);
      return item;
    }).toList();
    try {
      await ref.read(packingServiceProvider).updateItems(widget.listId, updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(AppStrings.somethingWrong,
              style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _addCustomItem(
    List<Map<String, dynamic>> rawItems,
    String selectedCategory,
  ) async {
    final nameCtrl        = TextEditingController();
    String pickedCategory = selectedCategory == 'All' ? 'Miscellaneous' : selectedCategory;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(AppStrings.addItem, style: TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w600,
          )),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(fontFamily: 'Poppins'),
                decoration: const InputDecoration(
                  labelText: AppStrings.itemName,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: pickedCategory,
                decoration: const InputDecoration(
                  labelText: AppStrings.itemCategory,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  'Documents', 'Clothing', 'Essentials',
                  'Toiletries', 'Electronics', 'Miscellaneous',
                ]
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => pickedCategory = v ?? 'Miscellaneous'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text(AppStrings.addItem),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;

    final cleanRaw = rawItems
        .map((item) => Map<String, dynamic>.from(item)..remove('_index'))
        .toList();
    try {
      await ref.read(packingServiceProvider).updateItems(widget.listId, [
        ...cleanRaw,
        {
          'name': nameCtrl.text.trim(),
          'packed': false,
          'category': pickedCategory,
        },
      ]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(AppStrings.somethingWrong),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  // ── Share sheet ────────────────────────────────────────────────────────────

  void _showShareSheet(Map<String, dynamic> listData) {
    final emailCtrl  = TextEditingController();
    final sharedWith = List<String>.from(listData['sharedWith'] as List? ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom +
                  MediaQuery.of(ctx).viewPadding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.lightOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Share with Trip Mate', style: TextStyle(
              fontFamily: 'Poppins', fontSize: 20,
              fontWeight: FontWeight.w700, color: AppColors.navy,
            )),
            const SizedBox(height: 4),
            Text(
              sharedWith.isEmpty
                  ? 'Only you can see this list right now.'
                  : 'Shared with ${sharedWith.length} person${sharedWith.length == 1 ? '' : 's'}.',
              style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 13,
                color: AppColors.lightOnSurfaceVar,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontFamily: 'Poppins'),
              decoration: InputDecoration(
                hintText: 'friend@example.com',
                hintStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.lightOnSurfaceVar),
                prefixIcon: const Icon(Icons.email_outlined,
                    color: AppColors.lightOnSurfaceVar, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.lightOutline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  if (email.isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    final name = await ref
                        .read(packingServiceProvider)
                        .shareListWith(widget.listId, email);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('List shared with $name!',
                            style: const TextStyle(fontFamily: 'Poppins')),
                        backgroundColor: AppColors.success,
                      ));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$e',
                            style: const TextStyle(fontFamily: 'Poppins')),
                        backgroundColor: AppColors.danger,
                      ));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Send Invite', style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Save as template ───────────────────────────────────────────────────────

  Future<void> _showSaveAsTemplateDialog() async {
    final nameCtrl = TextEditingController(
      text: ref.read(packingListProvider(widget.listId)).value?['name']
              as String? ??
          '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Template', style: TextStyle(
          fontFamily: 'Poppins', fontWeight: FontWeight.w600,
        )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Give your template a name so you can reuse it for future trips.',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.lightOnSurfaceVar),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(fontFamily: 'Poppins'),
              decoration: const InputDecoration(
                labelText: 'Template name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Template',
                style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );

    if (confirmed != true || nameCtrl.text.trim().isEmpty) return;

    try {
      await ref
          .read(packingServiceProvider)
          .saveAsTemplate(widget.listId, nameCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Template saved! Use it when creating a new list.',
              style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(AppStrings.somethingWrong,
              style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  // ── AI generation ──────────────────────────────────────────────────────────

  String _monthName(int month) => const [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ][month];

  Future<void> _generateAIList() async {
    final listData    = ref.read(packingListProvider(widget.listId)).value;
    final destination = listData?['destination'] as String? ?? '';

    final destCtrl  = TextEditingController(text: destination);
    final daysCtrl  = TextEditingController(text: '7');
    String selMonth = _monthName(DateTime.now().month);
    String selStyle = 'budget';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).viewPadding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI Packing Assistant', style: TextStyle(
                fontFamily: 'Poppins', fontSize: 20,
                fontWeight: FontWeight.w700, color: AppColors.navy,
              )),
              const SizedBox(height: 20),
              TextField(
                controller: destCtrl,
                style: const TextStyle(fontFamily: 'Poppins'),
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Destination', border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: daysCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontFamily: 'Poppins'),
                      decoration: const InputDecoration(
                        labelText: 'Days', border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selMonth,
                      decoration: const InputDecoration(
                        labelText: 'Month', border: OutlineInputBorder(),
                      ),
                      items: const [
                        'January', 'February', 'March', 'April', 'May', 'June',
                        'July', 'August', 'September', 'October', 'November',
                        'December',
                      ]
                          .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m,
                                  style: const TextStyle(
                                      fontFamily: 'Poppins'))))
                          .toList(),
                      onChanged: (v) =>
                          setSheet(() => selMonth = v ?? selMonth),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selStyle,
                decoration: const InputDecoration(
                  labelText: 'Travel Style', border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'budget',
                      child: Text('Budget',
                          style: TextStyle(fontFamily: 'Poppins'))),
                  DropdownMenuItem(
                      value: 'midrange',
                      child: Text('Mid-range',
                          style: TextStyle(fontFamily: 'Poppins'))),
                  DropdownMenuItem(
                      value: 'luxury',
                      child: Text('Luxury',
                          style: TextStyle(fontFamily: 'Poppins'))),
                ],
                onChanged: (v) => setSheet(() => selStyle = v ?? selStyle),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
                  label: const Text('Generate with AI', style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  )),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || destCtrl.text.trim().isEmpty) return;

    setState(() => _isGenerating = true);
    _aiController.repeat();

    try {
      final categories =
          await ref.read(geminiServiceProvider).generatePackingList(
        destination: destCtrl.text.trim(),
        durationDays: int.tryParse(daysCtrl.text.trim()) ?? 7,
        month: selMonth,
        travelStyle: selStyle,
      );

      final items = <Map<String, dynamic>>[];
      int idx = 0;
      for (final entry in categories.entries) {
        for (final itemName in entry.value) {
          items.add({
            'id': 'ai_${idx++}',
            'name': itemName,
            'category': entry.key,
            'packed': false,
            'quantity': 1,
          });
        }
      }

      await ref.read(packingServiceProvider).updateItems(widget.listId, items);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Added ${items.length} AI-suggested items!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_friendlyAiError(e)),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      _aiController.stop();
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  String _friendlyAiError(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (msg.contains('rate-limited') || msg.contains('resource-exhausted') ||
        msg.contains('limit reached') || msg.contains('quota')) {
      return 'AI is busy right now. Please wait a minute and try again.';
    }
    if (msg.contains('not reachable') || msg.contains('not configured') ||
        msg.contains('not deployed') || msg.contains('unauthenticated') ||
        msg.contains('failed-precondition') || msg.contains('unavailable')) {
      return 'AI generation is currently unavailable. Please try again later.';
    }
    if (msg.contains('invalid') || msg.contains('403')) {
      return 'AI service configuration error. Please contact support.';
    }
    return msg.isNotEmpty ? msg : 'AI generation failed. Please try again.';
  }
}

// ─── CATEGORY CHIP PINNED HEADER ─────────────────────────────────────────────

class _CategoryChipDelegate extends SliverPersistentHeaderDelegate {
  const _CategoryChipDelegate({
    required this.selectedCategory,
    required this.onSelect,
  });

  final String selectedCategory;
  final void Function(String) onSelect;

  static const _categories = [
    'All', 'Documents', 'Clothing', 'Essentials',
    'Toiletries', 'Electronics', 'Miscellaneous',
  ];

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat        = _categories[i];
          final isSelected = selectedCategory == cat;
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat, style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.navy,
              )),
              selected: isSelected,
              onSelected: (_) => onSelect(cat),
              backgroundColor: Colors.white,
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.lightOutline,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(_CategoryChipDelegate oldDelegate) =>
      selectedCategory != oldDelegate.selectedCategory;
}
