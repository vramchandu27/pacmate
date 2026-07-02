import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import '../../../core/api/places_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/api/weather_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/data/destinations_data.dart';
import '../../../shared/models/currency_data.dart';
import '../services/budget_service.dart';

// ─── CREATE TRIP SCREEN ───────────────────────────────────────────────────────

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _destinationCtrl   = TextEditingController();
  final _budgetCtrl        = TextEditingController();
  final _destinationFocus  = FocusNode();
  final _budgetFocus       = FocusNode();

  // Overlay
  final _layerLink         = LayerLink();
  OverlayEntry?            _overlayEntry;

  // Places search
  List<PlaceResult>        _suggestions   = [];
  bool                     _isSearching   = false;
  Timer?                   _debounce;
  String                   _selectedPlace = '';

  // Form state
  DateTime  _startDate = DateTime.now();
  DateTime  _endDate   = DateTime.now().add(const Duration(days: 7));
  String    _currency  = 'INR';
  bool      _isLoading = false;

  // Success overlay
  bool   _showSuccess      = false;
  String _createdDestination = '';

  // Carousel
  final _carouselCtrl = PageController();
  Timer?  _carouselTimer;
  int     _carouselPage = 0;

  static const _carouselImages = [
    'assets/images/pexels-alexmoliski-21319260.jpg',
    'assets/images/pexels-george-pak-7969114.jpg',
    'assets/images/pexels-ravirawat-1294731.jpg',
  ];

  CurrencyEntry get _currencyEntry =>
      kAllCurrencies.firstWhere((c) => c.code == _currency,
          orElse: () => kAllCurrencies.first);

  int get _tripDays => _endDate.difference(_startDate).inDays + 1;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _destinationFocus.addListener(_onFocusChange);
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_carouselPage + 1) % _carouselImages.length;
      _carouselCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselCtrl.dispose();
    _debounce?.cancel();
    _removeOverlay();
    _destinationFocus.removeListener(_onFocusChange);
    _destinationFocus.dispose();
    _budgetFocus.dispose();
    _destinationCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_destinationFocus.hasFocus) {
      // If user blurred without picking, restore selected value or clear
      if (_selectedPlace.isNotEmpty &&
          _destinationCtrl.text != _selectedPlace) {
        _destinationCtrl.text = _selectedPlace;
      }
      _removeOverlay();
    }
  }

  // ── Places search ─────────────────────────────────────────────────────────

  PlaceResult _localResult(String name) => PlaceResult(
        placeId: '',
        name: name,
        address: '',
        latitude: 0,
        longitude: 0,
        rating: 0,
        userRatingsTotal: 0,
        types: [],
      );

  void _onDestinationChanged(String query) {
    _selectedPlace = '';
    _debounce?.cancel();
    final q = query.trim();
    if (q.length < 2) {
      _removeOverlay();
      setState(() => _suggestions = []);
      return;
    }

    // Show static matches instantly — no API call needed
    final staticMatches = kDestinations
        .where((d) => d.toLowerCase().contains(q.toLowerCase()))
        .take(6)
        .map(_localResult)
        .toList();

    setState(() => _suggestions = staticMatches);
    if (staticMatches.isNotEmpty && _destinationFocus.hasFocus) {
      _showOverlay();
    }

    // Also try API in background; merge if results arrive
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _searchPlaces(q);
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);
    try {
      // Open Meteo geocoding — cities and countries only, no stores/businesses.
      final geoResults = await ref
          .read(weatherServiceProvider)
          .geocodeCities(query, count: 6);
      if (!mounted) return;
      setState(() => _isSearching = false);

      final merged = geoResults.map((r) {
        final label = r.address.isNotEmpty ? '${r.name}, ${r.address}' : r.name;
        return _localResult(label);
      }).toList();

      // Backfill with static matches not already covered.
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
      if (_suggestions.isNotEmpty && _destinationFocus.hasFocus) {
        _showOverlay();
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSuggestion(PlaceResult place) {
    _selectedPlace = place.name;
    _destinationCtrl.text = place.name;
    _destinationCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: place.name.length),
    );
    _removeOverlay();
    setState(() => _suggestions = []);
    _budgetFocus.requestFocus();
  }

  // ── Overlay ───────────────────────────────────────────────────────────────

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(builder: (_) => _buildDropdown());
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildDropdown() {
    return Positioned(
      width: MediaQuery.sizeOf(context).width - 40,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 60), // just below the text field
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
                itemBuilder: (_, i) {
                  final place = _suggestions[i];
                  return InkWell(
                    onTap: () => _selectSuggestion(place),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryAlpha10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.navy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (place.address.isNotEmpty) ...[
                                  const SizedBox(height: 2),
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
                              size: 14, color: AppColors.lightOnSurfaceVar),
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

  // ── Date pickers ──────────────────────────────────────────────────────────

  Future<void> _pickDate({required bool isStart}) async {
    // End-date picker's firstDate is _startDate so the calendar
    // physically prevents selecting a date before the trip starts.
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: isStart
          ? DateTime.now().subtract(const Duration(days: 365))
          : _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        // If the new start pushes past the end, auto-advance end by 7 days.
        if (!_endDate.isAfter(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 7));
        }
      } else {
        _endDate = picked; // picker already enforces picked >= _startDate
      }
    });
  }

  // ── Currency picker ───────────────────────────────────────────────────────

  Future<void> _pickCurrency() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CurrencySheet(
        selected: _currency,
        onSelect: (code) {
          setState(() => _currency = code);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Final safety check — end date must be same day or after start date.
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'End date cannot be before start date.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Check for overlapping trips
    final existingTrips = ref.read(allTripsProvider).valueOrNull ?? [];
    final newStart = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final newEnd   = DateTime(_endDate.year,   _endDate.month,   _endDate.day);

    final conflict = existingTrips.where((t) {
      if (t.completedAt != null) return false;
      final tStart = DateTime(t.startDate.year, t.startDate.month, t.startDate.day);
      final tEnd   = DateTime(t.endDate.year,   t.endDate.month,   t.endDate.day);
      return !tStart.isAfter(newEnd) && !tEnd.isBefore(newStart);
    }).firstOrNull;

    if (conflict != null && mounted) {
      final fmt = DateFormat('d MMM');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
              SizedBox(width: 8),
              Text(
                'Trip Already Planned',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          content: Text(
            'You already have a trip to ${conflict.destination} planned from '
            '${fmt.format(conflict.startDate)} – ${fmt.format(conflict.endDate)}. '
            'These dates overlap.\n\nDo you still want to create this trip?',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.lightOnSurfaceVar,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Change Dates',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightOnSurfaceVar,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Create Anyway',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
    }

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(budgetServiceProvider).createTrip(
            destination: _destinationCtrl.text.trim(),
            startDate: _startDate,
            endDate: _endDate,
            totalBudget: double.parse(_budgetCtrl.text.trim()),
            currency: _currency,
          );
      if (!mounted) return;
      setState(() {
        _showSuccess       = true;
        _createdDestination = _destinationCtrl.text.trim();
        _isLoading         = false;
      });
      await Future.delayed(const Duration(milliseconds: 2800));
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to create trip: $e',
              style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq   = MediaQuery.sizeOf(context);
    final w    = mq.width;
    final h    = mq.height;
    final hp        = (w * 0.05).clamp(14.0, 24.0);
    final sp        = (h * 0.026).clamp(16.0, 28.0);
    final fmt       = w < 360 ? DateFormat('d MMM') : DateFormat('d MMM yyyy');
    final fzBody    = w < 360 ? 13.0 : 15.0;
    final fzHint    = w < 360 ? 12.0 : 14.0;
    final carouselH = (h * 0.30).clamp(180.0, 300.0);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'New Trip',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: w < 360 ? 16.0 : 18.0,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hp, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Travel inspiration carousel ───────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: carouselH,
                  child: PageView.builder(
                    controller: _carouselCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _carouselImages.length,
                    onPageChanged: (i) => setState(() => _carouselPage = i),
                    itemBuilder: (_, i) => Image.asset(
                      _carouselImages[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_carouselImages.length, (i) {
                  final active = i == _carouselPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.lightOutline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              SizedBox(height: sp),

              // ── Destination ─────────────────────────────────────────────────
              _sectionLabel('Where to?', Icons.explore_rounded),
              const SizedBox(height: 10),
              CompositedTransformTarget(
                link: _layerLink,
                child: TextFormField(
                  controller: _destinationCtrl,
                  focusNode: _destinationFocus,
                  textInputAction: TextInputAction.next,
                  onChanged: _onDestinationChanged,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: fzBody,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search a city or country...',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: fzHint,
                      color: AppColors.lightOnSurfaceVar,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.location_on_outlined,
                        color: AppColors.primary),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : _destinationCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close,
                                    color: AppColors.lightOnSurfaceVar,
                                    size: 18),
                                onPressed: () {
                                  _destinationCtrl.clear();
                                  _selectedPlace = '';
                                  _removeOverlay();
                                  setState(() => _suggestions = []);
                                },
                              )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.lightOutline, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.lightOutline, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.danger, width: 1),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.danger, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a destination' : null,
                ),
              ),

              SizedBox(height: sp),

              // ── Dates ────────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                      child: _sectionLabel(
                          'Travel Dates', Icons.calendar_month_rounded)),
                  // Duration badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAlpha10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_tripDays ${_tripDays == 1 ? 'day' : 'days'}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _dateCard(
                      label: 'Start Date',
                      value: fmt.format(_startDate),
                      icon: Icons.flight_takeoff_rounded,
                      iconColor: AppColors.primary,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateCard(
                      label: 'End Date',
                      value: fmt.format(_endDate),
                      icon: Icons.flight_land_rounded,
                      iconColor: AppColors.teal,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),

              SizedBox(height: sp),

              // ── Budget ───────────────────────────────────────────────────────
              _sectionLabel('Budget', Icons.account_balance_wallet_rounded),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _budgetCtrl,
                      focusNode: _budgetFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: fzBody,
                        fontWeight: FontWeight.w500,
                        color: AppColors.navy,
                      ),
                      decoration: InputDecoration(
                        hintText: '50,000',
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: fzHint,
                          color: AppColors.lightOnSurfaceVar,
                        ),
                        prefixText: '${_currencyEntry.symbol}  ',
                        prefixStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: fzBody,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.lightOutline, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.lightOutline, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.danger, width: 1),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.danger, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter budget';
                        }
                        if (double.tryParse(v.trim()) == null) {
                          return 'Invalid number';
                        }
                        if ((double.tryParse(v.trim()) ?? 0) <= 0) {
                          return 'Must be > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Currency picker
                  GestureDetector(
                    onTap: _pickCurrency,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.lightOutline, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_currencyEntry.flag,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text(
                            _currency,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: AppColors.lightOnSurfaceVar),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: AppColors.lightOnSurfaceVar),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Set your home currency. Expenses abroad convert automatically.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: AppColors.lightOnSurfaceVar,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: sp * 1.4),

              // ── Create Button ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF2563EB)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    color: _isLoading
                        ? AppColors.lightOutline
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isLoading
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(70),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.rocket_launch_rounded, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Create Trip',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

            ],
          ),
        ),
      ),
          // ── Success overlay ────────────────────────────────────────────────
          if (_showSuccess)
            AnimatedOpacity(
              opacity: _showSuccess ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dark backdrop
                  Container(color: Colors.black54),
                  // Confetti on top of everything
                  IgnorePointer(
                    child: Lottie.asset(
                      'assets/animations/confetti.json',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  // Success card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 36),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppColors.success,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Trip Created!',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Get ready for\n$_createdDestination!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            color: AppColors.lightOnSurfaceVar,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go(AppRoutes.home),
                            icon: const Icon(Icons.dashboard_rounded, size: 18),
                            label: const Text(
                              'Go to Dashboard',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }

  Widget _dateCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightOutline),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
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
                    value,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.lightOnSurfaceVar),
          ],
        ),
      ),
    );
  }
}

// ─── POPULAR DESTINATIONS (now imported from shared/data/destinations_data.dart)
// The list below is kept temporarily as dead code; remove after confirming build.
// ignore: unused_element
const List<String> _kDestinationsLegacy = [
  'Mumbai, Maharashtra, India',
  'Delhi, India',
  'Bengaluru, Karnataka, India',
  'Hyderabad, Telangana, India',
  'Chennai, Tamil Nadu, India',
  'Kolkata, West Bengal, India',
  'Pune, Maharashtra, India',
  'Ahmedabad, Gujarat, India',
  'Surat, Gujarat, India',
  'Jaipur, Rajasthan, India',
  'Lucknow, Uttar Pradesh, India',
  'Kanpur, Uttar Pradesh, India',
  'Nagpur, Maharashtra, India',
  'Indore, Madhya Pradesh, India',
  'Bhopal, Madhya Pradesh, India',
  'Patna, Bihar, India',
  'Vadodara, Gujarat, India',
  'Coimbatore, Tamil Nadu, India',
  'Visakhapatnam, Andhra Pradesh, India',
  'Vijayawada, Andhra Pradesh, India',
  'Thiruvananthapuram, Kerala, India',
  'Kochi, Kerala, India',
  'Madurai, Tamil Nadu, India',
  'Bhubaneswar, Odisha, India',
  'Ranchi, Jharkhand, India',
  'Guwahati, Assam, India',
  'Chandigarh, India',
  'Amritsar, Punjab, India',
  'Jalandhar, Punjab, India',
  'Ludhiana, Punjab, India',
  'Agra, Uttar Pradesh, India',
  'Varanasi, Uttar Pradesh, India',
  'Allahabad, Uttar Pradesh, India',
  'Jodhpur, Rajasthan, India',
  'Udaipur, Rajasthan, India',
  'Ajmer, Rajasthan, India',
  'Jaisalmer, Rajasthan, India',
  'Pushkar, Rajasthan, India',
  'Bikaner, Rajasthan, India',
  'Kota, Rajasthan, India',
  'Mysore, Karnataka, India',
  'Mangalore, Karnataka, India',
  'Hubli, Karnataka, India',
  'Hampi, Karnataka, India',
  'Badami, Karnataka, India',
  'Tirupati, Andhra Pradesh, India',
  'Warangal, Telangana, India',
  'Aurangabad, Maharashtra, India',
  'Nashik, Maharashtra, India',
  'Kolhapur, Maharashtra, India',
  // ── India – Hill Stations ─────────────────────────────────────────────────
  'Shimla, Himachal Pradesh, India',
  'Manali, Himachal Pradesh, India',
  'Dharamshala, Himachal Pradesh, India',
  'McLeod Ganj, Himachal Pradesh, India',
  'Kasauli, Himachal Pradesh, India',
  'Spiti Valley, Himachal Pradesh, India',
  'Kullu, Himachal Pradesh, India',
  'Dalhousie, Himachal Pradesh, India',
  'Mussoorie, Uttarakhand, India',
  'Nainital, Uttarakhand, India',
  'Rishikesh, Uttarakhand, India',
  'Haridwar, Uttarakhand, India',
  'Dehradun, Uttarakhand, India',
  'Auli, Uttarakhand, India',
  'Chopta, Uttarakhand, India',
  'Lansdowne, Uttarakhand, India',
  'Ranikhet, Uttarakhand, India',
  'Ooty, Tamil Nadu, India',
  'Kodaikanal, Tamil Nadu, India',
  'Munnar, Kerala, India',
  'Wayanad, Kerala, India',
  'Coorg, Karnataka, India',
  'Chikmagalur, Karnataka, India',
  'Mahabaleshwar, Maharashtra, India',
  'Lonavala, Maharashtra, India',
  'Matheran, Maharashtra, India',
  'Panchgani, Maharashtra, India',
  'Darjeeling, West Bengal, India',
  'Kalimpong, West Bengal, India',
  'Shillong, Meghalaya, India',
  'Cherrapunji, Meghalaya, India',
  'Gangtok, Sikkim, India',
  'Pelling, Sikkim, India',
  'Lachung, Sikkim, India',
  'Leh, Ladakh, India',
  'Nubra Valley, Ladakh, India',
  'Pangong Lake, Ladakh, India',
  'Kargil, Ladakh, India',
  'Srinagar, Jammu & Kashmir, India',
  'Gulmarg, Jammu & Kashmir, India',
  'Pahalgam, Jammu & Kashmir, India',
  'Sonamarg, Jammu & Kashmir, India',
  // ── India – Beaches ───────────────────────────────────────────────────────
  'Goa, India',
  'North Goa, India',
  'South Goa, India',
  'Panjim, Goa, India',
  'Calangute, Goa, India',
  'Baga, Goa, India',
  'Varkala, Kerala, India',
  'Kovalam, Kerala, India',
  'Alleppey, Kerala, India',
  'Kumarakom, Kerala, India',
  'Rameswaram, Tamil Nadu, India',
  'Mahabalipuram, Tamil Nadu, India',
  'Pondicherry, Tamil Nadu, India',
  'Andaman and Nicobar Islands, India',
  'Port Blair, Andaman, India',
  'Havelock Island, Andaman, India',
  'Neil Island, Andaman, India',
  'Lakshadweep, India',
  'Diu, India',
  'Dwarka, Gujarat, India',
  'Somnath, Gujarat, India',
  'Tarkarli, Maharashtra, India',
  'Alibaug, Maharashtra, India',
  'Puri, Odisha, India',
  'Konark, Odisha, India',
  // ── India – Heritage & Pilgrimage ─────────────────────────────────────────
  'Khajuraho, Madhya Pradesh, India',
  'Orchha, Madhya Pradesh, India',
  'Ujjain, Madhya Pradesh, India',
  'Sanchi, Madhya Pradesh, India',
  'Bodh Gaya, Bihar, India',
  'Nalanda, Bihar, India',
  'Mathura, Uttar Pradesh, India',
  'Vrindavan, Uttar Pradesh, India',
  'Ayodhya, Uttar Pradesh, India',
  'Sarnath, Uttar Pradesh, India',
  'Kedarnath, Uttarakhand, India',
  'Badrinath, Uttarakhand, India',
  'Char Dham, Uttarakhand, India',
  'Dwarka, Gujarat, India',
  'Shirdi, Maharashtra, India',
  'Trimbakeshwar, Maharashtra, India',
  'Madurai, Tamil Nadu, India',
  'Kanyakumari, Tamil Nadu, India',
  'Tiruvannamalai, Tamil Nadu, India',
  'Chidambaram, Tamil Nadu, India',
  'Thanjavur, Tamil Nadu, India',
  'Guruvayur, Kerala, India',
  'Sabarimala, Kerala, India',
  'Hampi, Karnataka, India',
  'Belur, Karnataka, India',
  'Halebidu, Karnataka, India',
  'Pattadakal, Karnataka, India',
  // ── India – Wildlife & Nature ─────────────────────────────────────────────
  'Jim Corbett National Park, India',
  'Ranthambore National Park, India',
  'Bandhavgarh National Park, India',
  'Kanha National Park, India',
  'Pench National Park, India',
  'Kaziranga National Park, Assam, India',
  'Sundarbans, West Bengal, India',
  'Periyar Wildlife Sanctuary, Kerala, India',
  'Nagarhole, Karnataka, India',
  'Bandipur National Park, Karnataka, India',
  'Panna National Park, India',
  'Gir National Park, Gujarat, India',
  'Valley of Flowers, Uttarakhand, India',
  'Spiti Valley, Himachal Pradesh, India',
  'Meghalaya, India',
  'Arunachal Pradesh, India',
  'Tawang, Arunachal Pradesh, India',
  // ── Southeast Asia ────────────────────────────────────────────────────────
  'Bangkok, Thailand',
  'Chiang Mai, Thailand',
  'Chiang Rai, Thailand',
  'Phuket, Thailand',
  'Pattaya, Thailand',
  'Koh Samui, Thailand',
  'Krabi, Thailand',
  'Pai, Thailand',
  'Bali, Indonesia',
  'Jakarta, Indonesia',
  'Yogyakarta, Indonesia',
  'Lombok, Indonesia',
  'Komodo Island, Indonesia',
  'Raja Ampat, Indonesia',
  'Kuala Lumpur, Malaysia',
  'Penang, Malaysia',
  'Langkawi, Malaysia',
  'Kota Kinabalu, Malaysia',
  'Singapore',
  'Hanoi, Vietnam',
  'Ho Chi Minh City, Vietnam',
  'Hoi An, Vietnam',
  'Da Nang, Vietnam',
  'Halong Bay, Vietnam',
  'Siem Reap, Cambodia',
  'Phnom Penh, Cambodia',
  'Angkor Wat, Cambodia',
  'Vientiane, Laos',
  'Luang Prabang, Laos',
  'Yangon, Myanmar',
  'Bagan, Myanmar',
  'Manila, Philippines',
  'Cebu, Philippines',
  'Palawan, Philippines',
  'Boracay, Philippines',
  // ── East Asia ─────────────────────────────────────────────────────────────
  'Tokyo, Japan',
  'Kyoto, Japan',
  'Osaka, Japan',
  'Hiroshima, Japan',
  'Nara, Japan',
  'Hokkaido, Japan',
  'Seoul, South Korea',
  'Busan, South Korea',
  'Jeju Island, South Korea',
  'Beijing, China',
  'Shanghai, China',
  'Guangzhou, China',
  'Chengdu, China',
  'Guilin, China',
  'Zhangjiajie, China',
  'Xi\'an, China',
  'Hong Kong',
  'Macau',
  'Taipei, Taiwan',
  'Ulaanbaatar, Mongolia',
  // ── South Asia ────────────────────────────────────────────────────────────
  'Kathmandu, Nepal',
  'Pokhara, Nepal',
  'Chitwan, Nepal',
  'Colombo, Sri Lanka',
  'Kandy, Sri Lanka',
  'Sigiriya, Sri Lanka',
  'Galle, Sri Lanka',
  'Dhaka, Bangladesh',
  'Cox\'s Bazar, Bangladesh',
  'Thimphu, Bhutan',
  'Paro, Bhutan',
  'Punakha, Bhutan',
  'Karachi, Pakistan',
  'Lahore, Pakistan',
  'Islamabad, Pakistan',
  // ── Middle East ───────────────────────────────────────────────────────────
  'Dubai, UAE',
  'Abu Dhabi, UAE',
  'Sharjah, UAE',
  'Muscat, Oman',
  'Doha, Qatar',
  'Kuwait City, Kuwait',
  'Riyadh, Saudi Arabia',
  'Jeddah, Saudi Arabia',
  'Istanbul, Turkey',
  'Cappadocia, Turkey',
  'Antalya, Turkey',
  'Bodrum, Turkey',
  'Tel Aviv, Israel',
  'Jerusalem, Israel',
  'Amman, Jordan',
  'Petra, Jordan',
  'Cairo, Egypt',
  'Luxor, Egypt',
  'Hurghada, Egypt',
  'Sharm El Sheikh, Egypt',
  // ── Europe ────────────────────────────────────────────────────────────────
  'London, UK',
  'Paris, France',
  'Barcelona, Spain',
  'Madrid, Spain',
  'Rome, Italy',
  'Venice, Italy',
  'Florence, Italy',
  'Milan, Italy',
  'Amsterdam, Netherlands',
  'Berlin, Germany',
  'Munich, Germany',
  'Vienna, Austria',
  'Prague, Czech Republic',
  'Budapest, Hungary',
  'Warsaw, Poland',
  'Athens, Greece',
  'Santorini, Greece',
  'Mykonos, Greece',
  'Lisbon, Portugal',
  'Porto, Portugal',
  'Stockholm, Sweden',
  'Copenhagen, Denmark',
  'Oslo, Norway',
  'Helsinki, Finland',
  'Reykjavik, Iceland',
  'Zurich, Switzerland',
  'Geneva, Switzerland',
  'Interlaken, Switzerland',
  'Brussels, Belgium',
  'Dubrovnik, Croatia',
  'Split, Croatia',
  'Ljubljana, Slovenia',
  'Edinburgh, Scotland',
  'Dublin, Ireland',
  'Valletta, Malta',
  'Nice, France',
  'Monaco',
  'Tallinn, Estonia',
  'Riga, Latvia',
  'Vilnius, Lithuania',
  'Krakow, Poland',
  'Bratislava, Slovakia',
  'Bruges, Belgium',
  'Tbilisi, Georgia',
  'Baku, Azerbaijan',
  'Yerevan, Armenia',
  // ── Americas ─────────────────────────────────────────────────────────────
  'New York, USA',
  'Los Angeles, USA',
  'Las Vegas, USA',
  'San Francisco, USA',
  'Miami, USA',
  'Chicago, USA',
  'New Orleans, USA',
  'Honolulu, Hawaii, USA',
  'Toronto, Canada',
  'Vancouver, Canada',
  'Montreal, Canada',
  'Mexico City, Mexico',
  'Cancun, Mexico',
  'Tulum, Mexico',
  'Rio de Janeiro, Brazil',
  'São Paulo, Brazil',
  'Buenos Aires, Argentina',
  'Patagonia, Argentina',
  'Lima, Peru',
  'Machu Picchu, Peru',
  'Cusco, Peru',
  'Bogotá, Colombia',
  'Cartagena, Colombia',
  // ── Africa & Oceania ──────────────────────────────────────────────────────
  'Cape Town, South Africa',
  'Johannesburg, South Africa',
  'Nairobi, Kenya',
  'Masai Mara, Kenya',
  'Zanzibar, Tanzania',
  'Serengeti, Tanzania',
  'Marrakech, Morocco',
  'Casablanca, Morocco',
  'Sydney, Australia',
  'Melbourne, Australia',
  'Brisbane, Australia',
  'Cairns, Australia',
  'Gold Coast, Australia',
  'Auckland, New Zealand',
  'Queenstown, New Zealand',
  'Christchurch, New Zealand',
  'Fiji',
  'Bora Bora, French Polynesia',
  'Maldives',
];

// ─── CURRENCY SHEET ───────────────────────────────────────────────────────────

class _CurrencySheet extends StatefulWidget {
  const _CurrencySheet({required this.selected, required this.onSelect});
  final String selected;
  final void Function(String) onSelect;

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  final _searchCtrl = TextEditingController();
  List<CurrencyEntry> _filtered = kAllCurrencies;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final query = q.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? kAllCurrencies
          : kAllCurrencies
              .where((c) =>
                  c.code.toLowerCase().contains(query) ||
                  c.name.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightOutline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Select Currency',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Search currency...',
                hintStyle: const TextStyle(
                    fontFamily: 'Poppins', color: AppColors.lightOnSurfaceVar),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.lightOnSurfaceVar),
                filled: true,
                fillColor: AppColors.lightBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final isSelected = c.code == widget.selected;
                return ListTile(
                  leading: Text(c.flag,
                      style: const TextStyle(fontSize: 22)),
                  title: Text(
                    '${c.code} — ${c.name}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.navy,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 20)
                      : null,
                  onTap: () => widget.onSelect(c.code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
