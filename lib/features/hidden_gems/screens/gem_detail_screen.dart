import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/gem_model.dart';
import '../services/gems_service.dart';

// ─── GEM DETAIL SCREEN ───────────────────────────────────────────────────────
// Loads real gem data from Firestore using gemId and displays full details.
// ─────────────────────────────────────────────────────────────────────────────

class GemDetailScreen extends ConsumerStatefulWidget {
  final String gemId;

  const GemDetailScreen({super.key, required this.gemId});

  @override
  ConsumerState<GemDetailScreen> createState() => _GemDetailScreenState();
}

class _GemDetailScreenState extends ConsumerState<GemDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _upvoteController;
  late Animation<double> _upvoteAnimation;

  GemModel? _gem;
  String _addedByName = '';
  bool _loading = true;
  String? _error;
  bool _isUpvoted = false;
  late int _upvoteCount;

  // Rating state
  int? _userRating;       // user's own rating (1–5), null = not rated yet
  double _displayRating = 0.0;
  int _ratingCount = 0;
  bool _submittingRating = false;

  @override
  void initState() {
    super.initState();
    _upvoteCount = 0;
    _upvoteController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _upvoteAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _upvoteController, curve: Curves.elasticOut),
    );
    _loadGem();
  }

  @override
  void dispose() {
    _upvoteController.dispose();
    super.dispose();
  }

  Future<void> _loadGem() async {
    try {
      final gem = await ref.read(gemsServiceProvider).getGemById(widget.gemId);
      if (gem == null) {
        setState(() {
          _error = 'Gem not found';
          _loading = false;
        });
        return;
      }

      // Fetch display name of the user who added this gem
      String displayName = '';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(gem.addedBy)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          displayName = (data['displayName'] as String? ?? '').isNotEmpty
              ? data['displayName'] as String
              : (data['name'] as String? ?? '');
        }
      } catch (_) {}

      // Fallback to Firebase Auth display name or email (when it's the current user)
      if (displayName.isEmpty) {
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null && authUser.uid == gem.addedBy) {
          displayName = authUser.displayName?.isNotEmpty == true
              ? authUser.displayName!
              : (authUser.email?.split('@').first ?? '');
        }
      }
      if (displayName.isEmpty) displayName = 'Traveler';

      // Fetch this user's existing rating and like state
      final userRating =
          await ref.read(gemsServiceProvider).getUserRating(widget.gemId);
      final userLiked =
          await ref.read(gemsServiceProvider).hasUserLiked(widget.gemId);

      setState(() {
        _gem = gem;
        _upvoteCount = gem.upvotes;
        _displayRating = gem.averageRating;
        _ratingCount = gem.ratingCount;
        _userRating = userRating;
        _isUpvoted = userLiked;
        _addedByName = displayName;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toggleUpvote() async {
    if (_gem == null) return;
    final wasUpvoted = _isUpvoted;
    final wasCount = _upvoteCount;

    // Optimistic update
    setState(() {
      _isUpvoted = !wasUpvoted;
      _upvoteCount = wasCount + (wasUpvoted ? -1 : 1);
    });
    if (!wasUpvoted) {
      _upvoteController.forward().then((_) => _upvoteController.reverse());
    }

    try {
      await ref.read(gemsServiceProvider).toggleLike(widget.gemId);
    } catch (_) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isUpvoted = wasUpvoted;
          _upvoteCount = wasCount;
        });
      }
    }
  }

  Future<void> _submitRating(int stars) async {
    if (_submittingRating) return;
    setState(() {
      _submittingRating = true;
      _userRating = stars;
    });
    try {
      await ref.read(gemsServiceProvider).rateGem(widget.gemId, stars);
      // Reload to get updated average
      final updated =
          await ref.read(gemsServiceProvider).getGemById(widget.gemId);
      if (mounted && updated != null) {
        setState(() {
          _displayRating = updated.averageRating;
          _ratingCount = updated.ratingCount;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save rating. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingRating = false);
    }
  }

  Future<void> _navigate() async {
    if (_gem == null) return;
    final lat = _gem!.location.latitude;
    final lng = _gem!.location.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _locationText(GemModel gem) {
    final city = gem.city.isNotEmpty && gem.city != 'Unknown' ? gem.city : null;
    final country = gem.country.isNotEmpty && gem.country != 'Unknown' ? gem.country : null;
    if (city != null || country != null) {
      return [city, country].whereType<String>().join(', ');
    }
    // Fall back to coordinates
    final lat = gem.location.latitude;
    final lng = gem.location.longitude;
    final latStr = '${lat.abs().toStringAsFixed(4)}°${lat >= 0 ? 'N' : 'S'}';
    final lngStr = '${lng.abs().toStringAsFixed(4)}°${lng >= 0 ? 'E' : 'W'}';
    return '$latStr, $lngStr';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'T';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    final months = (diff.inDays / 30).floor();
    if (months >= 1) return '$months ${months == 1 ? 'month' : 'months'} ago';
    if (diff.inDays >= 1) return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    if (diff.inHours >= 1) return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();
    return _buildContent();
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: 300,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.teal, AppColors.primary, AppColors.purple],
              ),
            ),
          ),
          const Expanded(
            child: Center(child: CircularProgressIndicator(color: AppColors.teal)),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: AppColors.navy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadGem();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final gem = _gem!;
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhotoHeader(gem),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGemTitle(gem),
                      const SizedBox(height: 14),
                      _buildGemMeta(gem),
                      const SizedBox(height: 16),
                      _buildAddedBy(gem),
                      const SizedBox(height: 24),
                      _buildDescription(gem),
                      const SizedBox(height: 24),
                      _buildRatingSection(),
                      const SizedBox(height: 24),
                      _buildLocation(gem),
                      SizedBox(height: 96 + MediaQuery.of(context).viewPadding.bottom),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildPhotoHeader(GemModel gem) {
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    return Stack(
      children: [
        // Tappable photo — opens full-screen gallery
        GestureDetector(
          onTap: gem.photos.isNotEmpty
              ? () => _openGallery(gem.photos, 0)
              : null,
          child: SizedBox(
            height: 300 + statusBarHeight,
            width: double.infinity,
            child: gem.photos.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: gem.photos.first,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => _gradientPlaceholder(),
                    errorWidget: (ctx, url, err) => _gradientPlaceholder(),
                  )
                : _gradientPlaceholder(),
          ),
        ),
        // Top gradient so back button is always readable
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: statusBarHeight + 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withAlpha(160), Colors.transparent],
              ),
            ),
          ),
        ),
        // Back button — respects status bar
        Positioned(
          top: statusBarHeight + 10,
          left: 16,
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(128),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        // Photo count badge (bottom-right of header)
        if (gem.photos.length > 1)
          Positioned(
            bottom: 12,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(153),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${gem.photos.length} photos',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // "Tap to view" hint when there are photos
        if (gem.photos.isNotEmpty)
          Positioned(
            bottom: 12,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(128),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Tap to view',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _openGallery(List<String> photos, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (ctx, anim, sanim) => _PhotoGalleryPage(
          photos: photos,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (ctx, animation, sanim, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _gradientPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.teal, AppColors.primary, AppColors.purple],
        ),
      ),
      child: const Center(
        child: Icon(Icons.landscape_rounded, size: 64, color: Colors.white70),
      ),
    );
  }

  Widget _buildGemTitle(GemModel gem) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gem.name,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.location_on_rounded, size: 15, color: AppColors.teal),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _locationText(gem),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.teal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGemMeta(GemModel gem) {
    return Row(
      children: [
        // Category pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.teal.withAlpha(26),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.teal.withAlpha(51)),
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
        // Star summary (if rated)
        if (_displayRating > 0) ...[
          const SizedBox(width: 12),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFC107)),
              const SizedBox(width: 3),
              Text(
                _displayRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              if (_ratingCount > 0)
                Text(
                  ' ($_ratingCount)',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.lightOnSurfaceVar,
                  ),
                ),
            ],
          ),
        ],
        const Spacer(),
        // Upvote button
        GestureDetector(
          onTap: _toggleUpvote,
          child: AnimatedBuilder(
            animation: _upvoteAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _upvoteAnimation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isUpvoted
                        ? AppColors.success.withAlpha(20)
                        : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isUpvoted
                          ? AppColors.success.withAlpha(80)
                          : AppColors.lightOutline,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isUpvoted
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_up_alt_outlined,
                        size: 16,
                        color: _isUpvoted
                            ? AppColors.success
                            : AppColors.lightOnSurfaceVar,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$_upvoteCount',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isUpvoted
                              ? AppColors.success
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
      ],
    );
  }

  Widget _buildAddedBy(GemModel gem) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightOutline),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _initials(_addedByName),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
                    Text(
                      _addedByName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    if (gem.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded,
                          size: 13, color: AppColors.success),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'Shared ${_timeAgo(gem.createdAt)}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.lightOnSurfaceVar,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.person_outline_rounded,
              size: 18, color: AppColors.lightOnSurfaceVar),
        ],
      ),
    );
  }

  Widget _buildDescription(GemModel gem) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          gem.description.isNotEmpty
              ? gem.description
              : 'No description provided.',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.lightOnSurface,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ratings',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.lightOutline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Community average
              Row(
                children: [
                  _buildStarRow(_displayRating, size: 20, interactive: false),
                  const SizedBox(width: 8),
                  Text(
                    _displayRating > 0
                        ? _displayRating.toStringAsFixed(1)
                        : '—',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _ratingCount > 0
                        ? '$_ratingCount ${_ratingCount == 1 ? 'review' : 'reviews'}'
                        : 'No reviews yet',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.lightOnSurfaceVar,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppColors.lightOutline),
              ),
              // User's own rating
              Text(
                _userRating != null ? 'Your rating' : 'Tap to rate',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.lightOnSurfaceVar,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStarRow(
                    (_userRating ?? 0).toDouble(),
                    size: 32,
                    interactive: true,
                  ),
                  if (_submittingRating) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.teal),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStarRow(double rating, {required double size, required bool interactive}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        IconData icon;
        if (rating >= starIndex) {
          icon = Icons.star_rounded;
        } else if (rating >= starIndex - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        final filled = rating >= starIndex - 0.5;
        return GestureDetector(
          onTap: interactive && !_submittingRating
              ? () => _submitRating(starIndex)
              : null,
          child: Icon(
            icon,
            size: size,
            color: filled ? const Color(0xFFFFC107) : AppColors.lightOnSurfaceVar,
          ),
        );
      }),
    );
  }

  Widget _buildLocation(GemModel gem) {
    final latLng = LatLng(gem.location.latitude, gem.location.longitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 190,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
                  markers: {
                    Marker(
                      markerId: const MarkerId('gem'),
                      position: latLng,
                      infoWindow: InfoWindow(title: gem.name),
                    ),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  liteModeEnabled: true,
                  onTap: (_) => _navigate(),
                ),
              ),
            ),
            // Tap-to-navigate badge
            Positioned(
              bottom: 10,
              right: 10,
              child: GestureDetector(
                onTap: _navigate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(60),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.navigation_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Navigate',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Save to trip — coming soon!')),
                  );
                },
                icon: const Icon(Icons.bookmark_border_rounded, size: 18),
                label: const Text(
                  'Save',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightBackground,
                  foregroundColor: AppColors.navy,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.lightOutline),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _navigate,
                icon: const Icon(Icons.navigation_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Navigate',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FULL-SCREEN PHOTO GALLERY ───────────────────────────────────────────────

class _PhotoGalleryPage extends StatefulWidget {
  const _PhotoGalleryPage({required this.photos, required this.initialIndex});
  final List<String> photos;
  final int initialIndex;

  @override
  State<_PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<_PhotoGalleryPage> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Swipeable photos
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) {
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.photos[i],
                    fit: BoxFit.contain,
                    placeholder: (ctx, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                    errorWidget: (ctx, url, err) => const Icon(
                      Icons.broken_image_rounded,
                      size: 64,
                      color: Colors.white54,
                    ),
                  ),
                ),
              );
            },
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).viewPadding.top + 10,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(153),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),

          // Page counter  (e.g. "2 / 5")
          if (widget.photos.length > 1)
            Positioned(
              top: MediaQuery.of(context).viewPadding.top + 14,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(153),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_current + 1} / ${widget.photos.length}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

          // Dot indicators at bottom
          if (widget.photos.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).viewPadding.bottom + 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.photos.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _current == i ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _current == i ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
