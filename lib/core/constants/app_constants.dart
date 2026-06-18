// ─── APP CONSTANTS ────────────────────────────────────────────────────────────
// Single source of truth for all magic strings in PacMate.
// Never hardcode routes, collection names, asset paths, or UI strings inline.
// ─────────────────────────────────────────────────────────────────────────────

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String verifyEmail    = '/verify-email';
  static const String profileSetup   = '/profile-setup';
  static const String home = '/home';

  // Budget
  static const String budget = '/budget';
  static const String createTrip = '/budget/create-trip';
  static const String addExpense = '/budget/add-expense';
  static const String budgetReport = '/budget/report';
  static const String allTrips    = '/budget/all-trips';

  // Packing
  static const String packing = '/packing';
  static const String packingList = '/packing/list';
  static String packingListOf(String id) => '/packing/list/$id';

  // Hidden Gems
  static const String gemsMap = '/gems';
  static const String addGem = '/gems/add';
  static const String newGems = '/gems/new';
  static const String gemDetail = '/gems/:gemId';
  static String gemDetailOf(String id) => '/gems/$id';
  static String newGemsOf(List<String> ids, String city) =>
      '/gems/new?ids=${ids.join(',')}&city=${Uri.encodeComponent(city)}';

  // Route Planner
  static const String routePlanner = '/route-planner';
  static const String routeResult  = '/route-planner/result';

  // Profile & system
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String notifications  = '/notifications';
  static const String sessionExpired = '/session-expired';
}

class AppCollections {
  AppCollections._();

  static const String users = 'users';
  static const String trips = 'trips';
  static const String expenses = 'expenses';
  static const String packingLists = 'packingLists';
  static const String packingItems = 'packingItems';
  static const String hiddenGems = 'hiddenGems';
  static const String gemReviews = 'gemReviews';
  static const String notifications = 'notifications';
  static const String rateLimits = 'rateLimits';
  static const String aiCache = 'aiCache';
  static const String currencyCache = 'currencyCache';
}

class AppLottie {
  AppLottie._();

  static const String _base = 'assets/animations/';

  static const String splash = '${_base}splash.json';
  static const String onboarding1 = '${_base}onboarding_travel.json';
  static const String onboarding2 = '${_base}onboarding_budget.json';
  static const String onboarding3 = '${_base}onboarding_safety.json';
  static const String login = '${_base}login_travel.json';

  static const String loading = '${_base}loading.json';
  static const String success = '${_base}success.json';
  static const String error = '${_base}error.json';
  static const String empty = '${_base}empty.json';
  static const String noInternet = '${_base}no_internet.json';
  static const String notFound = '${_base}not_found.json';

  static const String aiThinking = '${_base}ai_thinking.json';
  static const String mapSearch = '${_base}map_search.json';
  static const String budgetDone = '${_base}budget_done.json';
  static const String packingDone = '${_base}packing_done.json';
  static const String locationPin = '${_base}location_pin.json';
  static const String confetti = '${_base}confetti.json';
}

class AppImages {
  AppImages._();

  static const String _base = 'assets/images/';

  static const String logo = '${_base}pacmate_logo.png';
  static const String logoWhite = '${_base}pacmate_logo_white.png';
  static const String placeholder = '${_base}placeholder.png';
  static const String avatarDefault = '${_base}avatar_default.png';
  static const String mapFallback = '${_base}map_fallback.png';
  static const String onboarding1 = '${_base}onboarding_1.png';
  static const String onboarding2 = '${_base}onboarding_2.png';
  static const String onboarding3 = '${_base}onboarding_3.png';
}

class AppIcons {
  AppIcons._();

  static const String _base = 'assets/icons/';

  static const String budget = '${_base}budget.svg';
  static const String packing = '${_base}packing.svg';
  static const String hiddenGems = '${_base}hidden_gems.svg';
}

class AppStrings {
  AppStrings._();

  // ── App ──────────────────────────────────────────────────────────────────
  static const String appName = 'PacMate';
  static const String appTagline = 'Your ultimate travel companion';
  static const String appVersion = '1.0.0';

  // ── Onboarding ───────────────────────────────────────────────────────────
  static const String onboarding1Title = 'Track Every Rupee';
  static const String onboarding1Subtitle =
      'Real-time multi-currency budget tracking for your entire trip.';
  static const String onboarding2Title = 'Pack Smarter';
  static const String onboarding2Subtitle =
      'AI-powered packing lists tailored to your destination and weather.';
  static const String onboarding3Title = 'Discover Hidden Gems';
  static const String onboarding3Subtitle =
      'Find secret spots loved by locals — shared by real travellers like you.';
  static const String getStarted = 'Get Started';
  static const String skip = 'Skip';
  static const String next = 'Next';

  // ── Auth ─────────────────────────────────────────────────────────────────
  static const String login = 'Login';
  static const String signup = 'Sign Up';
  static const String logout = 'Log Out';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';
  static const String emailLabel = 'Email address';
  static const String emailHint = 'you@example.com';
  static const String passwordLabel = 'Password';
  static const String passwordHint = 'Min. 8 characters';
  static const String confirmPasswordLabel = 'Confirm password';
  static const String nameLabel = 'Full name';
  static const String nameHint = 'What should we call you?';
  static const String phoneLabel = 'Phone number';
  static const String phoneHint = '+91 00000 00000';
  static const String continueWithGoogle = 'Continue with Google';
  static const String orDivider = 'OR';
  static const String alreadyHaveAccount = 'Already have an account? ';
  static const String dontHaveAccount = "Don't have an account? ";
  static const String loginLink = 'Log in';
  static const String signupLink = 'Sign up';
  static const String resetEmailSent =
      'Password reset email sent. Check your inbox.';
  static const String profileSetupTitle = 'Set Up Your Profile';
  static const String profileSetupSubtitle =
      'Tell us a bit about yourself so we can personalise your experience.';
  static const String travelStyleLabel = 'Your travel style';
  static const String homeCurrencyLabel = 'Home currency';
  static const String saveProfile = 'Save Profile';

  // ── Validation ───────────────────────────────────────────────────────────
  static const String fieldRequired = 'This field is required.';
  static const String emailInvalid = 'Enter a valid email address.';
  static const String passwordTooShort =
      'Password must be at least 8 characters.';
  static const String passwordNoMatch = 'Passwords do not match.';
  static const String passwordWeak = 'Use letters, numbers, and a symbol.';
  static const String nameTooShort = 'Name must be at least 2 characters.';
  static const String phoneInvalid = 'Enter a valid phone number.';
  static const String amountInvalid = 'Enter a valid amount.';

  // ── Home ─────────────────────────────────────────────────────────────────
  static const String homeGreetingMorning = 'Good morning';
  static const String homeGreetingAfternoon = 'Good afternoon';
  static const String homeGreetingEvening = 'Good evening';
  static const String homeTagline = 'Where to next?';
  static const String quickActions = 'Quick Actions';
  static const String recentTrips = 'Recent Trips';
  static const String noTripsYet = "No trips yet. Let's plan one!";
  static const String startPlanning = 'Start Planning';
  static const String viewAll = 'View All';
  static const String myTrips = 'My Trips';

  // ── Budget ───────────────────────────────────────────────────────────────
  static const String budgetTitle = 'Budget Tracker';
  static const String totalBudget = 'Total Budget';
  static const String totalSpent = 'Total Spent';
  static const String remaining = 'Remaining';
  static const String addExpense = 'Add Expense';
  static const String expenseTitle = 'Expense title';
  static const String expenseAmount = 'Amount';
  static const String expenseCategory = 'Category';
  static const String expenseDate = 'Date';
  static const String expenseNote = 'Note (optional)';
  static const String noExpensesYet = 'No expenses yet. Start tracking!';
  static const String splitWith = 'Split with group';
  static const String categories = 'Categories';

  static const List<String> expenseCategories = [
    'Food & Drinks',
    'Accommodation',
    'Transport',
    'Activities',
    'Shopping',
    'Health',
    'Communication',
    'Visa & Fees',
    'Other',
  ];

  // ── Packing ──────────────────────────────────────────────────────────────
  static const String packingTitle = 'Packing Lists';
  static const String newPackingList = 'New List';
  static const String generateWithAI = 'Generate with AI';
  static const String aiPackingHint =
      'Describe your trip (e.g. 10-day Ladakh trek in July)';
  static const String addItem = 'Add Item';
  static const String itemName = 'Item name';
  static const String itemCategory = 'Category';
  static const String markAllPacked = 'Mark All Packed';
  static const String noPackingLists = 'No packing lists yet.';
  static const String packedCount = 'packed';

  // ── Hidden Gems ──────────────────────────────────────────────────────────
  static const String gemsTitle = 'Hidden Gems';
  static const String addGem = 'Add a Gem';
  static const String gemName = 'Place name';
  static const String gemDescription = 'What makes it special?';
  static const String gemCategory = 'Category';
  static const String gemLocation = 'Location';
  static const String noGemsNearby =
      'No gems discovered nearby yet. Be the first!';
  static const String nearbyGems = 'Nearby Gems';
  static const String topRated = 'Top Rated';

  static const List<String> gemCategories = [
    'Viewpoint',
    'Street Food',
    'Local Market',
    'Hidden Beach',
    'Waterfall',
    'Cafe',
    'Temple / Shrine',
    'Village',
    'Nature Trail',
    'Other',
  ];

  // ── Profile & Settings ───────────────────────────────────────────────────
  static const String profileTitle = 'My Profile';
  static const String settingsTitle = 'Settings';
  static const String editProfile = 'Edit Profile';
  static const String darkMode = 'Dark Mode';
  static const String notifications = 'Notifications';
  static const String language = 'Language';
  static const String currency = 'Home Currency';
  static const String privacy = 'Privacy Policy';
  static const String termsOfService = 'Terms of Service';
  static const String helpSupport = 'Help & Support';
  static const String deleteAccount = 'Delete Account';
  static const String deleteAccountWarn =
      'This action is permanent and cannot be undone.';
  static const String appVersionLabel = 'App Version';

  // ── Common UI ────────────────────────────────────────────────────────────
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String done = 'Done';
  static const String close = 'Close';
  static const String back = 'Back';
  static const String retry = 'Retry';
  static const String refresh = 'Refresh';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String share = 'Share';
  static const String copy = 'Copy';
  static const String ok = 'OK';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String loading = 'Loading…';
  static const String pleaseWait = 'Please wait…';
  static const String somethingWrong =
      'Something went wrong. Please try again.';
  static const String noInternet = 'No internet connection.';
  static const String offlineMode = 'You\'re offline — showing cached data.';
  static const String sessionExpired =
      'Your session has expired. Please log in again.';
  static const String permissionDenied = 'Permission denied.';
  static const String locationRequired =
      'Location permission is required for this feature.';
  static const String cameraRequired = 'Camera permission is required.';

  // ── Rate Limiting ────────────────────────────────────────────────────────
  static const String rateLimitLogin =
      'Too many login attempts. Try again in 15 minutes.';
  static const String rateLimitAI =
      'Daily AI limit reached (10/day). Upgrade for unlimited access.';

  // ── AI ───────────────────────────────────────────────────────────────────
  static const String aiGenerating = 'Gemini is thinking…';
  static const String aiError =
      'AI is unavailable right now. Try again shortly.';
  static const String aiCacheNote = 'Results may be up to 24 hours old.';
}

class AppDurations {
  AppDurations._();

  static const Duration snackBar = Duration(seconds: 3);
  static const Duration pageTransition = Duration(milliseconds: 300);
  static const Duration shimmerCycle = Duration(milliseconds: 1500);
  static const Duration splashMin = Duration(seconds: 2);
  static const Duration debounce = Duration(milliseconds: 500);
  static const Duration aiCacheTTL = Duration(hours: 24);
  static const Duration currencyCacheTTL = Duration(hours: 1);
  static const Duration sessionTimeout = Duration(minutes: 30);
}

class AppLimits {
  AppLimits._();

  static const int maxLoginAttempts = 5;
  static const int loginWindowMinutes = 15;
  static const int maxAICallsPerDay = 10;
  static const int maxTripsFreePlan = 1;
  static const int maxImageUploadMB = 5;
  static const int maxPackingItems = 100;
  static const int maxExpenses = 500;
  static const int gemReviewsPageSize = 20;
  static const double nearbyGemsRadiusKm = 5.0;
}
