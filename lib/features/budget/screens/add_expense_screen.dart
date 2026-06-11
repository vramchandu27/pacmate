import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/exchange_rate_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/budget_model.dart';
import '../../../shared/models/currency_data.dart';
import '../services/budget_service.dart';

// ─── COUNTRY → CURRENCY MAP ──────────────────────────────────────────────────

const _kCountryCurrency = <String, String>{
  'India': 'INR', 'Maharashtra': 'INR', 'Karnataka': 'INR', 'Tamil Nadu': 'INR',
  'Kerala': 'INR', 'Rajasthan': 'INR', 'Goa': 'INR', 'Andhra Pradesh': 'INR',
  'Telangana': 'INR', 'West Bengal': 'INR', 'Gujarat': 'INR', 'Punjab': 'INR',
  'Uttar Pradesh': 'INR', 'Uttarakhand': 'INR', 'Himachal Pradesh': 'INR',
  'Jammu & Kashmir': 'INR', 'Ladakh': 'INR', 'Assam': 'INR', 'Meghalaya': 'INR',
  'Sikkim': 'INR', 'Arunachal Pradesh': 'INR', 'Andaman': 'INR',
  'Nepal': 'NPR', 'Sri Lanka': 'LKR', 'Bangladesh': 'BDT',
  'Bhutan': 'BTN', 'Pakistan': 'PKR', 'Maldives': 'MVR',
  'Thailand': 'THB', 'Indonesia': 'IDR', 'Malaysia': 'MYR',
  'Singapore': 'SGD', 'Vietnam': 'VND', 'Cambodia': 'KHR',
  'Laos': 'LAK', 'Myanmar': 'MMK', 'Philippines': 'PHP',
  'Japan': 'JPY', 'South Korea': 'KRW', 'China': 'CNY',
  'Hong Kong': 'HKD', 'Macau': 'MOP', 'Taiwan': 'TWD', 'Mongolia': 'MNT',
  'UAE': 'AED', 'Saudi Arabia': 'SAR', 'Qatar': 'QAR', 'Kuwait': 'KWD',
  'Oman': 'OMR', 'Turkey': 'TRY', 'Israel': 'ILS', 'Jordan': 'JOD', 'Egypt': 'EGP',
  'France': 'EUR', 'Germany': 'EUR', 'Spain': 'EUR', 'Italy': 'EUR',
  'Netherlands': 'EUR', 'Belgium': 'EUR', 'Austria': 'EUR', 'Greece': 'EUR',
  'Portugal': 'EUR', 'Finland': 'EUR', 'Ireland': 'EUR', 'Luxembourg': 'EUR',
  'Slovenia': 'EUR', 'Slovakia': 'EUR', 'Estonia': 'EUR', 'Latvia': 'EUR',
  'Lithuania': 'EUR', 'Malta': 'EUR', 'Monaco': 'EUR', 'Croatia': 'EUR',
  'UK': 'GBP', 'Scotland': 'GBP', 'England': 'GBP', 'Wales': 'GBP',
  'Switzerland': 'CHF', 'Sweden': 'SEK', 'Denmark': 'DKK', 'Norway': 'NOK',
  'Iceland': 'ISK', 'Czech Republic': 'CZK', 'Hungary': 'HUF',
  'Poland': 'PLN', 'Romania': 'RON', 'Bulgaria': 'BGN',
  'Georgia': 'GEL', 'Azerbaijan': 'AZN', 'Armenia': 'AMD',
  'South Africa': 'ZAR', 'Kenya': 'KES', 'Tanzania': 'TZS',
  'Morocco': 'MAD', 'Ethiopia': 'ETB', 'Nigeria': 'NGN',
  'USA': 'USD', 'Canada': 'CAD', 'Mexico': 'MXN',
  'Brazil': 'BRL', 'Argentina': 'ARS', 'Peru': 'PEN', 'Colombia': 'COP',
  'Chile': 'CLP', 'Ecuador': 'USD', 'Bolivia': 'BOB',
  'Australia': 'AUD', 'New Zealand': 'NZD', 'Fiji': 'FJD',
  'French Polynesia': 'XPF',
};

String? _detectCountryCurrency(String destination) {
  if (destination.isEmpty) return null;
  for (final part in destination.split(',').map((s) => s.trim()).toList().reversed) {
    final hit = _kCountryCurrency[part];
    if (hit != null) return hit;
  }
  return null;
}

// ─── ADD EXPENSE SCREEN ──────────────────────────────────────────────────────
// Allows users to log an expense with currency conversion, category selection,
// split options for couples/families, and date picking.
// Uses mock data — wire to BudgetService + Riverpod when backend is ready.
// ─────────────────────────────────────────────────────────────────────────────

// ── Category config ───────────────────────────────────────────────────────────
class _CategoryInfo {
  const _CategoryInfo({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
}

const List<_CategoryInfo> _categories = [
  _CategoryInfo(label: 'Food',       icon: Icons.restaurant_rounded,     color: AppColors.success),
  _CategoryInfo(label: 'Transport',  icon: Icons.directions_bus_rounded,  color: AppColors.teal),
  _CategoryInfo(label: 'Stay',       icon: Icons.hotel_rounded,           color: AppColors.primary),
  _CategoryInfo(label: 'Activities', icon: Icons.surfing_rounded,         color: AppColors.purple),
  _CategoryInfo(label: 'Shopping',   icon: Icons.shopping_bag_rounded,    color: AppColors.warning),
  _CategoryInfo(label: 'Other',      icon: Icons.more_horiz_rounded,      color: AppColors.lightOnSurfaceVar),
];

// ─────────────────────────────────────────────────────────────────────────────

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _amountCtrl     = TextEditingController();
  final _noteCtrl       = TextEditingController();

  Map<String, double> _liveRates = {};
  String        _tripCurrencyCode  = 'INR';
  CurrencyEntry _tripCurrencyEntry = kAllCurrencies.firstWhere((c) => c.code == 'INR');
  bool _currencySynced = false; // prevents overriding after user manually picks

  @override
  void initState() {
    super.initState();
    // Fetch live rates in background
    Future.microtask(() async {
      final rates = await ref.read(exchangeRateServiceProvider).getAllRates();
      if (mounted) setState(() => _liveRates = rates);
    });

    // Try to sync from cached provider value (stream may already have emitted)
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTripCurrency());
  }

  void _syncTripCurrency() {
    if (_currencySynced || !mounted) return;
    final trip = ref.read(activeTripProvider).valueOrNull;
    if (trip == null) return;
    _applyTripData(trip.currency, trip.destination);
  }

  void _applyTripData(String tripCurrency, String destination) {
    // Trip budget currency (used for totals / conversion display)
    final tripEntry = kAllCurrencies.firstWhere(
      (c) => c.code == tripCurrency,
      orElse: () => kAllCurrencies.firstWhere((c) => c.code == 'INR'),
    );
    // Expense input currency: auto-detect from destination, fall back to trip currency
    final expenseCode = _detectCountryCurrency(destination) ?? tripCurrency;
    final expenseEntry = kAllCurrencies.firstWhere(
      (c) => c.code == expenseCode,
      orElse: () => tripEntry,
    );
    setState(() {
      _tripCurrencyCode  = tripCurrency;
      _tripCurrencyEntry = tripEntry;
      _selectedCurrency  = expenseEntry;
      _currencySynced    = true;
    });
  }

  CurrencyEntry _selectedCurrency = kAllCurrencies.firstWhere((c) => c.code == 'INR');
  int           _selectedCategory = 0;
  DateTime      _selectedDate     = DateTime.now();

  // ── Derived: trip-currency conversion ───────────────────────────────────────
  // _liveRates is INR-based: rates[code] = "1 INR → X code"
  // To convert selected → trip: tripRate / selectedRate
  double get _effectiveRate {
    if (_liveRates.isEmpty) {
      // Fallback to hardcoded rates (both relative to INR)
      final tripToInr = _tripCurrencyEntry.toInrRate;
      return tripToInr > 0
          ? _selectedCurrency.toInrRate / tripToInr
          : _selectedCurrency.toInrRate;
    }
    final selectedRate = _liveRates[_selectedCurrency.code] ?? 0;
    if (selectedRate <= 0) return 1.0;
    final tripRate = _liveRates[_tripCurrencyCode] ?? 1.0;
    return tripRate / selectedRate;
  }

  double get _convertedAmount {
    final raw = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    return raw * _effectiveRate;
  }

  String get _convertedFormatted {
    final v   = _convertedAmount;
    final sym = _tripCurrencyEntry.symbol;
    if (v == 0) return '${sym}0';
    final nf = _tripCurrencyCode == 'INR'
        ? NumberFormat('#,##,##0.##', 'en_IN')
        : NumberFormat('#,##0.##');
    return '$sym${nf.format(v)}';
  }

  String _fmtTrip(double v) {
    final sym = _tripCurrencyEntry.symbol;
    final nf  = _tripCurrencyCode == 'INR'
        ? NumberFormat('#,##,##0', 'en_IN')
        : NumberFormat('#,##0');
    return '$sym${nf.format(v.abs())}';
  }

  // ── Date helpers ────────────────────────────────────────────────────────────
  String get _dateLabel {
    final now = DateTime.now();
    if (_selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (_selectedDate.year == yesterday.year &&
        _selectedDate.month == yesterday.month &&
        _selectedDate.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${_selectedDate.day} ${_monthShort(_selectedDate.month)} ${_selectedDate.year}';
  }

  String _monthShort(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][m];

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final trip = ref.read(activeTripProvider).valueOrNull;
    if (trip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active trip. Create a trip first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final remaining = trip.totalBudget - trip.totalSpent;
    if (_convertedAmount > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Over budget! Only ${_fmtTrip(remaining)} remaining.',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          duration: AppDurations.snackBar,
        ),
      );
      return;
    }

    try {
      await ref.read(budgetServiceProvider).addExpense(
        tripId: trip.id,
        amount: double.parse(_amountCtrl.text),
        convertedAmountINR: _convertedAmount,
        originalCurrency: _selectedCurrency.code,
        category: _categories[_selectedCategory].label,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        paidBy: ref.read(budgetServiceProvider).currentUserId,
        splitEqually: false,
        splitBetween: [],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Expense saved  ${_selectedCurrency.symbol}${_amountCtrl.text}  •  ${_categories[_selectedCategory].label}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
            duration: AppDurations.snackBar,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // If the stream hadn't emitted yet during initState, catch it here
    ref.listen<AsyncValue<BudgetModel?>>(activeTripProvider, (_, next) {
      final trip = next.valueOrNull;
      if (trip != null && !_currencySynced) {
        _applyTripData(trip.currency, trip.destination);
      }
    });

    final trip = ref.watch(activeTripProvider).valueOrNull;
    final remaining = trip != null ? trip.totalBudget - trip.totalSpent : double.infinity;
    final isOverBudget = _convertedAmount > 0 && _convertedAmount > remaining;

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
          'Add Expense',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildAmountSection(remaining: remaining, isOverBudget: isOverBudget),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Category'),
                    const SizedBox(height: 12),
                    _buildCategoryGrid(),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Note'),
                    const SizedBox(height: 10),
                    _buildNoteField(),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Date'),
                    const SizedBox(height: 10),
                    _buildDatePicker(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // ── Amount section ───────────────────────────────────────────────────────────
  Widget _buildAmountSection({required double remaining, required bool isOverBudget}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOverBudget ? AppColors.danger.withAlpha(12) : AppColors.lightSurfaceVar,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverBudget ? AppColors.danger : AppColors.lightOutlineVar,
          width: isOverBudget ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Currency dropdown row
          Row(
            children: [
              _buildCurrencyDropdown(),
              const Spacer(),
              Text(
                'Amount',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.lightOnSurfaceVar,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Large amount field
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _selectedCurrency.symbol,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 36,
                      fontWeight: FontWeight.w300,
                      color: AppColors.lightOutline,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return AppStrings.fieldRequired;
                    if (double.tryParse(v) == null || double.parse(v) <= 0) {
                      return AppStrings.amountInvalid;
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          // INR conversion
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _amountCtrl.text.isEmpty
                ? const SizedBox(height: 22, key: ValueKey('empty'))
                : Padding(
                    key: const ValueKey('inr'),
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.currency_exchange_rounded,
                          size: 14,
                          color: isOverBudget ? AppColors.danger : AppColors.teal,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '= $_convertedFormatted',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isOverBudget ? AppColors.danger : AppColors.teal,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '@ ${_effectiveRate.toStringAsFixed(4)} $_tripCurrencyCode/${_selectedCurrency.code}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.lightOnSurfaceVar,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (isOverBudget)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Text(
                    'Exceeds budget — only ${_fmtTrip(remaining)} left',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrencyDropdown() {
    return GestureDetector(
      onTap: _showCurrencySheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.lightOutline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedCurrency.flag,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              _selectedCurrency.code,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.lightOnSurfaceVar),
          ],
        ),
      ),
    );
  }

  void _showCurrencySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CurrencyPickerSheet(
        selected: _selectedCurrency,
        tripCurrency: _tripCurrencyEntry,
        onSelect: (c) {
          setState(() {
            _selectedCurrency = c;
            _currencySynced   = true; // user made explicit choice — don't override
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Category grid ────────────────────────────────────────────────────────────
  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: _categories.length,
      itemBuilder: (_, i) => _buildCategoryCard(i),
    );
  }

  Widget _buildCategoryCard(int index) {
    final cat      = _categories[index];
    final selected = index == _selectedCategory;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.lightSurfaceVar,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.lightOutlineVar,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.primary.withAlpha(51), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withAlpha(51) : cat.color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(cat.icon, size: 22, color: selected ? Colors.white : cat.color),
            ),
            const SizedBox(height: 6),
            Text(
              cat.label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Note field ───────────────────────────────────────────────────────────────
  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteCtrl,
      maxLines: 2,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: AppColors.navy,
      ),
      decoration: InputDecoration(
        hintText: AppStrings.expenseNote,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 14, right: 10),
          child: Icon(Icons.sticky_note_2_outlined, size: 20, color: AppColors.lightOnSurfaceVar),
        ),
        prefixIconConstraints: const BoxConstraints(),
        filled: true,
        fillColor: AppColors.lightSurfaceVar,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightOutlineVar),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightOutlineVar),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  // ── Date picker ──────────────────────────────────────────────────────────────
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.lightSurfaceVar,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightOutlineVar),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryAlpha10,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _dateLabel,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ),
            Text(
              '${_selectedDate.day.toString().padLeft(2, '0')} / '
              '${_selectedDate.month.toString().padLeft(2, '0')} / '
              '${_selectedDate.year}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: AppColors.lightOnSurfaceVar,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.lightOnSurfaceVar),
          ],
        ),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.lightOnSurfaceVar,
        letterSpacing: 0.3,
      ),
    );
  }

  // ── Save button ──────────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, (bottomPadding > 0 ? bottomPadding + 12 : 28)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.lightOutlineVar)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                AppStrings.addExpense,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CURRENCY PICKER BOTTOM SHEET ────────────────────────────────────────────

class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet({
    required this.selected,
    required this.tripCurrency,
    required this.onSelect,
  });

  final CurrencyEntry selected;
  final CurrencyEntry tripCurrency;
  final ValueChanged<CurrencyEntry> onSelect;

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<CurrencyEntry> _filtered = kAllCurrencies;

  // Build list with trip currency pinned at top (when not searching)
  List<CurrencyEntry> _buildList(String q) {
    if (q.isEmpty) {
      final rest = kAllCurrencies
          .where((c) => c.code != widget.tripCurrency.code)
          .toList();
      return [widget.tripCurrency, ...rest];
    }
    final lower = q.toLowerCase();
    return kAllCurrencies
        .where((c) =>
            c.code.toLowerCase().contains(lower) ||
            c.name.toLowerCase().contains(lower))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _filtered = _buildList('');
  }

  void _onSearch(String q) {
    setState(() => _filtered = _buildList(q));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightOutline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const Text(
                'Select Currency',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              // Search field
              TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                autofocus: true,
                style: const TextStyle(fontFamily: 'Poppins'),
                decoration: InputDecoration(
                  hintText: 'Search currency or country...',
                  hintStyle: const TextStyle(fontFamily: 'Poppins'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.lightSurfaceVar,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              // Currency list
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No currencies found',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: AppColors.lightOnSurfaceVar,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final c = _filtered[i];
                          final isSelected  = c.code == widget.selected.code;
                          final isSearching = _searchCtrl.text.isNotEmpty;
                          final showTripHeader = !isSearching && i == 0;
                          final showAllHeader  = !isSearching && i == 1;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showTripHeader)
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(0, 4, 0, 2),
                                  child: Text(
                                    'TRIP CURRENCY',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              if (showAllHeader) ...[
                                const Divider(height: 20),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    'ALL CURRENCIES',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.lightOnSurfaceVar,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                                title: Text(
                                  c.code,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? AppColors.primary : AppColors.navy,
                                  ),
                                ),
                                subtitle: Text(
                                  c.name,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: AppColors.lightOnSurfaceVar,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded,
                                        color: AppColors.primary)
                                    : showTripHeader
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withAlpha(18),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: AppColors.primary.withAlpha(40)),
                                            ),
                                            child: const Text(
                                              'Trip',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          )
                                        : null,
                                onTap: () => widget.onSelect(c),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
