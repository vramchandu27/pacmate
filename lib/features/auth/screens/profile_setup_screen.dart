import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/theme/app_theme.dart';

// ── Avatar data ──────────────────────────────────────────────────────────────
const _avatars = [
  {'emoji': '🧳', 'color': 0xFFBA7517},
  {'emoji': '✈️', 'color': 0xFF378ADD},
  {'emoji': '🏕️', 'color': 0xFF639922},
  {'emoji': '🤿', 'color': 0xFF1D9E75},
  {'emoji': '🏄', 'color': 0xFFE24B4A},
  {'emoji': '🧗', 'color': 0xFF534AB7},
  {'emoji': '🚴', 'color': 0xFF1A7FC1},
  {'emoji': '🌍', 'color': 0xFF0F172A},
  {'emoji': '📸', 'color': 0xFFD946EF},
  {'emoji': '🎒', 'color': 0xFFF59E0B},
];

const _currencies = ['INR', 'USD', 'EUR', 'GBP', 'AED', 'SGD', 'JPY', 'AUD'];


class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _isSaving = false;
  int _selectedAvatar = 0;
  File? _photoFile;
  String _selectedCurrency = 'INR';
  bool _isSeniorMode = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && (user.displayName ?? '').isNotEmpty) {
      _nameCtrl.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (picked != null) {
      setState(() => _photoFile = File(picked.path));
    }
  }

  Future<String?> _uploadPhoto(String uid) async {
    if (_photoFile == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref('avatars/$uid.jpg');
      await ref
          .putFile(_photoFile!, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(const Duration(seconds: 30));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final authService = ref.read(authServiceProvider);

      // Upload photo first so URL is available for profile update
      final photoUrl = await _uploadPhoto(user.uid);

      // Save critical data to Firestore in parallel
      await Future.wait([
        authService.updateProfile({
          'fullName': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'currency': _selectedCurrency,
          'travelType': 'solo',
          'avatar': _avatars[_selectedAvatar]['emoji'],
          'photoUrl': ?photoUrl,
          'seniorMode': _isSeniorMode,
        }),
        authService.markProfileComplete(),
      ]);

      // Firebase Auth display name + photo — best-effort, don't block navigation
      user.updateDisplayName(_nameCtrl.text.trim()).ignore();
      if (photoUrl != null) user.updatePhotoURL(photoUrl).ignore();

      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save profile: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Pick your avatar'),
                    const SizedBox(height: 14),
                    _buildAvatarRow(),
                    const SizedBox(height: 20),
                    _buildPhotoUpload(),
                    const SizedBox(height: 32),
                    _buildNameField(),
                    const SizedBox(height: 18),
                    _buildPhoneField(),
                    const SizedBox(height: 28),
                    _sectionLabel('Home currency'),
                    const SizedBox(height: 12),
                    _buildCurrencyChips(),
                    const SizedBox(height: 28),
                    _buildSeniorToggle(),
                    SizedBox(height: 32 + bottomPad),
                  ],
                ),
              ),
            ),
          ),
          _buildSaveButton(bottomPad),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) context.pop();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Set Up Your Profile',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Just a few things to personalise your journey ✨',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar row ───────────────────────────────────────────────────────────────

  Widget _buildAvatarRow() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _avatars.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final isSelected = _selectedAvatar == i;
          final color = Color(_avatars[i]['color'] as int);
          return GestureDetector(
            onTap: () => setState(() => _selectedAvatar = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withAlpha(35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 3,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withAlpha(100),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  _avatars[i]['emoji'] as String,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Photo upload ─────────────────────────────────────────────────────────────

  Widget _buildPhotoUpload() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _photoFile != null
                ? AppColors.primary
                : AppColors.lightOutline,
            width: _photoFile != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withAlpha(20),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
                image: _photoFile != null
                    ? DecorationImage(
                        image: FileImage(_photoFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _photoFile == null
                  ? const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.primary,
                      size: 22,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _photoFile != null ? 'Photo selected ✓' : 'Upload a photo',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _photoFile != null
                          ? AppColors.success
                          : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Optional · from your gallery',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.lightOnSurfaceVar,
                    ),
                  ),
                ],
              ),
            ),
            if (_photoFile != null)
              GestureDetector(
                onTap: () => setState(() => _photoFile = null),
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.lightOnSurfaceVar,
                  size: 20,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.lightOnSurfaceVar,
              ),
          ],
        ),
      ),
    );
  }

  // ── Text fields ──────────────────────────────────────────────────────────────

  Widget _buildNameField() {
    return _StyledField(
      controller: _nameCtrl,
      label: 'Your Name',
      hint: 'What should we call you?',
      iconEmoji: '👤',
      iconColor: AppColors.primary,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Name is required';
        if (v.trim().length < 2) return 'Name is too short';
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return _StyledField(
      controller: _phoneCtrl,
      label: 'Phone Number',
      hint: 'Optional · e.g. +91 98765 43210',
      iconEmoji: '📱',
      iconColor: AppColors.teal,
      keyboardType: TextInputType.phone,
    );
  }

  // ── Currency chips ───────────────────────────────────────────────────────────

  Widget _buildCurrencyChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _currencies.map((c) {
        final isSelected = _selectedCurrency == c;
        return GestureDetector(
          onTap: () => setState(() => _selectedCurrency = c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.lightOutline,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(60),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Text(
              c,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.navy,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Senior mode toggle ───────────────────────────────────────────────────────

  Widget _buildSeniorToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isSeniorMode = !_isSeniorMode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isSeniorMode
              ? AppColors.teal.withAlpha(18)
              : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isSeniorMode ? AppColors.teal : AppColors.lightOutline,
            width: _isSeniorMode ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            const Text('🌿', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Senior Mode',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Medicine reminders, family tracking & comfort tips',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.lightOnSurfaceVar,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isSeniorMode,
              onChanged: (v) => setState(() => _isSeniorMode = v),
              activeThumbColor: AppColors.teal,
              activeTrackColor: AppColors.teal.withAlpha(80),
            ),
          ],
        ),
      ),
    );
  }

  // ── Save button ──────────────────────────────────────────────────────────────

  Widget _buildSaveButton(double bottomPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        bottomPad > 0 ? bottomPad + 8 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withAlpha(100),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _isSaving
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
                    Text(
                      "Let's Go",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
    );
  }
}

// ── Styled text field widget ─────────────────────────────────────────────────

class _StyledField extends StatefulWidget {
  const _StyledField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.iconEmoji,
    required this.iconColor,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String iconEmoji;
  final Color iconColor;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  @override
  State<_StyledField> createState() => _StyledFieldState();
}

class _StyledFieldState extends State<_StyledField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? AppColors.primary : AppColors.lightOutline,
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.primary.withAlpha(30),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            margin: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              color: widget.iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.iconEmoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: widget.keyboardType,
              validator: widget.validator,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.navy,
              ),
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                labelStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: _focused
                      ? AppColors.primary
                      : AppColors.lightOnSurfaceVar,
                ),
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.lightOnSurface,
                ),
                filled: false,
                contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
