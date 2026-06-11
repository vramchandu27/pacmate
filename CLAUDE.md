# PacMate — Claude Code Project Context

## What This App Is
PacMate is a Flutter mobile app for backpackers.
The ultimate all-in-one travel companion app.
Target: iOS + Android via Flutter (Dart).

## Core Concept
One app that replaces 9 separate travel apps:
- AI Route Planner (Gemini API)
- Budget Tracker (multi-currency, real-time shared)
- Smart Packing List (AI-generated, weather-aware)
- Safety Tools (SOS, emergency numbers, scam alerts)
- Hidden Gems Finder (community map)
- Traveler Connect (real-time chat, buddy finder)
- Hotel Finder (Hostelworld + Booking.com API)
- Family Mode (lost child finder, allergy alerts)
- Senior Mode (medicine reminders, family tracking)

## Tech Stack
- Frontend: Flutter (Dart)
- Backend: Firebase (Firestore, Auth, Storage, FCM)
- AI: Gemini API (via Cloud Functions)
- Maps: Google Maps Flutter + Places API
- Currency: Exchange Rate API
- Weather: Open Meteo API (free, no key)
- Safety: Travel Advisory API (free, no key)
- Hotels: Hostelworld API + Google Places
- Subscriptions: RevenueCat
- State Management: Riverpod
- Navigation: GoRouter
- Local DB: Hive (offline support)
- Secure Storage: flutter_secure_storage
- Animations: Lottie

## Architecture Pattern
Feature-first folder structure:
lib/
  core/        → constants, theme, api services, security
  shared/      → reusable widgets, models, services
  features/    → auth, home, budget, packing, safety,
                 route_planner, hidden_gems, traveler_connect,
                 hotels, subscriptions, family, senior

Each feature has: screens/, controllers/, services/, models/

## Brand Colors
Primary Blue:   #378ADD
Success Green:  #639922
Danger Red:     #E24B4A
Warning Amber:  #BA7517
Teal:           #1D9E75
Purple:         #534AB7
Background:     #0F172A (splash/dark)
Font:           Poppins (Regular, Medium, SemiBold, Bold)

## Files Already Built
✅ main.dart
✅ app_router.dart (GoRouter, all routes)
✅ core/constants/app_constants.dart
✅ core/theme/app_theme.dart (full Material 3 theme)
✅ core/config/env_config.dart (dart-define API keys)
✅ core/network/firebase_service.dart
✅ core/api/cloud_functions_service.dart
✅ core/api/gemini_api_service.dart
✅ core/api/exchange_rate_service.dart
✅ core/api/weather_service.dart
✅ core/api/places_service.dart
✅ core/api/revenuecat_service.dart
✅ core/security/secure_storage_service.dart
✅ core/security/input_validator.dart
✅ core/security/rate_limiter.dart
✅ core/security/biometric_service.dart
✅ core/security/api_security_service.dart
✅ core/security/session_manager.dart
✅ core/security/privacy_service.dart
✅ features/auth/screens/splash_screen.dart (Lottie)
✅ features/auth/screens/onboarding_screen.dart (3 slides)
✅ features/auth/services/auth_service.dart
✅ features/budget/services/budget_service.dart
✅ features/hidden_gems/services/gems_service.dart
✅ features/traveler_connect/services/chat_service.dart
✅ features/senior/services/medicine_service.dart
✅ features/family/services/family_service.dart
✅ functions/index.js (8 Cloud Functions)

## Files To Build Next (in order)
1. features/auth/screens/login_screen.dart
2. features/auth/screens/signup_screen.dart
3. features/auth/screens/forgot_password_screen.dart
4. features/auth/screens/profile_setup_screen.dart
5. features/auth/controllers/auth_controller.dart
6. shared/models/user_model.dart
7. features/home/screens/home_screen.dart
8. features/home/screens/home_dashboard_view.dart
9. features/budget/screens/budget_screen.dart
10. features/budget/screens/add_expense_screen.dart

## Coding Standards
- Use Riverpod for ALL state management
- Use GoRouter for ALL navigation
- Use AppColors from app_theme.dart for ALL colors
- Use AppConstants for ALL string constants
- Use InputValidator for ALL form validation
- Use SecureStorageService for sensitive data
- NEVER hardcode API keys — use EnvConfig
- ALWAYS handle loading + error states
- ALWAYS add error handling with try/catch
- Use flutter_secure_storage for tokens
- Use Hive for offline data caching

## Key Routes (from app_router.dart)
AppRoutes.splash      = '/'
AppRoutes.onboarding  = '/onboarding'
AppRoutes.login       = '/login'
AppRoutes.signup      = '/signup'
AppRoutes.home        = '/home'
AppRoutes.budget      = '/budget'
AppRoutes.packing     = '/packing'
AppRoutes.safety      = '/safety'
AppRoutes.sos         = '/safety/sos'
AppRoutes.routePlanner= '/route-planner'
AppRoutes.gemsMap     = '/gems'
AppRoutes.connect     = '/connect'
AppRoutes.paywall     = '/paywall'
AppRoutes.familyDashboard = '/family'
AppRoutes.medicineManager = '/senior/medicines'

## Firestore Collections
users, trips, expenses, packingLists,
hiddenGems, gemReviews, chats,
safetyAlerts, medicines, familyLinks,
notifications, rateLimits, aiCache,
currencyCache, sosEvents

## API Keys (via --dart-define)
GOOGLE_MAPS_KEY  → console.cloud.google.com
GEMINI_KEY       → aistudio.google.com
EXCHANGE_RATE_KEY→ exchangerate-api.com
REVENUECAT_KEY   → revenuecat.com
(Open Meteo + Travel Advisory need NO key)

## Run Command
flutter run \
  --dart-define=GOOGLE_MAPS_KEY=YOUR_KEY \
  --dart-define=GEMINI_KEY=YOUR_KEY \
  --dart-define=EXCHANGE_RATE_KEY=YOUR_KEY \
  --dart-define=REVENUECAT_KEY=YOUR_KEY

## User Personas (for feature context)
1. Arjun (solo budget backpacker)
2. Bindhu (solo professional female)
3. Vikram & Sneha (married couple)
4. Sharma Family (family with kids — allergy alerts)
5. Venkat & Lakshmi (senior citizens — medicine reminders)

## Important Decisions Made
- NO Spring Boot / Java backend needed
- Firebase replaces all backend needs
- Cloud Functions (Node.js) for AI calls + SOS
- RevenueCat for subscriptions (NOT Stripe)
- Firestore offline persistence enabled
- AES-256 encryption for medical data
- Rate limiting: 5 logins/15min, 10 AI calls/day
- Gemini results cached 24hrs in Firestore
- Currency rates cached 1hr in SharedPreferences

## Subscription Plans
Free:     Basic budget, 1 trip, basic safety
Explorer: ₹299/month — AI features, offline maps, gems
Pro:      ₹599/month — Everything + Traveler Connect
