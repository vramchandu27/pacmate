import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/places_service.dart';
import '../../../core/api/weather_service.dart';
import '../../../core/config/env_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/budget/services/budget_service.dart';
import '../../../shared/data/destinations_data.dart';
import '../../../shared/models/budget_model.dart';
import '../models/packing_input.dart';
import '../models/packing_result.dart';
import '../services/packing_engine.dart';
import '../services/packing_service.dart';

/// Builds a Google Static Maps URL for a destination.
/// Returns empty string if no Maps key is configured.
String _destinationMapUrl(String destination) {
  final key = EnvConfig.googleMapsKey;
  if (destination.isEmpty || key.isEmpty) return '';
  final encoded = Uri.encodeComponent(destination);
  return 'https://maps.googleapis.com/maps/api/staticmap'
      '?center=$encoded&zoom=11&size=600x300&scale=2&maptype=roadmap&key=$key';
}

// ─── PACKING SCREEN ──────────────────────────────────────────────────────────

class PackingScreen extends ConsumerWidget {
  const PackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync  = ref.watch(packingListsProvider);
    final sharedAsync = ref.watch(sharedListsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Text(
          AppStrings.packingTitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => _openAddSheet(context),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.teal],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'New List',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(context, ref, listsAsync, sharedAsync),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> listsAsync,
    AsyncValue<List<Map<String, dynamic>>> sharedAsync,
  ) {
    if (listsAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (listsAsync.hasError) return _buildError();

    final ownedLists  = listsAsync.value ?? [];
    // sharedAsync may still be loading if the collection group index is
    // being built — fall back to empty so own lists always show immediately.
    final sharedLists = sharedAsync.valueOrNull ?? [];

    if (ownedLists.isEmpty && sharedLists.isEmpty) {
      return _buildEmptyState(context);
    }

    return CustomScrollView(
      slivers: [
        if (ownedLists.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionHeader('My Lists')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => FadeInUp(
                  duration: const Duration(milliseconds: 350),
                  delay: Duration(milliseconds: i * 70),
                  child: _buildCard(context, ref, ownedLists[i], isShared: false),
                ),
                childCount: ownedLists.length,
              ),
            ),
          ),
        ],
        if (sharedLists.isNotEmpty) ...[
          SliverToBoxAdapter(child: _sectionHeader('Shared with Me')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => FadeInUp(
                  duration: const Duration(milliseconds: 350),
                  delay: Duration(milliseconds: i * 70),
                  child: _buildCard(context, ref, sharedLists[i], isShared: true),
                ),
                childCount: sharedLists.length,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.teal],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddPackingListSheet(),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(Icons.luggage_outlined, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Packing Lists Yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Create a smart packing list tailored to your trip',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                color: AppColors.lightOnSurfaceVar,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _openAddSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create List', style: TextStyle(fontFamily: 'Poppins')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card ───────────────────────────────────────────────────────────────────

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> list, {
    required bool isShared,
  }) {
    final items       = List<Map<String, dynamic>>.from(list['items'] as List? ?? []);
    final packedCount = items.where((i) => i['packed'] == true).length;
    final progress    = items.isEmpty ? 0.0 : packedCount / items.length;
    final listId      = list['id'] as String? ?? '';
    final dest        = list['destination'] as String? ?? '';
    final mapUrl      = _destinationMapUrl(dest);

    final card = GestureDetector(
      onTap: () => context.push(AppRoutes.packingListOf(listId)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightOutline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Destination map banner ─────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: mapUrl.isNotEmpty
                  ? _buildMapHeader(mapUrl, dest, isShared)
                  : _buildGradientBanner(dest, isShared),
            ),

            // ── Card body ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          list['name'] as String? ?? '',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _progressColor(progress).withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          items.isEmpty ? '0 items' : '$packedCount/${items.length}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _progressColor(progress),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.lightOutline,
                      valueColor: AlwaysStoppedAnimation<Color>(_progressColor(progress)),
                      minHeight: 5,
                    ),
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: items.take(5).map(_buildItemChip).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Shared lists: no swipe-to-delete
    if (isShared) return card;

    return Dismissible(
      key: Key(listId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'Delete List?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Delete "${list['name']}"? This cannot be undone.',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        try {
          await ref.read(packingServiceProvider).deletePackingList(listId);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(AppStrings.somethingWrong, style: TextStyle(fontFamily: 'Poppins')),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        }
      },
      child: card,
    );
  }

  Widget _buildMapHeader(String url, String dest, bool isShared) {
    return Stack(
      children: [
        CachedNetworkImage(
          imageUrl: url,
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            height: 140,
            color: AppColors.primary.withAlpha(15),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, _, _) => _buildGradientBanner(dest, isShared),
        ),
        // Fade at bottom for text legibility
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withAlpha(170), Colors.transparent],
              ),
            ),
          ),
        ),
        // Destination label
        Positioned(
          left: 14, bottom: 10,
          child: Row(
            children: [
              const Icon(Icons.place_rounded, color: Colors.white70, size: 13),
              const SizedBox(width: 4),
              Text(
                dest,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        if (isShared) _sharedBadge(top: 10, right: 12),
      ],
    );
  }

  Widget _buildGradientBanner(String dest, bool isShared) {
    final initial = dest.isNotEmpty ? dest[0].toUpperCase() : '?';
    final color   = _destinationColor(dest);
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withAlpha(200)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8, bottom: -14,
            child: Text(
              initial,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 96,
                fontWeight: FontWeight.w900,
                color: Colors.white.withAlpha(22),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.place_rounded, color: Colors.white60, size: 14),
                const SizedBox(height: 2),
                Text(
                  dest.isEmpty ? 'Unknown destination' : dest,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (isShared) _sharedBadge(top: 10, right: 12),
        ],
      ),
    );
  }

  Widget _sharedBadge({required double top, required double right}) {
    return Positioned(
      top: top,
      right: right,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.teal.withAlpha(210),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_alt_rounded, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text(
              'Shared',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemChip(Map<String, dynamic> item) {
    final isPacked = item['packed'] as bool? ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isPacked ? AppColors.success.withAlpha(15) : AppColors.lightBackground,
        border: Border.all(color: isPacked ? AppColors.success : AppColors.lightOutline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPacked) ...[
            const Icon(Icons.check_rounded, color: AppColors.success, size: 13),
            const SizedBox(width: 3),
          ],
          Text(
            item['name'] as String? ?? '',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isPacked ? AppColors.success : AppColors.lightOnSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
          SizedBox(height: 16),
          Text(
            AppStrings.somethingWrong,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ── Pure helpers ───────────────────────────────────────────────────────────

  Color _progressColor(double p) {
    if (p >= 1.0) return AppColors.success;
    if (p >= 0.5) return AppColors.primary;
    return AppColors.lightOnSurfaceVar;
  }

  Color _destinationColor(String dest) {
    const colors = [
      AppColors.primary,
      AppColors.teal,
      AppColors.purple,
      AppColors.warning,
      AppColors.success,
      Color(0xFF1A6D8A),
    ];
    if (dest.isEmpty) return AppColors.primary;
    return colors[dest.codeUnitAt(0) % colors.length];
  }
}

// ─── ADD PACKING LIST SHEET ───────────────────────────────────────────────────

class _AddPackingListSheet extends ConsumerStatefulWidget {
  const _AddPackingListSheet();

  @override
  ConsumerState<_AddPackingListSheet> createState() =>
      _AddPackingListSheetState();
}

class _AddPackingListSheetState extends ConsumerState<_AddPackingListSheet> {
  final _nameCtrl  = TextEditingController();
  final _destCtrl  = TextEditingController();
  final _destFocus = FocusNode();

  // Destination autocomplete
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<PlaceResult> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounce;
  String _selectedPlace = '';

  DateTime _startDate = DateTime.now();
  DateTime _endDate   = DateTime.now().add(const Duration(days: 6));
  TripType _tripType  = TripType.vacation;

  TripWeather? _tripWeather;
  bool         _weatherLoading = false;
  String?      _weatherError;

  bool    _generating = false;
  String? _validationError;

  Map<String, dynamic>? _selectedTemplate;
  bool _ignoreNextDestChange = false;

  // Trip-linked packing
  String? _linkedTripId;

  void _applyTrip(BudgetModel trip) {
    _ignoreNextDestChange = true;
    _destCtrl.text = trip.destination;
    _selectedPlace  = trip.destination;
    setState(() {
      _linkedTripId = trip.id;
      _startDate    = trip.startDate;
      _endDate      = trip.endDate;
      _validationError = null;
    });
    _removeOverlay();
    _fetchWeather();
  }

  @override
  void initState() {
    super.initState();
    _destFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _nameCtrl.dispose();
    _destCtrl.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  // ── Destination autocomplete ───────────────────────────────────────────────

  PlaceResult _localResult(String name) => PlaceResult(
        placeId: '', name: name, address: '',
        latitude: 0, longitude: 0, rating: 0,
        userRatingsTotal: 0, types: [],
      );

  void _onFocusChange() {
    if (!_destFocus.hasFocus) {
      if (_selectedPlace.isNotEmpty && _destCtrl.text != _selectedPlace) {
        _destCtrl.text = _selectedPlace;
      }
      _removeOverlay();
      if (_destCtrl.text.trim().isNotEmpty) _fetchWeather();
    }
  }

  void _onDestinationChanged(String query) {
    if (_ignoreNextDestChange) { _ignoreNextDestChange = false; return; }
    _selectedPlace = '';
    if (_validationError != null) setState(() => _validationError = null);
    _debounce?.cancel();
    final q = query.trim();
    if (q.length < 2) {
      _removeOverlay();
      setState(() => _suggestions = []);
      return;
    }
    final staticMatches = kDestinations
        .where((d) => d.toLowerCase().contains(q.toLowerCase()))
        .take(6)
        .map(_localResult)
        .toList();
    setState(() => _suggestions = staticMatches);
    if (staticMatches.isNotEmpty && _destFocus.hasFocus) _showOverlay();
    _debounce = Timer(const Duration(milliseconds: 450), () => _searchPlaces(q));
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);
    try {
      // Free geocoding via Open Meteo — works without any API key.
      final geoResults = await ref
          .read(weatherServiceProvider)
          .geocodeCities(query, count: 6);
      if (!mounted) return;
      setState(() => _isSearching = false);

      final merged = geoResults.map((r) {
        final label = r.address.isNotEmpty ? '${r.name}, ${r.address}' : r.name;
        return _localResult(label);
      }).toList();

      // Backfill with static matches not already covered by geo results.
      for (final s in kDestinations
          .where((d) => d.toLowerCase().contains(query.toLowerCase()))
          .take(6)) {
        final cityFirst = s.split(',').first.toLowerCase();
        if (!merged.any((r) => r.name.toLowerCase().contains(cityFirst))) {
          merged.add(_localResult(s));
        }
      }
      if (!mounted) return;
      setState(() => _suggestions = merged.take(6).toList());
      if (_suggestions.isNotEmpty && _destFocus.hasFocus) _showOverlay();
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSuggestion(PlaceResult place) {
    _selectedPlace = place.name;
    _ignoreNextDestChange = true;
    _debounce?.cancel();
    _destCtrl.text = place.name;
    _destCtrl.selection =
        TextSelection.fromPosition(TextPosition(offset: place.name.length));
    _removeOverlay();
    setState(() => _suggestions = []);
    _destFocus.unfocus();
    _fetchWeather();
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: (_) => _buildDropdown());
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildDropdown() {
    return Positioned(
      width: MediaQuery.sizeOf(context).width - 48,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 56),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (_, i) {
                  final place = _suggestions[i];
                  return InkWell(
                    onTap: () => _selectSuggestion(place),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.location_on_rounded,
                                color: AppColors.primary, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place.name,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.navy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (place.address.isNotEmpty) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    place.address,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: AppColors.lightOnSurfaceVar,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.north_west_rounded,
                              size: 13,
                              color: AppColors.lightOnSurfaceVar),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get _duration => _endDate.difference(_startDate).inDays + 1;

  void _applyTemplate(Map<String, dynamic> tpl) {
    setState(() {
      if (_selectedTemplate?['id'] == tpl['id']) {
        // Deselect: clear fields that were filled in from this template.
        final tplName = tpl['name'] as String? ?? '';
        if (_nameCtrl.text == tplName) _nameCtrl.text = '';
        final tDest = tpl['destination'] as String? ?? '';
        if (_destCtrl.text == tDest) {
          _destCtrl.text = '';
          _tripWeather = null;
          _weatherError = null;
        }
        _selectedTemplate = null;
        return;
      }
      _selectedTemplate = tpl;
      if (_nameCtrl.text.isEmpty) {
        _nameCtrl.text = tpl['name'] as String? ?? '';
      }
      final tDest = tpl['destination'] as String? ?? '';
      if (_destCtrl.text.isEmpty && tDest.isNotEmpty) {
        _destCtrl.text = tDest;
        _fetchWeather();
      }
    });
  }

  // ── Auto-fetch weather ─────────────────────────────────────────────────────

  Future<void> _fetchWeather() async {
    final rawDest = _destCtrl.text.trim();
    if (rawDest.isEmpty) return;
    setState(() {
      _weatherLoading = true;
      _weatherError   = null;
      _tripWeather    = null;
    });
    try {
      final svc = ref.read(weatherServiceProvider);
      // Geocoding works best with just the city name. Autocomplete suggestions
      // are stored as "City, State, Country", so strip everything after the
      // first comma and retry with the full string as a fallback.
      final cityOnly = rawDest.split(',').first.trim();
      var geo = await svc.geocodeCity(cityOnly);
      geo ??= await svc.geocodeCity(rawDest);
      if (geo == null) {
        setState(() {
          _weatherError   = 'Could not find "$cityOnly". Check the city name.';
          _weatherLoading = false;
        });
        return;
      }
      final weather = await svc.getWeatherForPeriod(
        lat: geo.lat, lng: geo.lng,
        startDate: _startDate, endDate: _endDate, cityName: geo.name,
      );
      setState(() {
        _tripWeather    = weather;
        _weatherError   = weather == null ? 'Weather data unavailable.' : null;
        _weatherLoading = false;
      });
    } catch (_) {
      setState(() {
        _weatherError   = 'Could not fetch weather. Check your connection.';
        _weatherLoading = false;
      });
    }
  }

  // ── Date pickers ───────────────────────────────────────────────────────────

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate.isBefore(picked)) {
        _endDate = picked.add(const Duration(days: 1));
      }
    });
    if (_destCtrl.text.trim().isNotEmpty) _fetchWeather();
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isAfter(_startDate)
          ? _endDate
          : _startDate.add(const Duration(days: 1)),
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
    if (_destCtrl.text.trim().isNotEmpty) _fetchWeather();
  }

  // ── Generate / Use Template ────────────────────────────────────────────────

  Future<void> _generate() async {
    final name = _nameCtrl.text.trim();
    final dest = _destCtrl.text.trim();

    if (dest.isEmpty) {
      setState(() => _validationError = 'Please enter a destination first.');
      _destFocus.requestFocus();
      return;
    }
    if (name.isEmpty) {
      setState(() => _validationError = 'Please enter a list name.');
      return;
    }
    setState(() => _validationError = null);

    if (_selectedTemplate != null) {
      await _saveFromTemplate(name, dest);
      return;
    }

    if (_tripWeather == null && !_weatherLoading) await _fetchWeather();
    setState(() => _generating = true);

    final weather   = _tripWeather;
    final condition = _parseCondition(weather?.dominantCondition ?? 'sunny');
    final temp      = weather?.avgTemperatureC ?? _seasonalTemp(_startDate.month);

    final input = PackingInput(
      destination: dest,
      startDate: _startDate,
      endDate: _endDate,
      temperature: temp,
      weatherCondition: condition,
      tripType: _tripType,
    );

    final result = PackingEngine.generate(input);
    setState(() => _generating = false);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewPackingSheet(
        listName: name,
        destination: dest,
        result: result,
      ),
    );
  }

  Future<void> _saveFromTemplate(String name, String dest) async {
    setState(() => _generating = true);
    try {
      final rawItems = List<Map<String, dynamic>>.from(
        _selectedTemplate!['items'] as List? ?? [],
      );
      final items = rawItems.asMap().entries.map((e) {
        return {
          ...Map<String, dynamic>.from(e.value),
          'id': 'tpl_${e.key}',
          'packed': false,
        };
      }).toList();

      final listId = await ref.read(packingServiceProvider).savePackingListWithItems(
        name: name,
        destination: dest,
        items: items,
      );

      if (mounted) {
        Navigator.of(context).pop();
        context.push(AppRoutes.packingListOf(listId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(packingTemplatesProvider).value ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (sheetCtx, controller) {
        final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.fromLTRB(
                    24, 12, 24,
                    24 + MediaQuery.of(sheetCtx).viewPadding.bottom,
                  ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withAlpha(18),
                          AppColors.teal.withAlpha(12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primary.withAlpha(30)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.primary, AppColors.teal],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(60),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.luggage_outlined,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Packing List',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Weather-aware · Smart Packing',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.teal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Templates section ──────────────────────────────────────
                  if (templates.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildTemplateSection(templates),
                  ],

                  const SizedBox(height: 20),

                  // ── Pack for a Trip ────────────────────────────────────────
                  _buildTripPicker(),

                  const SizedBox(height: 20),

                  // ── List Name ──────────────────────────────────────────────
                  _sectionLabel('List Name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(fontFamily: 'Poppins'),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    onChanged: (_) {
                      if (_validationError != null) setState(() => _validationError = null);
                    },
                    decoration: _inputDecoration(
                        'e.g. Goa Beach Trip', Icons.luggage_outlined),
                  ),
                  const SizedBox(height: 20),

                  // ── Destination ────────────────────────────────────────────
                  _sectionLabel('Destination'),
                  const SizedBox(height: 8),
                  CompositedTransformTarget(
                    link: _layerLink,
                    child: TextField(
                      controller: _destCtrl,
                      focusNode: _destFocus,
                      style: const TextStyle(fontFamily: 'Poppins'),
                      textInputAction: TextInputAction.done,
                      onChanged: _onDestinationChanged,
                      onSubmitted: (_) => _fetchWeather(),
                      decoration: _inputDecoration(
                        'Search a city...', Icons.place_outlined,
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.primary),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Travel Dates ───────────────────────────────────────────
                  _sectionLabel('Travel Dates'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _dateTile(
                          label: 'Start',
                          date: _startDate,
                          onTap: _pickStartDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateTile(
                          label: 'End',
                          date: _endDate,
                          onTap: _pickEndDate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_duration day${_duration == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  // ── Weather + Trip Type (hidden when using template) ────────
                  if (_selectedTemplate == null) ...[
                    const SizedBox(height: 20),
                    _buildWeatherCard(),
                    const SizedBox(height: 20),
                    _sectionLabel('Trip Type'),
                    const SizedBox(height: 10),
                    _chipRow<TripType>(
                      options: TripType.values,
                      selected: _tripType,
                      label: _tripLabel,
                      icon: _tripIcon,
                      color: AppColors.teal,
                      onSelect: (v) => setState(() => _tripType = v),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Inline validation error ──────────────────────────────
                  if (_validationError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.warning.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.warning, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _validationError!,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // ── Action button ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: _generating
                        ? ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            ),
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.teal],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(80),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _generate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _selectedTemplate != null
                                        ? Icons.content_copy_outlined
                                        : Icons.checklist_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedTemplate != null
                                        ? 'Create from Template'
                                        : 'Generate Packing List',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),

                ],
              ),
            ),
          ],
        ),
        ),
      );
      },
    );
  }

  // ── Trip picker ────────────────────────────────────────────────────────────

  Widget _buildTripPicker() {
    final allTrips = ref.watch(allTripsProvider).valueOrNull ?? [];
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final trips = allTrips.where((t) {
      if (t.completedAt != null) return false;
      final end = DateTime(t.endDate.year, t.endDate.month, t.endDate.day);
      return !end.isBefore(today); // active or upcoming
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    if (trips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Pack for a Trip'),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: trips.length,
            separatorBuilder: (context, i) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final trip   = trips[i];
              final picked = _linkedTripId == trip.id;
              final start  = trip.startDate;
              final end    = trip.endDate;
              final fmt    = '${start.day} ${_mon(start.month)} – ${end.day} ${_mon(end.month)}';
              final isActive = !DateTime(start.year, start.month, start.day).isAfter(today) &&
                               !DateTime(end.year, end.month, end.day).isBefore(today);

              return GestureDetector(
                onTap: () => _applyTrip(trip),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: picked ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: picked
                          ? AppColors.primary
                          : isActive
                              ? AppColors.success.withAlpha(120)
                              : AppColors.lightOutline,
                      width: picked ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: picked
                            ? AppColors.primary.withAlpha(40)
                            : Colors.black.withAlpha(6),
                        blurRadius: picked ? 10 : 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flight_takeoff_rounded,
                            size: 12,
                            color: picked
                                ? Colors.white70
                                : isActive
                                    ? AppColors.success
                                    : AppColors.lightOnSurfaceVar,
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              trip.destination.split(',').first,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: picked ? Colors.white : AppColors.navy,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (picked) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle_rounded,
                                size: 14, color: Colors.white),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fmt,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: picked
                              ? Colors.white70
                              : AppColors.lightOnSurfaceVar,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.lightOutline, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or fill manually',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.lightOnSurfaceVar.withAlpha(180),
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.lightOutline, height: 1)),
          ],
        ),
      ],
    );
  }

  String _mon(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  // ── Template section ───────────────────────────────────────────────────────

  Widget _buildTemplateSection(List<Map<String, dynamic>> templates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bookmark_outline_rounded, size: 15, color: AppColors.primary),
            SizedBox(width: 6),
            Text(
              'Start from a Template',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final tpl        = templates[i];
              final isSelected = _selectedTemplate?['id'] == tpl['id'];
              final dest       = tpl['destination'] as String? ?? '';
              final count      = (tpl['items'] as List?)?.length ?? 0;
              return GestureDetector(
                onTap: () => _applyTemplate(tpl),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(maxWidth: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withAlpha(15)
                        : Colors.white,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.lightOutline,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 13),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              tpl['name'] as String? ?? 'Template',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dest.isNotEmpty ? '$dest · $count items' : '$count items',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.lightOnSurfaceVar,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        const Divider(),
      ],
    );
  }

  // ── Weather card ───────────────────────────────────────────────────────────

  Widget _buildWeatherCard() {
    if (_weatherLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightOutline),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 12),
            Text(
              'Fetching weather for your trip…',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.lightOnSurfaceVar,
              ),
            ),
          ],
        ),
      );
    }

    if (_weatherError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withAlpha(60)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _weatherError!,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, color: AppColors.warning),
              ),
            ),
            TextButton(
              onPressed: _fetchWeather,
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text(
                'Retry',
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    }

    if (_tripWeather != null) {
      final w         = _tripWeather!;
      final cond      = w.dominantCondition;
      final icon      = _conditionIcon(cond);
      final color     = _conditionColor(cond);
      final tempColor = _tempColor(w.avgTemperatureC);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: color.withAlpha(25), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.cityName,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_conditionLabel(cond)} · avg ${w.avgTemperatureC.round()}°C',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.lightOnSurfaceVar,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tempColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${w.avgTemperatureC.round()}°C',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: tempColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightOutline),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_sync_outlined,
              color: AppColors.lightOnSurfaceVar, size: 18),
          SizedBox(width: 10),
          Text(
            'Weather will be detected after you enter\na destination and press done.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppColors.lightOnSurfaceVar,
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ],
      );

  InputDecoration _inputDecoration(String hint, IconData icon,
          {Widget? suffixIcon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'Poppins', color: AppColors.lightOnSurfaceVar),
        prefixIcon: Icon(icon, color: AppColors.lightOnSurfaceVar, size: 20),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Widget _dateTile({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(8),
          border: Border.all(color: AppColors.primary.withAlpha(50)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_today_outlined,
                  color: AppColors.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.lightOnSurfaceVar,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.day} ${_monthShort(date.month)} ${date.year}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipRow<T>({
    required List<T> options,
    required T selected,
    required String Function(T) label,
    required IconData Function(T) icon,
    required Color color,
    required void Function(T) onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? color.withAlpha(22) : Colors.white,
              border: Border.all(
                color: isSelected ? color : AppColors.lightOutline,
                width: isSelected ? 1.8 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withAlpha(35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon(opt),
                    size: 17,
                    color: isSelected ? color : AppColors.lightOnSurfaceVar),
                const SizedBox(width: 7),
                Text(
                  label(opt),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? color : AppColors.lightOnSurfaceVar,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Pure helpers ───────────────────────────────────────────────────────────

  Color _tempColor(double temp) {
    if (temp < 5) return AppColors.purple;
    if (temp < 15) return AppColors.primary;
    if (temp < 30) return AppColors.success;
    return AppColors.danger;
  }

  IconData _conditionIcon(String c) => switch (c) {
        'rainy' => Icons.umbrella_outlined,
        'snowy' => Icons.ac_unit_rounded,
        'cloudy' => Icons.cloud_outlined,
        _ => Icons.wb_sunny_outlined,
      };

  Color _conditionColor(String c) => switch (c) {
        'rainy' => AppColors.primary,
        'snowy' => AppColors.purple,
        'cloudy' => AppColors.lightOnSurfaceVar,
        _ => AppColors.warning,
      };

  String _conditionLabel(String c) => switch (c) {
        'rainy' => 'Rainy',
        'snowy' => 'Snowy',
        'cloudy' => 'Cloudy',
        _ => 'Sunny',
      };

  WeatherCondition _parseCondition(String c) => switch (c) {
        'rainy' => WeatherCondition.rainy,
        'snowy' => WeatherCondition.snowy,
        'cloudy' => WeatherCondition.cloudy,
        _ => WeatherCondition.sunny,
      };

  double _seasonalTemp(int month) {
    const temps = [
      8.0, 10.0, 14.0, 18.0, 23.0, 27.0,
      30.0, 29.0, 25.0, 20.0, 14.0, 9.0,
    ];
    return temps[month - 1];
  }

  String _tripLabel(TripType t) => switch (t) {
        TripType.vacation => 'Vacation',
        TripType.business => 'Business',
        TripType.trekking => 'Trekking',
        TripType.beach    => 'Beach',
      };

  IconData _tripIcon(TripType t) => switch (t) {
        TripType.vacation => Icons.landscape_outlined,
        TripType.business => Icons.business_center_outlined,
        TripType.trekking => Icons.hiking_outlined,
        TripType.beach    => Icons.beach_access_outlined,
      };

  String _monthShort(int m) => const [
        '',
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m];
}

// ─── REVIEW PACKING SHEET ────────────────────────────────────────────────────
// Shown after engine-generated list. User toggles items before saving.

class _ReviewPackingSheet extends ConsumerStatefulWidget {
  const _ReviewPackingSheet({
    required this.listName,
    required this.destination,
    required this.result,
  });

  final String listName;
  final String destination;
  final PackingResult result;

  @override
  ConsumerState<_ReviewPackingSheet> createState() =>
      _ReviewPackingSheetState();
}

class _ReviewPackingSheetState extends ConsumerState<_ReviewPackingSheet> {
  late Map<String, Map<String, bool>> _selected;
  bool _saving = false;

  static const _categoryOrder = [
    'documents', 'clothing', 'essentials',
    'toiletries', 'electronics', 'miscellaneous',
  ];

  @override
  void initState() {
    super.initState();
    _selected = {};
    for (final item in widget.result.all) {
      _selected.putIfAbsent(item.category, () => {})[item.name] = true;
    }
  }


  int get _selectedCount =>
      _selected.values.expand((m) => m.values).where((v) => v).length;

  bool _allInCategory(String cat) =>
      (_selected[cat] ?? {}).values.every((v) => v);

  void _toggleItem(String cat, String name) {
    setState(() => _selected[cat]![name] = !(_selected[cat]![name] ?? true));
  }

  void _toggleCategory(String cat) {
    final allOn = _allInCategory(cat);
    setState(() {
      for (final k in (_selected[cat] ?? {}).keys) {
        _selected[cat]![k] = !allOn;
      }
    });
  }

  Future<void> _save() async {
    if (_selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one item.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final items = <Map<String, dynamic>>[];
      int idx = 0;
      for (final item in widget.result.all) {
        if (_selected[item.category]?[item.name] == true) {
          items.add({
            'id': 'rule_${idx++}',
            'name': item.name,
            'category': item.category,
            'quantity': 1,
            'isImportant': item.isImportant,
            'packed': false,
          });
        }
      }

      final listId = await ref.read(packingServiceProvider).savePackingListWithItems(
        name: widget.listName,
        destination: widget.destination,
        items: items,
      );

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
        context.push(AppRoutes.packingListOf(listId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<PackingItem>>{};
    for (final cat in _categoryOrder) {
      final items = widget.result.all.where((i) => i.category == cat).toList();
      if (items.isNotEmpty) grouped[cat] = items;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightOutline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review Suggestions',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Uncheck items you don\'t need · $_selectedCount selected',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.lightOnSurfaceVar,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final cat in _selected.values) {
                          for (final k in cat.keys) { cat[k] = true; }
                        }
                      });
                    },
                    child: const Text(
                      'All',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                children: grouped.entries
                    .map((e) => _buildCategorySection(e.key, e.value))
                    .toList(),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                  24, 12, 24,
                  MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'Add $_selectedCount items to my list',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String category, List<PackingItem> items) {
    final allOn        = _allInCategory(category);
    final color        = _categoryColor(category);
    final selectedInCat =
        items.where((i) => _selected[category]?[i.name] == true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _toggleCategory(category),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text(
                  _capitalize(category),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$selectedInCat/${items.length}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.lightOnSurfaceVar,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _toggleCategory(category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: allOn ? color.withAlpha(20) : AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: allOn ? color : AppColors.lightOutline),
                    ),
                    child: Text(
                      allOn ? 'Deselect all' : 'Select all',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: allOn ? color : AppColors.lightOnSurfaceVar,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ...items.map((item) {
          final isOn = _selected[category]?[item.name] ?? true;
          return InkWell(
            onTap: () => _toggleItem(category, item.name),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isOn ? Colors.white : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOn ? AppColors.lightOutline : AppColors.lightOutlineVar,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isOn ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isOn ? AppColors.primary : AppColors.lightOutline,
                        width: 1.5,
                      ),
                    ),
                    child: isOn
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isOn ? AppColors.navy : AppColors.lightOnSurfaceVar,
                        decoration: isOn ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                  if (item.isImportant)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Must',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        const Divider(height: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  Color _categoryColor(String cat) => switch (cat) {
        'clothing'     => AppColors.success,
        'essentials'   => AppColors.danger,
        'toiletries'   => AppColors.teal,
        'electronics'  => AppColors.purple,
        'documents'    => AppColors.primary,
        _              => AppColors.warning,
      };

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// kDestinations is imported from lib/shared/data/destinations_data.dart

