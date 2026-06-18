import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

import '../../../core/config/env_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../services/gems_service.dart';

class AddGemScreen extends ConsumerStatefulWidget {
  const AddGemScreen({super.key, this.lat, this.lng});

  final double? lat;
  final double? lng;

  @override
  ConsumerState<AddGemScreen> createState() => _AddGemScreenState();
}

class _AddGemScreenState extends ConsumerState<AddGemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  final List<XFile> _selectedImages = [];
  String _selectedCategory = '';

  double? _lat;
  double? _lng;
  String _locationLabel = 'Detecting location...';
  String _city = '';
  String _country = '';
  bool _submitting = false;
  String _uploadStatus = '';

  final List<String> _categories = [
    'Food & Drinks',
    'Nature',
    'Arts',
    'Beach',
    'Local Life',
    'Adventure',
  ];

  final ImagePicker _picker = ImagePicker();
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    if (widget.lat != null && widget.lng != null) {
      _lat = widget.lat;
      _lng = widget.lng;
      _reverseGeocode(_lat!, _lng!);
    } else {
      _detectLocation();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationLabel = 'Location unavailable');
        return;
      }
      // Always get a fresh fix — never use last known position which can be
      // hours old and from a completely different location, causing the gem
      // to be stored at wrong coordinates.
      // Try network-based (fast) first, then GPS for better accuracy.
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,   // network-based, fast (~1s)
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20),
          ),
        );
      }
      if (!mounted) return;
      _lat = pos.latitude;
      _lng = pos.longitude;
      await _reverseGeocode(_lat!, _lng!);
    } catch (_) {
      if (mounted) setState(() => _locationLabel = 'Location unavailable');
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    final key = EnvConfig.googleMapsKey;
    if (key.isEmpty) {
      if (mounted) {
        setState(() => _locationLabel =
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}');
      }
      return;
    }
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {'latlng': '$lat,$lng', 'key': key},
      );
      final results = res.data['results'] as List? ?? [];
      if (results.isEmpty) throw Exception('no results');

      String city = '';
      String country = '';

      // Scan all results — first result may not have locality
      for (final result in results) {
        final comps = result['address_components'] as List? ?? [];
        for (final c in comps) {
          final types = (c['types'] as List).map((e) => e.toString()).toList();
          if (city.isEmpty && types.contains('locality')) {
            city = c['long_name'] as String;
          }
          if (country.isEmpty && types.contains('country')) {
            country = c['long_name'] as String;
          }
        }
        if (city.isNotEmpty && country.isNotEmpty) break;
      }

      // Fallback hierarchy for city: some locations use different types
      if (city.isEmpty) {
        const fallbackTypes = [
          'postal_town',
          'sublocality_level_1',
          'sublocality',
          'administrative_area_level_2',
          'administrative_area_level_1',
        ];
        outer:
        for (final type in fallbackTypes) {
          for (final result in results) {
            final comps = result['address_components'] as List? ?? [];
            for (final c in comps) {
              final types =
                  (c['types'] as List).map((e) => e.toString()).toList();
              if (types.contains(type)) {
                city = c['long_name'] as String;
                break outer;
              }
            }
          }
        }
      }

      final label = [city, country].where((s) => s.isNotEmpty).join(', ');
      if (mounted) {
        setState(() {
          _lat = lat;
          _lng = lng;
          _city = city;
          _country = country;
          _locationLabel =
              label.isNotEmpty ? label : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _locationLabel =
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}');
      }
    }
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) return;
    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: 72,   // ~70-80% smaller than original, imperceptible quality loss
      maxWidth: 1920,     // cap resolution — phone cameras can shoot 4000+ px wide
      maxHeight: 1920,
    );
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.take(5 - _selectedImages.length));
      });
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _submitGem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo')),
      );
      return;
    }
    if (_selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available yet')),
      );
      return;
    }

    final total = _selectedImages.length;
    setState(() {
      _submitting = true;
      _uploadStatus = 'Uploading photo 1 of $total…';
    });
    final gemName = _nameCtrl.text.trim();
    try {
      final service = ref.read(gemsServiceProvider);
      await service.addGem(
        name: gemName,
        description: _descriptionCtrl.text.trim(),
        category: _selectedCategory,
        latitude: _lat!,
        longitude: _lng!,
        city: _city,
        country: _country,
        photoFiles: _selectedImages.map((x) => File(x.path)).toList(),
        onPhotoUploaded: (done) {
          if (mounted) {
            setState(() => _uploadStatus = done < total
                ? 'Uploading photo ${done + 1} of $total…'
                : 'Saving gem…');
          }
        },
      );
      if (!mounted) return;
      await _showSuccessOverlay(gemName);
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Add a Hidden Gem',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhotoUpload(),
                const SizedBox(height: 24),
                _buildNameField(),
                const SizedBox(height: 18),
                _buildDescriptionField(),
                const SizedBox(height: 24),
                _buildCategorySelector(),
                const SizedBox(height: 24),
                _buildLocationSection(),
                const SizedBox(height: 18),
                _buildTagsField(),
                const SizedBox(height: 32),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photos',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.lightBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightOutline, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 32,
                  color: AppColors.lightOnSurfaceVar,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add photos (max 5)',
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
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(File(_selectedImages[index].path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gem Name',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameCtrl,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Gem name is required' : null,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            color: AppColors.navy,
          ),
          decoration: InputDecoration(
            hintText: 'Enter gem name',
            hintStyle: const TextStyle(color: AppColors.lightOnSurface),
            filled: true,
            fillColor: AppColors.lightBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionCtrl,
          maxLines: 4,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Description is required';
            if (v.trim().length < 10) return 'At least 10 characters';
            return null;
          },
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            color: AppColors.navy,
          ),
          decoration: InputDecoration(
            hintText: 'Describe this hidden gem...',
            hintStyle: const TextStyle(color: AppColors.lightOnSurface),
            filled: true,
            fillColor: AppColors.lightBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategory == category;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.teal : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.teal : AppColors.lightOutline,
                  ),
                ),
                child: Center(
                  child: Text(
                    category,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.navy,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (_) => _LocationPickerScreen(
          initialLat: _lat,
          initialLng: _lng,
        ),
      ),
    );
    if (result != null && mounted) {
      _lat = result['lat'];
      _lng = result['lng'];
      setState(() => _locationLabel = 'Fetching address…');
      await _reverseGeocode(_lat!, _lng!);
    }
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.lightBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightOutline),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _locationLabel,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _pickLocationOnMap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.teal.withAlpha(80)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 13, color: AppColors.teal),
                      SizedBox(width: 4),
                      Text(
                        'Pick on map',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tags',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _tagsCtrl,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            color: AppColors.navy,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. street food, rooftop, hidden',
            hintStyle: const TextStyle(color: AppColors.lightOnSurface),
            filled: true,
            fillColor: AppColors.lightBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submitGem,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          disabledBackgroundColor: AppColors.teal.withAlpha(128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _submitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _uploadStatus,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : const Text(
                'Share this Gem',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _showSuccessOverlay(String gemName) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Success',
      barrierColor: Colors.black.withAlpha(160),
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (ctx, _, _) => _GemSuccessDialog(gemName: gemName),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// ─── GEM SUCCESS DIALOG ───────────────────────────────────────────────────────

class _GemSuccessDialog extends StatefulWidget {
  const _GemSuccessDialog({required this.gemName});
  final String gemName;

  @override
  State<_GemSuccessDialog> createState() => _GemSuccessDialogState();
}

class _GemSuccessDialogState extends State<_GemSuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _confettiController.forward();
      Future.delayed(const Duration(milliseconds: 2800), () {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
      });
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).pop(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Confetti
          Positioned.fill(
            child: IgnorePointer(
              child: Lottie.asset(
                AppLottie.confetti,
                controller: _confettiController,
                repeat: false,
                errorBuilder: (_, _, _) => const SizedBox(),
                onLoaded: (comp) {
                  _confettiController
                    ..duration = comp.duration
                    ..forward(from: 0);
                },
              ),
            ),
          ),
          // Card
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 36),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal.withAlpha(60),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _pulse,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.teal, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.teal.withAlpha(90),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.diamond_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Gem Added!',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"${widget.gemName}" has been\nshared with the community!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.lightOnSurfaceVar,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Tap anywhere to continue',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.teal,
                      ),
                    ),
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
}

// ─── LOCATION PICKER SCREEN ───────────────────────────────────────────────────
// Drag-the-map style picker — pin stays fixed in the centre,
// map moves beneath it. Confirm returns the chosen LatLng.

class _LocationPickerScreen extends StatefulWidget {
  const _LocationPickerScreen({this.initialLat, this.initialLng});
  final double? initialLat;
  final double? initialLng;

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  GoogleMapController? _mapController;
  late LatLng _selected;
  String _addressLabel = 'Move the map to pin the location';
  bool _geocoding = false;
  final Dio _dio = Dio();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selected = LatLng(
      widget.initialLat ?? 20.5937,
      widget.initialLng ?? 78.9629,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onCameraMove(CameraPosition pos) {
    _selected = pos.target;
  }

  void _onCameraIdle() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _fetchAddress);
  }

  Future<void> _fetchAddress() async {
    setState(() => _geocoding = true);
    final key = EnvConfig.googleMapsKey;
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '${_selected.latitude},${_selected.longitude}',
          'key': key,
        },
      );
      final results = res.data['results'] as List? ?? [];
      if (results.isNotEmpty) {
        final address =
            results.first['formatted_address'] as String? ?? '';
        if (mounted) setState(() => _addressLabel = address);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _addressLabel =
            '${_selected.latitude.toStringAsFixed(5)}, ${_selected.longitude.toStringAsFixed(5)}');
      }
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.navy,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Pick Location',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _selected, zoom: 15),
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) => _mapController = c,
          ),

          // ── Fixed centre pin ────────────────────────────────────────────
          const Center(
            child: Padding(
              // shift up by half the icon height so the point lands on spot
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(Icons.location_pin, color: AppColors.teal, size: 48),
            ),
          ),

          // ── Bottom card ─────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20, 16, 20,
                MediaQuery.of(context).viewPadding.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 16, color: AppColors.teal),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _geocoding
                            ? const Text(
                                'Finding address…',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppColors.lightOnSurfaceVar,
                                ),
                              )
                            : Text(
                                _addressLabel,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppColors.navy,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _geocoding
                          ? null
                          : () => Navigator.of(context).pop({
                                'lat': _selected.latitude,
                                'lng': _selected.longitude,
                              }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Confirm Location',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
