import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/api/places_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/budget/services/budget_service.dart';
import '../../../shared/models/gem_model.dart';
import '../services/gems_service.dart';

enum ViewMode { map, list }

enum GemTab { nearby, trending, recent, following }

final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.map);
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');
final activeGemTabProvider = StateProvider<GemTab>((ref) => GemTab.recent);
final tripFilterEnabledProvider = StateProvider<bool>((ref) => false);

class GemsMapScreen extends ConsumerStatefulWidget {
  const GemsMapScreen({super.key});

  @override
  ConsumerState<GemsMapScreen> createState() => _GemsMapScreenState();
}

class _GemsMapScreenState extends ConsumerState<GemsMapScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _mapKey = GlobalKey<_GemMapWidgetState>();
  final _scrollCtrl = ScrollController();

  // Per-tab pagination state
  final _tabGems = <GemTab, List<GemModel>>{};
  final _tabCursors = <GemTab, DocumentSnapshot?>{};
  final _tabHasMore = <GemTab, bool>{for (final t in GemTab.values) t: true};
  bool _isInitialLoading  = false;
  bool _isLoadingMore     = false;
  bool _locationDenied    = false;
  bool _isSearching       = false;
  List<GemModel> _searchResults = [];

  // Bottom sheet — ValueNotifier so only sheet+FAB rebuild on drag, not the map
  static const _sheetClosed = 0.07;
  static const _sheetOpen   = 0.50;   // hard maximum
  final _sheetFraction = ValueNotifier<double>(_sheetOpen);
  late final AnimationController _snapCtrl;
  int _prevGemCount = -1; // tracks gem count changes to re-snap the sheet

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTab(GemTab.recent);
    });
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    _sheetFraction.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _snapSheet(double target) {
    final begin = _sheetFraction.value;
    _snapCtrl.reset();
    final anim = Tween<double>(
      begin: begin,
      end: target,
    ).animate(CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutCubic));
    anim.addListener(() => _sheetFraction.value = anim.value);
    _snapCtrl.forward();
  }

  // Natural open height: just tall enough to show all gems without whitespace.
  double _contentOpenFraction(int gemCount, double screenHeight) {
    const handleH   = 58.0;  // pill + badge row + divider
    const itemH     = 80.0;  // each gem row in the sheet
    const emptyH    = 200.0; // empty-state icon + text + button
    const bottomPad = 10.0;
    final content = handleH + (gemCount == 0 ? emptyH : gemCount * itemH) + bottomPad;
    return (content / screenHeight).clamp(_sheetClosed + 0.02, _sheetOpen);
  }

  // ── Scroll listener ────────────────────────────────────────────────────────

  void _onScroll() {
    if (_isLoadingMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadMoreForTab(ref.read(activeGemTabProvider));
    }
  }

  // ── Pagination helpers ─────────────────────────────────────────────────────

  Future<void> _refreshTab(GemTab tab) async {
    if (!mounted) return;
    setState(() {
      _tabGems[tab] = [];
      _tabCursors[tab] = null;
      _tabHasMore[tab] = true;
      _isInitialLoading = true;
    });
    await _loadMoreForTab(tab);
    if (mounted) setState(() => _isInitialLoading = false);
  }

  String? _activeTripCity() {
    if (!ref.read(tripFilterEnabledProvider)) return null;
    final trip = ref.read(activeTripProvider).valueOrNull;
    if (trip == null) return null;
    final city = trip.destination.split(',').first.trim();
    return city.isEmpty ? null : city;
  }

  Future<void> _loadMoreForTab(GemTab tab) async {
    if (!mounted) return;
    if (_isLoadingMore) return;
    if (_tabHasMore[tab] == false) return;
    if (tab == GemTab.following) return;

    setState(() => _isLoadingMore = true);

    try {
      final category = ref.read(selectedCategoryProvider);
      final cat = category == 'All' ? null : category;
      final service = ref.read(gemsServiceProvider);
      final after = _tabCursors[tab];
      final tripCity = _activeTripCity();

      final GemPage page;
      if (tripCity != null) {
        // Trip city filter overrides all tab-specific queries.
        page = await service.fetchCityPage(
          city: tripCity,
          category: cat,
          after: after,
        );
      } else {
        switch (tab) {
          case GemTab.nearby:
            final pos = await ref.read(currentPositionProvider.future);
            if (pos == null) {
              if (mounted) {
              setState(() {
                _isLoadingMore  = false;
                _locationDenied = true;
              });
            }
              return;
            }
            if (mounted) setState(() => _locationDenied = false);
            page = await service.fetchNearbyPage(
              latitude: pos.latitude,
              longitude: pos.longitude,
              category: cat,
              after: after,
            );
          case GemTab.trending:
            page = await service.fetchTrendingPage(category: cat, after: after);
          case GemTab.recent:
            page = await service.fetchRecentPage(category: cat, after: after);
          case GemTab.following:
            if (mounted) setState(() => _isLoadingMore = false);
            return;
        }
      }

      if (!mounted) return;
      setState(() {
        _tabGems[tab] = [...(_tabGems[tab] ?? []), ...page.gems];
        _tabCursors[tab] = page.cursor;
        _tabHasMore[tab] = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final activeTab = ref.watch(activeGemTabProvider);
    final isMapMode = ref.watch(viewModeProvider) == ViewMode.map;
    final cat = selectedCategory == 'All' ? null : selectedCategory;

    ref.watch(activeTripProvider);
    ref.watch(tripFilterEnabledProvider);

    // Reload when tab changes (if not already loaded for that tab).
    ref.listen(activeGemTabProvider, (prev, next) {
      if (prev != next && _tabGems[next] == null) _refreshTab(next);
    });

    // Reset pagination when category changes.
    ref.listen(selectedCategoryProvider, (prev, next) {
      if (prev != next) _refreshTab(ref.read(activeGemTabProvider));
    });

    // Reset pagination when trip filter is toggled.
    ref.listen(tripFilterEnabledProvider, (prev, next) {
      if (prev != next) _refreshTab(ref.read(activeGemTabProvider));
    });

    // Reset pagination when the active trip changes (new trip or trip completed).
    ref.listen(activeTripProvider, (prev, next) {
      if (prev?.valueOrNull?.id != next.valueOrNull?.id) {
        _refreshTab(ref.read(activeGemTabProvider));
      }
    });

    // Map markers respect the active tab + category chip — same filters as list.
    // Trip city filter is skipped on map (camera is GPS-based).
    final mapGemsAsync = switch (activeTab) {
      GemTab.nearby   => ref.watch(nearbyGemsProvider(cat)),
      GemTab.trending => ref.watch(trendingGemsProvider(cat)),
      _               => ref.watch(allGemsProvider(cat)),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // Always render the map widget so _mapKey.currentState is never null
          // when the user searches. Markers update as the stream emits.
          if (isMapMode)
            _buildMapView(context, mapGemsAsync.valueOrNull ?? [])
          else
            _buildListView(context, activeTab),
          _buildTopOverlay(context),
          if (isMapMode)
            _buildBottomSheet(context, mapGemsAsync.valueOrNull ?? []),
          _buildFloatingActionButton(context),
        ],
      ),
    );
  }

  Widget _buildMapView(BuildContext context, List<GemModel> gems) {
    final markers = gems.map((gem) {
      final pos = LatLng(gem.location.latitude, gem.location.longitude);
      return Marker(
        markerId: MarkerId(gem.id),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(_markerHue(gem.category)),
        infoWindow: InfoWindow(
          title: gem.name,
          snippet: 'Tap to view details',
          onTap: () => context.push(AppRoutes.gemDetailOf(gem.id)),
        ),
        onTap: () {
          _mapKey.currentState?.zoomTo(pos);
          _showGemPreviewSheet(context, gem);
        },
      );
    }).toSet();

    final posAsync = ref.watch(currentPositionProvider);
    final initialPos = posAsync.valueOrNull != null
        ? LatLng(
            posAsync.valueOrNull!.latitude,
            posAsync.valueOrNull!.longitude,
          )
        : null;

    return _GemMapWidget(
      key: _mapKey,
      gemMarkers: markers,
      placesService: ref.read(placesServiceProvider),
      initialLocation: initialPos,
      onAddGem: (latLng) => context.push(
        '${AppRoutes.addGem}?lat=${latLng.latitude}&lng=${latLng.longitude}',
      ),
    );
  }

  double _markerHue(String category) {
    switch (category) {
      case 'Food & Drinks':
        return BitmapDescriptor.hueOrange;
      case 'Nature':
        return BitmapDescriptor.hueGreen;
      case 'Arts':
        return BitmapDescriptor.hueViolet;
      case 'Beach':
        return BitmapDescriptor.hueAzure;
      case 'Local Life':
        return BitmapDescriptor.hueYellow;
      case 'Adventure':
        return BitmapDescriptor.hueRed;
      default:
        return BitmapDescriptor.hueCyan;
    }
  }

  Widget _buildListView(BuildContext context, GemTab tab) {
    final hasActiveTrip = ref.read(activeTripProvider).valueOrNull != null;
    final topPadding = MediaQuery.of(context).viewPadding.top +
        (hasActiveTrip ? 220.0 : 172.0);
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom + 20.0;
    // ── Search results mode ────────────────────────────────────────────────
    if (_isSearching) {
      if (_searchResults.isEmpty) {
        return Container(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(top: topPadding, left: 40, right: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 56, color: AppColors.lightOnSurfaceVar),
                  const SizedBox(height: 16),
                  const Text(
                    'No gems found',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try a different name, city or category',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.lightOnSurfaceVar,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return ListView.builder(
        controller: _scrollCtrl,
        padding: EdgeInsets.only(top: topPadding + 8, bottom: bottomPadding),
        itemCount: _searchResults.length,
        itemBuilder: (ctx, i) => _buildGemListCard(ctx, _searchResults[i]),
      );
    }

    final gems = _tabGems[tab] ?? [];
    final hasMore = _tabHasMore[tab] ?? true;

    // Show full-screen spinner on first load.
    if (_isInitialLoading && gems.isEmpty) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }

    // Empty state per tab.
    if (!_isInitialLoading && gems.isEmpty) {
      final (icon, title, subtitle) = switch (tab) {
        GemTab.following => (
          Icons.people_outline_rounded,
          'No gems from followed travelers',
          'Follow other travelers to see their gems here.\nComing soon!',
        ),
        GemTab.nearby => (
          _locationDenied
              ? Icons.location_disabled_rounded
              : Icons.location_off_outlined,
          _locationDenied
              ? 'Location access needed'
              : (_activeTripCity() != null
                  ? 'No gems in ${_activeTripCity()}'
                  : 'No gems within 50 km'),
          _locationDenied
              ? 'Allow location access to see hidden gems near you.'
              : (_activeTripCity() != null
                  ? 'No community gems found in ${_activeTripCity()} yet.\nBe the first to add one!'
                  : 'Gems added in other cities won\'t appear here.\nSwitch to Recent to see all gems.'),
        ),
        GemTab.trending => (
          Icons.trending_up_rounded,
          'No trending gems yet',
          'Be the first to add and get upvoted!',
        ),
        GemTab.recent => (
          Icons.explore_off_outlined,
          'No gems found',
          'Be the first to add a hidden gem!',
        ),
      };
      return Container(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: topPadding, left: 40, right: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 56, color: AppColors.lightOnSurfaceVar),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.lightOnSurfaceVar,
                  ),
                ),
                if (tab == GemTab.nearby && _locationDenied) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Geolocator.openAppSettings();
                    },
                    icon: const Icon(Icons.location_on_rounded, size: 18),
                    label: const Text(
                      'Enable Location',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // footer item count: add 1 slot when loading more or more pages exist.
    final showFooter = _isLoadingMore || hasMore;

    return RefreshIndicator(
      onRefresh: () => _refreshTab(tab),
      color: AppColors.teal,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        itemCount: gems.length + (showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == gems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.teal,
                  ),
                ),
              ),
            );
          }
          return _buildGemListCard(context, gems[index]);
        },
      ),
    );
  }

  Widget _buildTabRow() {
    final activeTab = ref.watch(activeGemTabProvider);
    const tabs = [
      (GemTab.nearby, 'Nearby', Icons.near_me_rounded),
      (GemTab.trending, 'Trending', Icons.local_fire_department_rounded),
      (GemTab.recent, 'Recent', Icons.access_time_rounded),
      (GemTab.following, 'Following', Icons.people_rounded),
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: tabs.map((t) {
          final (tab, label, icon) = t;
          final isSelected = activeTab == tab;
          final isLocked = tab == GemTab.following;
          return GestureDetector(
            onTap: isLocked
                ? null
                : () => ref.read(activeGemTabProvider.notifier).state = tab,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? AppColors.lightBackground
                        : isSelected
                        ? AppColors.teal
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isLocked
                          ? AppColors.lightOutline
                          : isSelected
                          ? AppColors.teal
                          : AppColors.lightOutline,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isLocked
                            ? AppColors.lightOnSurfaceVar
                            : isSelected
                            ? Colors.white
                            : AppColors.navy,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isLocked
                              ? AppColors.lightOnSurfaceVar
                              : isSelected
                              ? Colors.white
                              : AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  Positioned(
                    top: -6,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Soon',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopOverlay(BuildContext context) {
    final isListMode = ref.watch(viewModeProvider) == ViewMode.list;
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: statusBarHeight + 10,
          left: 16,
          right: 16,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Search bar + Map/List toggle ─────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onChanged: (q) {
                        if (q.trim().isEmpty && _isSearching) {
                          setState(() {
                            _isSearching   = false;
                            _searchResults = [];
                          });
                        }
                      },
                      onSubmitted: (q) async {
                        final query = q.trim();
                        if (query.isEmpty) return;
                        // Search gems first
                        setState(() => _isSearching = true);
                        final results = await ref
                            .read(gemsServiceProvider)
                            .searchGems(query);
                        if (!mounted) return;
                        setState(() => _searchResults = results);
                        // Only geocode the location on the map when no gem
                        // results are found — avoids the Geocoding API error
                        // banner when the user is browsing gem results.
                        if (results.isEmpty) {
                          if (ref.read(viewModeProvider) != ViewMode.map) {
                            ref.read(viewModeProvider.notifier).state =
                                ViewMode.map;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _mapKey.currentState?.searchLocation(query);
                            });
                          } else {
                            _mapKey.currentState?.searchLocation(query);
                          }
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Search gems, cities, categories...',
                        hintStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: AppColors.lightOnSurfaceVar,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.lightOnSurfaceVar,
                          size: 20,
                        ),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchCtrl,
                          builder: (_, val, _) => val.text.isEmpty
                              ? const SizedBox.shrink()
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18,
                                      color: AppColors.lightOnSurfaceVar),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    FocusScope.of(context).unfocus();
                                    setState(() {
                                      _isSearching   = false;
                                      _searchResults = [];
                                    });
                                  },
                                ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF2F4F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    final current = ref.read(viewModeProvider);
                    ref.read(viewModeProvider.notifier).state =
                        current == ViewMode.map ? ViewMode.list : ViewMode.map;
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isListMode
                          ? AppColors.teal
                          : const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isListMode ? Icons.map_rounded : Icons.list_rounded,
                      size: 20,
                      color: isListMode
                          ? Colors.white
                          : AppColors.lightOnSurfaceVar,
                    ),
                  ),
                ),
              ],
            ),
            // ── Tabs ────────────────────────────────────────────────────
            const SizedBox(height: 10),
            _buildTabRow(),
            // ── Category chips ───────────────────────────────────────────
            const SizedBox(height: 8),
            _buildCategoryChips(background: const Color(0xFFF2F4F7)),
            // ── Trip city filter banner ──────────────────────────────────
            _buildTripFilterBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildTripFilterBanner() {
    // Banner only makes sense in list mode — in map mode gems are camera-based.
    if (ref.watch(viewModeProvider) == ViewMode.map) return const SizedBox.shrink();
    final activeTrip = ref.watch(activeTripProvider).valueOrNull;
    if (activeTrip == null) return const SizedBox.shrink();

    final filterEnabled = ref.watch(tripFilterEnabledProvider);
    final city = activeTrip.destination.split(',').first.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(tripFilterEnabledProvider.notifier).state =
          !filterEnabled,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filterEnabled
              ? AppColors.teal.withAlpha(26)
              : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filterEnabled
                ? AppColors.teal.withAlpha(77)
                : AppColors.lightOutline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              filterEnabled
                  ? Icons.flight_takeoff_rounded
                  : Icons.flight_rounded,
              size: 14,
              color: filterEnabled
                  ? AppColors.teal
                  : AppColors.lightOnSurfaceVar,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filterEnabled
                        ? 'Showing gems in $city'
                        : 'Trip to $city planned',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: filterEnabled
                          ? AppColors.teal
                          : AppColors.navy,
                    ),
                  ),
                  Text(
                    filterEnabled
                        ? 'Tap to switch back to your location'
                        : 'Tap to explore gems in $city',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: filterEnabled
                          ? AppColors.teal.withAlpha(180)
                          : AppColors.lightOnSurfaceVar,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: filterEnabled
                    ? AppColors.teal.withAlpha(40)
                    : AppColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                filterEnabled ? 'ON' : 'OFF',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: filterEnabled
                      ? AppColors.teal
                      : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips({required Color background}) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _categories.map((category) {
          final isSelected = selectedCategory == category;
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                category,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.navy,
                ),
              ),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(selectedCategoryProvider.notifier).state = category,
              backgroundColor: background,
              selectedColor: AppColors.teal,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.teal : AppColors.lightOutline,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context, List<GemModel> gems) {
    final screenHeight   = MediaQuery.of(context).size.height;
    final contentFraction = _contentOpenFraction(gems.length, screenHeight);

    // Snap to content height whenever the gem count changes (e.g. on first load
    // or after filtering) so the sheet never shows empty white space.
    if (gems.length != _prevGemCount) {
      _prevGemCount = gems.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _snapSheet(contentFraction);
      });
    }

    return ValueListenableBuilder<double>(
      valueListenable: _sheetFraction,
      builder: (ctx, fraction, child) {
        final sheetHeight = screenHeight * fraction;
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: sheetHeight,
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Handle — drags the sheet ───────────────────────────
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (d) {
                    final delta = -d.delta.dy / screenHeight;
                    _sheetFraction.value = (_sheetFraction.value + delta).clamp(
                      _sheetClosed,
                      contentFraction,   // cap at content height, not fixed max
                    );
                  },
                  onVerticalDragEnd: (d) {
                    final velocity = d.primaryVelocity ?? 0;
                    final mid = (_sheetClosed + contentFraction) / 2;
                    final shouldOpen =
                        velocity < -200 || _sheetFraction.value > mid;
                    _snapSheet(shouldOpen ? contentFraction : _sheetClosed);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.lightOutline,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.teal.withAlpha(18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.diamond_outlined,
                                      size: 12, color: AppColors.teal),
                                  const SizedBox(width: 5),
                                  Text(
                                    gems.isEmpty
                                        ? 'Community Gems'
                                        : '${gems.length} gem${gems.length == 1 ? '' : 's'} on map',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.teal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              fraction > (_sheetClosed + _sheetOpen) / 2
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_up_rounded,
                              size: 20,
                              color: AppColors.lightOnSurfaceVar,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
                ),
                // ── Scrollable gem list ────────────────────────────────
                Expanded(
                  child: gems.isEmpty
                      ? SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.explore_outlined,
                                  size: 40,
                                  color: AppColors.teal,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'No community gems here yet',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Long-press anywhere on the map to add the first hidden gem!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color: AppColors.lightOnSurfaceVar,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: () => context.push(AppRoutes.addGem),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text(
                                    'Add a Gem',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.teal,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: gems.length,
                          itemBuilder: (context, index) =>
                              _buildSheetGemRow(context, gems[index]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetGemRow(BuildContext context, GemModel gem) {
    final catColor = _categoryColor(gem.category);
    return InkWell(
      onTap: () => context.push(AppRoutes.gemDetailOf(gem.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: gem.photos.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: gem.photos.first,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _gemPhotoPlaceholder(catColor),
                      errorWidget: (_, _, _) => _gemPhotoPlaceholder(catColor),
                    )
                  : _gemPhotoPlaceholder(catColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _toTitleCase(gem.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 10, color: AppColors.lightOnSurfaceVar),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          gem.city.isNotEmpty ? gem.city : gem.country,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.lightOnSurfaceVar,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    gem.category,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: catColor,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      gem.upvotes > 0
                          ? Icons.thumb_up_alt_rounded
                          : Icons.thumb_up_alt_outlined,
                      size: 11,
                      color: gem.upvotes > 0
                          ? catColor
                          : AppColors.lightOnSurfaceVar,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${gem.upvotes}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: gem.upvotes > 0
                            ? catColor
                            : AppColors.lightOnSurfaceVar,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.lightOnSurfaceVar, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _gemPhotoPlaceholder(Color color) {
    return Container(
      width: 60,
      height: 60,
      color: color.withAlpha(20),
      child: Icon(Icons.photo_camera, size: 22, color: color.withAlpha(120)),
    );
  }

  Color _categoryColor(String cat) => switch (cat) {
        'Food & Drinks' => AppColors.warning,
        'Nature'        => AppColors.success,
        'Arts'          => AppColors.purple,
        'Beach'         => AppColors.teal,
        'Local Life'    => AppColors.primary,
        'Adventure'     => AppColors.danger,
        _               => AppColors.teal,
      };

  IconData _categoryIcon(String cat) => switch (cat) {
        'Food & Drinks' => Icons.restaurant_outlined,
        'Nature'        => Icons.forest_outlined,
        'Arts'          => Icons.palette_outlined,
        'Beach'         => Icons.beach_access_outlined,
        'Local Life'    => Icons.people_outline_rounded,
        'Adventure'     => Icons.hiking_outlined,
        _               => Icons.diamond_outlined,
      };

  String _toTitleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Widget _buildGemListCard(BuildContext context, GemModel gem) {
    final catColor = _categoryColor(gem.category);
    final catIcon  = _categoryIcon(gem.category);
    return GestureDetector(
      onTap: () => context.push(AppRoutes.gemDetailOf(gem.id)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Thumbnail ──────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
              child: gem.photos.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: gem.photos.first,
                      width: 100,
                      height: 110,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _gemCardPlaceholder(catColor, catIcon),
                      errorWidget: (_, _, _) => _gemCardPlaceholder(catColor, catIcon),
                    )
                  : _gemCardPlaceholder(catColor, catIcon),
            ),
            // ── Content ────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withAlpha(22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: catColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            gem.category,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: catColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    // Name
                    Text(
                      _toTitleCase(gem.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 11, color: AppColors.lightOnSurfaceVar),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            gem.city.isNotEmpty ? gem.city : gem.country,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: AppColors.lightOnSurfaceVar,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Upvotes + chevron
                    Row(
                      children: [
                        Icon(
                          gem.upvotes > 0
                              ? Icons.thumb_up_alt_rounded
                              : Icons.thumb_up_alt_outlined,
                          size: 13,
                          color: gem.upvotes > 0
                              ? catColor
                              : AppColors.lightOnSurfaceVar,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          gem.upvotes > 0
                              ? '${gem.upvotes}'
                              : 'First!',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: gem.upvotes > 0
                                ? catColor
                                : AppColors.lightOnSurfaceVar,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.chevron_right_rounded,
                              size: 18, color: AppColors.lightOnSurfaceVar),
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

  Widget _gemCardPlaceholder(Color color, IconData icon) {
    return Container(
      width: 100,
      height: 110,
      color: color.withAlpha(20),
      child: Icon(icon, color: color, size: 30),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    final isMapMode = ref.watch(viewModeProvider) == ViewMode.map;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return ValueListenableBuilder<double>(
      valueListenable: _sheetFraction,
      builder: (ctx, fraction, child) {
        final fabBottom = isMapMode
            ? (screenHeight * fraction) + 16
            : bottomPad + 20;
        return Positioned(bottom: fabBottom, right: 20, child: child!);
      },
      child: FloatingActionButton(
        heroTag: 'gems_add_fab',
        onPressed: () => context.push(AppRoutes.addGem),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showGemPreviewSheet(BuildContext context, GemModel gem) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomPad = MediaQuery.paddingOf(ctx).bottom;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photo ───────────────────────────────────────────────────
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: gem.photos.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: gem.photos.first,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (ctx2, url) => Container(
                          height: 180,
                          color: AppColors.lightBackground,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.teal,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (ctx2, url, err) => Container(
                          height: 100,
                          color: AppColors.lightBackground,
                          child: const Center(
                            child: Icon(
                              Icons.photo_camera,
                              size: 40,
                              color: AppColors.lightOnSurfaceVar,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 100,
                        color: AppColors.lightBackground,
                        child: const Center(
                          child: Icon(
                            Icons.photo_camera,
                            size: 40,
                            color: AppColors.lightOnSurfaceVar,
                          ),
                        ),
                      ),
              ),
              // ── Details ─────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + bottomPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withAlpha(26),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            gem.category,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.teal,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.thumb_up_alt_outlined,
                          size: 16,
                          color: AppColors.lightOnSurfaceVar,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${gem.upvotes}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.lightOnSurfaceVar,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      gem.name,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.lightOnSurfaceVar,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${gem.city}, ${gem.country}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.lightOnSurfaceVar,
                          ),
                        ),
                      ],
                    ),
                    if (gem.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        gem.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push(AppRoutes.gemDetailOf(gem.id));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View Full Details',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const List<String> _categories = [
  'All',
  'Food & Drinks',
  'Nature',
  'Arts',
  'Beach',
  'Local Life',
  'Adventure',
];


class _GemMapWidget extends StatefulWidget {
  const _GemMapWidget({
    super.key,
    required this.gemMarkers,
    required this.placesService,
    required this.onAddGem,
    this.initialLocation,
  });

  final Set<Marker> gemMarkers;
  final PlacesService placesService; // used for search-bar geocoding
  final void Function(LatLng) onAddGem;
  final LatLng? initialLocation;

  @override
  State<_GemMapWidget> createState() => _GemMapWidgetState();
}

class _GemMapWidgetState extends State<_GemMapWidget> {
  GoogleMapController? _controller;
  LatLng? _current;
  bool _hasInitialGemFit = false;

  static const _fallback = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    // Pre-seed from parent's cached position so onMapCreated sees a non-null
    // _current immediately — avoids the race where the map renders at India center
    if (widget.initialLocation != null) {
      _current = widget.initialLocation;
    }
    _initLocation();
  }

  @override
  void didUpdateWidget(_GemMapWidget old) {
    super.didUpdateWidget(old);
    // Fit camera to community gems only on first load, not on every rebuild
    if (!_hasInitialGemFit &&
        widget.gemMarkers.isNotEmpty &&
        _controller != null) {
      _fitGemMarkers(widget.gemMarkers);
    }
  }

  void _fitGemMarkers(Set<Marker> gems) {
    if (gems.isEmpty || _controller == null) return;
    _hasInitialGemFit = true;

    // Only fit gems within 50 km of the user to avoid zooming out to world level
    final userPos = _current;
    final positions = gems.map((m) => m.position).where((p) {
      if (userPos == null) return true;
      return Geolocator.distanceBetween(
            userPos.latitude,
            userPos.longitude,
            p.latitude,
            p.longitude,
          ) <=
          50000;
    }).toList();

    // If nothing nearby, just stay at user's location
    if (positions.isEmpty) return;

    if (positions.length == 1) {
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: positions.first, zoom: 15),
        ),
      );
      return;
    }
    var minLat = positions.first.latitude;
    var maxLat = positions.first.latitude;
    var minLng = positions.first.longitude;
    var maxLng = positions.first.longitude;
    for (final p in positions) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  Future<void> _initLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        _moveTo(LatLng(last.latitude, last.longitude));
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      _moveTo(LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  void _moveTo(LatLng target) {
    setState(() => _current = target);
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 15)),
    );
  }

  void zoomTo(LatLng target) {
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 16)),
    );
  }

  Future<void> searchLocation(String query) async {
    if (_controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Map is still loading. Please try again.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final coord = await widget.placesService.geocodeQuery(query);
      if (!mounted) return;
      if (coord == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No results found for "$query"',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final latLng = LatLng(coord.latitude, coord.longitude);
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 13),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      final friendly =
          msg.contains('REQUEST_DENIED') || msg.contains('not authorized')
          ? 'Geocoding API not enabled. Go to GCP Console → APIs & Services → enable Geocoding API.'
          : msg.contains('OVER_DAILY_LIMIT') || msg.contains('quota')
          ? 'Geocoding quota exceeded. Try again tomorrow.'
          : msg.contains('INVALID_REQUEST') || msg.contains('400')
          ? 'Invalid search query. Try a different location name.'
          : 'Search failed: $msg';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendly,
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _current ?? _fallback,
        zoom: _current != null ? 15 : 5,
      ),
      markers: widget.gemMarkers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      onMapCreated: (c) {
        _controller = c;
        if (widget.gemMarkers.isNotEmpty) {
          _fitGemMarkers(widget.gemMarkers);
        } else {
          final cur = _current;
          if (cur != null) {
            c.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: cur, zoom: 15),
              ),
            );
          }
        }
      },
      onLongPress: widget.onAddGem,
    );
  }
}

