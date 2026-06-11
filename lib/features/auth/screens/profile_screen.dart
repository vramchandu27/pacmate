import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/user_provider.dart';

// ─── PROFILE SCREEN ──────────────────────────────────────────────────────────
// View/edit user profile with logout and "complete profile" prompt.
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoggingOut = false;
  bool _isUploadingPhoto = false;

  // Edit-mode controllers
  final _nameCtrl = TextEditingController();
  String _travelStyle = 'budget';
  String _travelType = 'solo';
  String _currency = 'INR';
  String _homeCountry = 'India';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _enterEditMode(UserModel user) {
    _nameCtrl.text = user.fullName;
    _travelStyle = user.travelStyle;
    _travelType = user.travelType;
    _currency = user.currency;
    _homeCountry = user.homeCountry;
    setState(() => _isEditing = true);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.of(context).pop();
    try {
      final xFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (xFile == null) return;
      setState(() => _isUploadingPhoto = true);
      await ref.read(authServiceProvider).uploadProfilePhoto(File(xFile.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!',
                style: TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload photo.',
                style: TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Change Profile Photo',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Camera',
                  style: TextStyle(fontFamily: 'Poppins')),
              onTap: () => _pickPhoto(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primary),
              title: const Text('Gallery',
                  style: TextStyle(fontFamily: 'Poppins')),
              onTap: () => _pickPhoto(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.nameTooShort,
              style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(authServiceProvider).updateProfile({
        'fullName': name,
        'travelStyle': _travelStyle,
        'travelType': _travelType,
        'currency': _currency,
        'homeCountry': _homeCountry,
      });
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!',
                style: TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.somethingWrong,
                style: TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text(
              'Log Out',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await ref.read(authServiceProvider).signOut();
      if (mounted) context.go(AppRoutes.login);
    } catch (_) {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.somethingWrong,
                style: TextStyle(fontFamily: 'Poppins')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(userAsync.valueOrNull),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text(
            e.toString(),
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
        ),
        data: (user) {
          if (user == null) {
            return _buildNoUser();
          }
          return _isEditing ? _buildEditMode(user) : _buildViewMode(user);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(UserModel? user) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        onPressed: _isEditing
            ? () => setState(() => _isEditing = false)
            : () => context.pop(),
        icon: Icon(
          _isEditing ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
          color: AppColors.navy,
        ),
      ),
      title: Text(
        _isEditing ? AppStrings.editProfile : AppStrings.profileTitle,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      actions: [
        if (!_isEditing && user != null)
          IconButton(
            onPressed: () => _enterEditMode(user),
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
          ),
        if (_isEditing)
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveProfile,
                  child: const Text(
                    AppStrings.save,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
      ],
    );
  }

  // ── View mode ──────────────────────────────────────────────────────────────

  Widget _buildViewMode(UserModel user) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero header ─────────────────────────────────────────────
          _buildHeroCard(user),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Complete profile banner
                if (!user.profileComplete) ...[
                  _buildCompleteProfileBanner(user),
                  const SizedBox(height: 20),
                ],

                // Travel profile section
                _sectionLabel('Travel Profile'),
                const SizedBox(height: 12),
                _buildInfoGrid(user),
                const SizedBox(height: 28),

                // Logout
                _buildLogoutButton(),
                SizedBox(height: bottomPad + 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(UserModel user) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A4A), Color(0xFF0B1A2E)],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Decorative circles
          Positioned(
            right: -28, top: -28,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(8),
              ),
            ),
          ),
          Positioned(
            right: 60, bottom: -40,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withAlpha(22),
              ),
            ),
          ),
          Positioned(
            left: -20, top: 40,
            child: Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.teal.withAlpha(18),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              children: [
                // Avatar with gradient ring
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.teal],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1A2A4A),
                    ),
                    child: _buildTappableAvatar(user),
                  ),
                ),
                const SizedBox(height: 14),
                // Name
                Text(
                  _toTitleCase(user.fullName),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                // Email
                Text(
                  user.email,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 20),
                // Stats strip
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(22)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _heroStat('${user.totalTrips}', 'Trips'),
                      Container(width: 1, height: 32, color: Colors.white.withAlpha(28)),
                      _heroStat(user.currency, 'Currency'),
                      Container(width: 1, height: 32, color: Colors.white.withAlpha(28)),
                      _heroStat(_firstWord(user.homeCountry), 'Country'),
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

  Widget _heroStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4, height: 18,
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
          text,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    if (_isLoggingOut) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.danger));
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withAlpha(90)),
        color: AppColors.danger.withAlpha(8),
      ),
      child: TextButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded,
            color: AppColors.danger, size: 18),
        label: const Text(
          AppStrings.logout,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.danger,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildCompleteProfileBanner(UserModel user) {
    final hasPhoto = user.photoUrl != null && user.photoUrl!.isNotEmpty;
    final hasName  = user.fullName.trim().length >= 2;

    final steps = [
      (label: 'Profile photo',       done: hasPhoto, icon: Icons.camera_alt_outlined),
      (label: 'Full name',           done: hasName,  icon: Icons.person_outline_rounded),
      (label: 'Travel preferences',  done: false,    icon: Icons.tune_rounded),
    ];

    final doneCount = steps.where((s) => s.done).length;
    final progress  = doneCount / steps.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.account_circle_outlined,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Complete your profile',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '$doneCount / ${steps.length} done',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.lightOnSurfaceVar,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.lightOutline,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.warning),
            ),
          ),
          const SizedBox(height: 14),
          // Checklist
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      s.done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 17,
                      color: s.done
                          ? AppColors.success
                          : AppColors.lightOnSurfaceVar,
                    ),
                    const SizedBox(width: 8),
                    Icon(s.icon,
                        size: 15,
                        color: s.done
                            ? AppColors.success
                            : AppColors.lightOnSurfaceVar),
                    const SizedBox(width: 6),
                    Text(
                      s.label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight:
                            s.done ? FontWeight.w400 : FontWeight.w500,
                        color: s.done
                            ? AppColors.lightOnSurfaceVar
                            : AppColors.navy,
                        decoration:
                            s.done ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.lightOnSurfaceVar,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          // CTA button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push(AppRoutes.profileSetup),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Complete Profile',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserModel user) {
    final initial =
        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?';
    if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 52,
        backgroundImage: NetworkImage(user.photoUrl!),
        onBackgroundImageError: (_, s) {},
      );
    }
    return Container(
      width: 104,
      height: 104,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 44,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTappableAvatar(UserModel user) {
    return Tooltip(
      message: 'Tap to update photo',
      child: GestureDetector(
        onTap: _isUploadingPhoto ? null : _showPhotoSourceSheet,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _buildAvatar(user),
            if (_isUploadingPhoto)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(UserModel user) {
    final items = [
      {
        'label': 'Travel Style',
        'value': _capitalize(user.travelStyle),
        'icon': Icons.backpack_outlined,
        'color': AppColors.primary,
      },
      {
        'label': 'Home Currency',
        'value': user.currency,
        'icon': Icons.currency_exchange_rounded,
        'color': AppColors.success,
      },
      {
        'label': 'Home Country',
        'value': user.homeCountry,
        'icon': Icons.flag_outlined,
        'color': AppColors.warning,
      },
      {
        'label': 'Total Trips',
        'value': user.totalTrips.toString(),
        'icon': Icons.flight_rounded,
        'color': AppColors.purple,
      },
      {
        'label': 'Member Since',
        'value': _formatDate(user.createdAt),
        'icon': Icons.calendar_today_outlined,
        'color': AppColors.lightOnSurfaceVar,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final color = item['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(28),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withAlpha(190)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                item['value'] as String,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item['label'] as String,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.lightOnSurfaceVar,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Edit mode ──────────────────────────────────────────────────────────────

  Widget _buildEditMode(UserModel user) {
    const travelStyles = ['budget', 'mid', 'luxury'];
    const currencies   = [
      'INR', 'USD', 'EUR', 'GBP', 'AUD',
      'SGD', 'THB', 'JPY', 'AED', 'CAD',
    ];
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Mini avatar banner ───────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A2A4A), Color(0xFF0B1A2E)],
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.teal],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1A2A4A),
                    ),
                    child: _buildTappableAvatar(user),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tap photo to change',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),

          // ── Form fields ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPad + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full name
                _fieldLabel('Full Name', Icons.person_outline_rounded, AppColors.primary),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                  ),
                  decoration: _fieldDecoration(
                    AppStrings.nameHint,
                    Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 20),

                // Travel style
                _fieldLabel('Travel Style', Icons.backpack_outlined, AppColors.teal),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _travelStyle,
                  items: travelStyles
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(_capitalize(s),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.navy,
                                )),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _travelStyle = v!),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                    fontSize: 16,
                  ),
                  decoration: _fieldDecoration('', Icons.backpack_outlined),
                ),
                const SizedBox(height: 20),

                // Home currency
                _fieldLabel('Home Currency', Icons.currency_exchange_rounded, AppColors.warning),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  items: currencies
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.navy,
                                )),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _currency = v!),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                    fontSize: 16,
                  ),
                  decoration: _fieldDecoration('', Icons.currency_exchange_rounded),
                ),
                const SizedBox(height: 32),

                // Buttons row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _isEditing = false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(
                              color: AppColors.lightOnSurfaceVar, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          AppStrings.cancel,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isSaving
                          ? const Center(
                              child: SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
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
                                    color: AppColors.primary.withAlpha(70),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  AppStrings.save,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: const TextStyle(
          fontFamily: 'Poppins', color: AppColors.lightOnSurfaceVar),
      prefixIcon: Icon(icon, color: AppColors.lightOnSurfaceVar, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.lightOutline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.lightOutline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ── No user fallback ───────────────────────────────────────────────────────

  Widget _buildNoUser() {
    // Auto-sign-out on next frame — user doc missing means stale session
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(authServiceProvider).signOut();
    });
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _toTitleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _firstWord(String s) => s.trim().split(' ').first;

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}
