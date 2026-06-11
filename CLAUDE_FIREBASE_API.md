# PacMate — Complete Firebase & API Implementation Guide

## Project Overview
PacMate is a Flutter travel companion app for backpackers.
- Frontend: Flutter (Dart)
- Backend: Firebase (Firestore, Auth, Storage, FCM, Cloud Functions)
- AI: Gemini API via Cloud Functions
- Maps: Google Maps API
- Other APIs: Exchange Rate, Weather, Travel Advisory, RevenueCat

## Current Status
✅ All 29 screens built with mock data
⬜ Phase 2: Firebase implementation
⬜ Phase 3: API integration

---

# PHASE 2 — FIREBASE IMPLEMENTATION

## Firebase Setup

### 1. Initialize Firebase
```bash
flutterfire configure
# This auto-generates lib/core/network/firebase_options.dart
# Connects Android and iOS
```

### 2. Update pubspec.yaml — Add Firebase packages
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
  firebase_storage: ^4.0.11
  firebase_messaging: ^14.7.9
  firebase_analytics: ^10.7.0
  firebase_crashlytics: ^3.4.0
  firebase_app_check: ^0.2.1
```

### 3. Main.dart — Initialize Firebase
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await FirebaseAppCheck.instance.activate(
    webRecaptchaSiteKey: null,
  );
  
  // Setup Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  runApp(const MyApp());
}
```

---

## Firebase Services to Create

### File: lib/core/network/auth_service.dart

Features:
- Email/Password signup
- Email/Password login  
- Google Sign-In
- Forgot password
- Sign out
- Delete account
- Automatic user profile creation in Firestore

Methods:
```
signUpWithEmail(email, password, fullName)
signInWithEmail(email, password)
signInWithGoogle()
sendPasswordResetEmail(email)
signOut()
deleteAccount()
isProfileComplete()
```

### File: lib/core/network/firebase_service.dart

Purpose: Central Firebase hub — exposes all services

Singleton instances:
```
FirebaseAuth auth
FirebaseFirestore firestore
FirebaseStorage storage
FirebaseMessaging messaging
FirebaseAnalytics analytics
FirebaseCrashlytics crashlytics
```

Helper methods:
```
initialize()                    # Setup all services
getCurrentUser()               # Current logged-in user
isLoggedIn()                   # Bool check
getCurrentUserId()             # UID string
usersRef                       # Firestore users collection
tripsRef                       # Trips collection
expensesRef                    # Expenses collection
... (all collections as properties)

logEvent(name, params)         # Analytics
logLogin(method)
logSignUp(method)
logTripCreated(destination)
logExpenseAdded(category, amount)
```

### File: lib/features/budget/services/budget_service.dart

Methods:
```
createTrip(destination, startDate, endDate, 
           totalBudget, currency) → tripId

addExpense(tripId, amount, convertedAmountINR,
           originalCurrency, category, note,
           paidBy, splitEqually, splitBetween)

getExpenses(tripId) → Stream<List<ExpenseModel>>

getActiveTrip() → Stream<BudgetModel>

deleteExpense(expenseId, tripId, amount)

getExpensesByCategory(tripId) → 
  Map<String, double>

convertCurrency(amount, from, to) → double
```

### File: lib/features/hidden_gems/services/gems_service.dart

Methods:
```
getGemsNearby(latitude, longitude, category) 
  → Stream<List<GemModel>>

addGem(name, description, category,
       latitude, longitude, city, country,
       photos) → gemId

upvoteGem(gemId)

saveGem(gemId)

getGemById(gemId) → GemModel

getMyGems() → Stream<List<GemModel>>
```

### File: lib/features/traveler_connect/services/chat_service.dart

Methods:
```
getOrCreateChat(otherUserId) → chatId

sendMessage(chatId, text)

getMessages(chatId) → Stream<List<MessageModel>>

markAsRead(chatId)

getUserChats() → Stream<List<ChatData>>
```

### File: lib/features/senior/services/medicine_service.dart

Methods:
```
initialize()                   # Setup local notifications

addMedicine(name, condition, times,
            instructions, totalTablets,
            assignedTo)

markAsTaken(medicineId)

getMedicines() → Stream<List<MedicineModel>>

deleteMedicine(medicineId)
```

### File: lib/features/family/services/family_service.dart

Methods:
```
startSharingLocation()         # Continuous GPS updates

watchFamilyMember(memberId) 
  → Stream<FamilyMemberModel>

inviteFamilyMember(parentId, childId,
                   relationship)

getFamilyMembers() 
  → Stream<List<FamilyMemberModel>>

sendSOSAlert(latitude, longitude, address)

stopSharingLocation()
```

---

## Firestore Collections & Schema

### users collection
```
users/{userId}
├── uid: string
├── email: string
├── fullName: string
├── photoUrl: string?
├── homeCountry: string
├── currency: string (INR)
├── travelStyle: string (budget/mid/luxury)
├── travelType: string (solo/couple/family/group)
├── seniorMode: boolean
├── familyMode: boolean
├── isPro: boolean
├── plan: string (free/explorer/pro)
├── fcmToken: string?
├── location: GeoPoint? (for family tracking)
├── isOnline: boolean
├── profileComplete: boolean
├── totalTrips: number
├── createdAt: timestamp
└── lastSeen: timestamp
```

### trips collection
```
trips/{tripId}
├── userId: string
├── destination: string
├── startDate: timestamp
├── endDate: timestamp
├── totalBudget: number
├── currency: string
├── totalSpent: number
├── isActive: boolean
├── members: array<string> (user IDs)
├── createdAt: timestamp
└── updatedAt: timestamp
```

### expenses collection
```
expenses/{expenseId}
├── tripId: string
├── userId: string
├── amount: number (original currency)
├── convertedAmountINR: number
├── originalCurrency: string (SGD, THB, etc)
├── category: string (Food, Transport, Stay, etc)
├── note: string?
├── paidBy: string (user ID who paid)
├── splitEqually: boolean
├── splitBetween: array<string>? (user IDs)
├── date: timestamp
└── createdAt: timestamp
```

### packingLists collection
```
packingLists/{listId}
├── userId: string
├── tripId: string
├── items: array
│   ├── id: string
│   ├── name: string
│   ├── category: string
│   ├── checked: boolean
│   ├── quantity: number
│   └── notes: string?
├── generatedByAI: boolean
├── sharedWith: array<string>?
├── createdAt: timestamp
└── updatedAt: timestamp
```

### hiddenGems collection
```
hiddenGems/{gemId}
├── name: string
├── description: string
├── category: string (Food, Nature, Arts, Beach, etc)
├── location: GeoPoint
├── city: string
├── country: string
├── photos: array<string> (URLs)
├── addedBy: string (user ID)
├── upvotes: number
├── downvotes: number
├── isVerified: boolean
├── createdAt: timestamp
└── updatedAt: timestamp
```

### chats collection
```
chats/{chatId}
├── participants: array<string> (2 user IDs)
├── lastMessage: string
├── lastMessageTime: timestamp
├── createdAt: timestamp
└── messages (subcollection)
    └── messages/{messageId}
        ├── text: string
        ├── sentBy: string (user ID)
        ├── sentAt: timestamp
        ├── isRead: boolean
        └── reactions: map? (emoji → count)
```

### medicines collection
```
medicines/{medicineId}
├── userId: string
├── assignedTo: string (same or family member ID)
├── name: string
├── condition: string
├── times: array<string> (["08:00", "20:00"])
├── instructions: string
├── totalTablets: number
├── tabletsRemaining: number
├── isActive: boolean
├── takenDates: array<string>? (["2026-04-17"])
├── lastTaken: timestamp?
├── createdAt: timestamp
└── missedDoses: array<string>?
```

### familyLinks collection
```
familyLinks/{linkId}
├── parentId: string (being tracked)
├── childId: string (doing tracking)
├── relationship: string (son/daughter/parent/etc)
├── isActive: boolean
├── trackingEnabled: boolean
├── createdAt: timestamp
└── acceptedAt: timestamp?
```

### safetyAlerts collection
```
safetyAlerts/{country}
├── countryCode: string (TH, SG, IN, etc)
├── countryName: string
├── score: number (1-5)
├── message: string
├── updatedAt: timestamp
└── sources: number
```

### notifications collection
```
notifications/{notifId}
├── to: string (recipient user ID)
├── from: string (sender user ID)
├── type: string (sos_alert, medicine_missed, message, etc)
├── title: string
├── body: string
├── data: map? (extra data)
├── isRead: boolean
├── timestamp: timestamp
└── expiresAt: timestamp?
```

### Additional Collections
```
rateLimits/{userId}_action_date
├── count: number
└── updatedAt: timestamp

aiCache/{key}
├── result: map
├── expiresAt: timestamp
└── createdAt: timestamp

currencyCache/{baseCurrency}
├── rates: map<string, number>
├── base: string
└── updatedAt: timestamp

sosEvents/{sosId}
├── userId: string
├── userName: string
├── latitude: number
├── longitude: number
├── address: string
├── familyNotified: number
└── timestamp: timestamp
```

---

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAuth() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return request.auth.uid == userId;
    }

    function isParticipant() {
      return request.auth.uid in resource.data.participants;
    }

    function validString(field, minLen, maxLen) {
      return request.resource.data[field] is string
          && request.resource.data[field].size() >= minLen
          && request.resource.data[field].size() <= maxLen;
    }

    // Users
    match /users/{userId} {
      allow read: if isAuth() && isOwner(userId);
      allow create: if isAuth() && isOwner(userId)
                    && validString('fullName', 2, 100)
                    && validString('email', 5, 255);
      allow update: if isAuth() && isOwner(userId)
                    && request.resource.data.uid == resource.data.uid;
      allow delete: if false;
    }

    // Trips
    match /trips/{tripId} {
      allow read: if isAuth()
                  && (resource.data.userId == request.auth.uid
                  || request.auth.uid in resource.data.members);
      allow create: if isAuth()
                    && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isAuth()
                            && resource.data.userId == request.auth.uid;
    }

    // Expenses
    match /expenses/{expenseId} {
      allow read: if isAuth()
                  && resource.data.userId == request.auth.uid;
      allow create: if isAuth()
                    && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isAuth()
                            && resource.data.userId == request.auth.uid;
    }

    // Packing Lists
    match /packingLists/{listId} {
      allow read: if isAuth()
                  && (resource.data.userId == request.auth.uid
                  || request.auth.uid in resource.data.sharedWith);
      allow create: if isAuth()
                    && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isAuth()
                            && resource.data.userId == request.auth.uid;
    }

    // Hidden Gems
    match /hiddenGems/{gemId} {
      allow read: if isAuth();
      allow create: if isAuth()
                    && request.resource.data.addedBy == request.auth.uid;
      allow update: if isAuth()
                    && resource.data.addedBy == request.auth.uid;
      allow delete: if isAuth()
                    && resource.data.addedBy == request.auth.uid;
    }

    // Chats
    match /chats/{chatId} {
      allow read: if isAuth() && isParticipant();
      allow create: if isAuth()
                    && request.auth.uid in request.resource.data.participants;
      allow update: if isAuth() && isParticipant();
      
      match /messages/{messageId} {
        allow read: if isAuth()
                    && request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
        allow create: if isAuth()
                      && request.resource.data.sentBy == request.auth.uid;
        allow update, delete: if false;
      }
    }

    // Medicines
    match /medicines/{medicineId} {
      allow read: if isAuth()
                  && (resource.data.userId == request.auth.uid
                  || resource.data.assignedTo == request.auth.uid);
      allow create: if isAuth()
                    && request.resource.data.userId == request.auth.uid;
      allow update: if isAuth()
                    && (resource.data.userId == request.auth.uid
                    || resource.data.assignedTo == request.auth.uid);
      allow delete: if isAuth()
                    && resource.data.userId == request.auth.uid;
    }

    // Family Links
    match /familyLinks/{linkId} {
      allow read: if isAuth()
                  && (resource.data.parentId == request.auth.uid
                  || resource.data.childId == request.auth.uid);
      allow create: if isAuth();
      allow update: if isAuth()
                    && (resource.data.parentId == request.auth.uid
                    || resource.data.childId == request.auth.uid);
      allow delete: if false;
    }

    // Notifications
    match /notifications/{notifId} {
      allow read: if isAuth()
                  && resource.data.to == request.auth.uid;
      allow create: if isAuth();
      allow update: if isAuth()
                    && resource.data.to == request.auth.uid;
      allow delete: if false;
    }

    // Catch all — deny everything else
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Firebase Storage Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    match /profile_photos/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.auth.uid == userId
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }

    match /gem_photos/{gemId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 10 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }

    match /trip_photos/{tripId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 10 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }

    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Firebase Console Setup

### Enable Services
1. Authentication → Enable Email/Password + Google
2. Firestore Database → Create → TEST MODE → asia-south1
3. Storage → Get Started → TEST MODE
4. Cloud Messaging → Already enabled
5. Crashlytics → Already enabled
6. Cloud Functions → Enable (for Phase 3)

### Security Settings
1. Auth → Settings → Enable Email Enumeration Protection
2. Auth → Settings → Enable Google reCAPTCHA
3. Firestore → Deploy security rules (from above)
4. Storage → Deploy storage rules (from above)

---

# PHASE 3 — API INTEGRATION

## API Keys Setup

### 1. Google Maps API
```
Where: console.cloud.google.com
Enable APIs:
  - Maps SDK for Android
  - Maps SDK for iOS
  - Places API
  - Directions API
  - Geocoding API

Cost: Free $200/month credit
```

### 2. Gemini AI API
```
Where: aistudio.google.com
Cost: Free tier — 60 requests/min
Create Cloud Functions to call this
(never call directly from app)
```

### 3. Exchange Rate API
```
Where: exchangerate-api.com
Cost: Free 1,500 calls/month
Direct API calls from app are safe
```

### 4. RevenueCat (Subscriptions)
```
Where: revenuecat.com
Cost: Free until $2.5K MRR
Setup products:
  - explorer_monthly (₹299)
  - pro_monthly (₹599)
Connect Google Play + App Store
```

### 5. Open Meteo (Weather)
```
Where: api.open-meteo.com
Cost: Free forever
No signup needed
```

### 6. Travel Advisory (Safety)
```
Where: travel-advisory.info/api
Cost: Free forever
No signup needed
```

---

## Cloud Functions Setup

### Deploy Functions
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### Functions to Deploy

#### Function 1: generatePackingList
```
Input: destination, durationDays, month,
       travelStyle, activities, accommodation,
       isSoloFemale, nutAllergy, hasKids,
       kidsAges, isSenior, medicalConditions

Process:
1. Check user authentication
2. Rate limit: max 10 AI calls/day
3. Check subscription (Explorer/Pro)
4. Build detailed prompt
5. Call Gemini API
6. Cache result 24 hours in Firestore
7. Return JSON result

Output: Map<category, List<items>>
```

#### Function 2: generateRoute
```
Input: startCity, endCity, durationDays,
       dailyBudgetINR, interests, pace,
       isSenior, maxWalkingKm, vegetarianOnly

Process:
1. Check auth
2. Rate limit: max 5 routes/day
3. Check subscription
4. Build detailed itinerary prompt
5. Call Gemini API
6. Cache 24 hours
7. Return day-by-day itinerary

Output: List<DayItinerary>
```

#### Function 3: getExchangeRates
```
Input: baseCurrency (default INR)

Process:
1. Check cache (1 hour)
2. If cached, return cached rates
3. Call Exchange Rate API
4. Cache in Firestore
5. Return rates map

Output: Map<currency, rate>
```

#### Function 4: sendNotification
```
Input: toUserId, title, body, type, extraData

Process:
1. Check auth
2. Get user's FCM token
3. Send FCM notification
4. Save to notifications collection

Output: success boolean
```

#### Function 5: triggerSOS
```
Input: latitude, longitude, address

Process:
1. Check auth
2. Get all family member FCM tokens
3. Send high-priority SOS alert to all
4. Save SOS event to audit log
5. Update user location

Output: familyNotified count
```

#### Function 6: checkMedicineMissed
```
Trigger: Pub/Sub every 30 minutes

Process:
1. Get all active medicines
2. Check which ones are overdue
3. For overdue medicines:
   - Get family members
   - Send FCM alert to family
   - Save notification

Output: None (runs automatically)
```

#### Function 7: onUserCreated
```
Trigger: Firebase Auth user created

Process:
1. Create user profile in Firestore
2. Give 7-day free trial
3. Send welcome notification
4. Setup Stripe customer

Output: None (automatic)
```

#### Function 8: onUserDeleted
```
Trigger: Firebase Auth user deleted

Process:
1. Delete all user data from Firestore:
   - Profile
   - Trips
   - Expenses
   - Packing lists
   - Medicines
   - Family links
2. Delete all files from Storage
3. Delete Stripe customer

Output: None (automatic)
```

---

## API Services to Create

### File: lib/core/api/cloud_functions_service.dart
```
Methods:
- generatePackingList() → Map<String, List<String>>
- generateRoute() → List<Map<String, dynamic>>
- getExchangeRates() → Map<String, double>
- triggerSOS() → Map<String, dynamic>
- sendNotification() → void
```

### File: lib/core/api/gemini_api_service.dart
```
Methods:
- generatePackingList() (via Cloud Functions)
- generateRoute() (via Cloud Functions)
Note: Direct Gemini calls go through Cloud Functions
```

### File: lib/core/api/exchange_rate_service.dart
```
Methods:
- getRate(from, to) → double
- convert(amount, from, to) → double
- getAllRatesFromINR() → Map<String, double>
Caching: 1 hour in SharedPreferences
```

### File: lib/core/api/weather_service.dart
```
Methods:
- getWeather(latitude, longitude) → WeatherData
- getWeatherDescription() → String
- getWeatherPackingTips() → List<String>
API: Open Meteo (free, no key)
```

### File: lib/core/api/travel_advisory_service.dart
```
Methods:
- getCountrySafety(countryCode) → SafetyData
API: travel-advisory.info (free, no key)
Returns: safety score 1-5, message, updated date
```

### File: lib/core/api/places_service.dart
```
Methods:
- searchNearbyHotels() → List<PlaceResult>
- searchNearbyRestaurants() → List<PlaceResult>
- getPlaceDetails() → PlaceDetails
- textSearch() → List<PlaceResult>
- getPhotoUrl() → String
API: Google Maps Places (needs GOOGLE_MAPS_KEY)
```

### File: lib/core/api/revenuecat_service.dart
```
Methods:
- initialize() → void
- getStatus() → SubscriptionStatus
- canAccess(feature) → bool
- getOfferings() → Offerings
- purchase(package) → PurchaseResult
- restorePurchases() → bool
- startFreeTrial(package) → PurchaseResult
```

---

## Environment Variables (--dart-define)

```bash
flutter run \
  --dart-define=GOOGLE_MAPS_KEY=AIzaSy... \
  --dart-define=GEMINI_KEY=AIzaSy... \
  --dart-define=EXCHANGE_RATE_KEY=abc123 \
  --dart-define=REVENUECAT_KEY=appl_... \
  --dart-define=HOSTELWORLD_KEY=hw_...
```

### File: lib/core/config/env_config.dart
```dart
class EnvConfig {
  static const String googleMapsKey =
    String.fromEnvironment('GOOGLE_MAPS_KEY');
  
  static const String geminiKey =
    String.fromEnvironment('GEMINI_KEY');
  
  static const String exchangeRateKey =
    String.fromEnvironment('EXCHANGE_RATE_KEY');
  
  static const String revenueCatKey =
    String.fromEnvironment('REVENUECAT_KEY');
}
```

---

## Implementation Order for Phase 2

1. Setup Firebase with flutterfire configure
2. Create auth_service.dart
3. Create firebase_service.dart
4. Update main.dart
5. Update login_screen.dart to use real auth
6. Update signup_screen.dart
7. Create budget_service.dart
8. Update budget_screen.dart
9. Create gems_service.dart
10. Update gems screens
11. Create chat_service.dart
12. Update chat screen
13. Create medicine_service.dart
14. Create family_service.dart
15. Test all screens with real Firebase

---

## Implementation Order for Phase 3

1. Setup Cloud Functions
2. Create cloud_functions_service.dart
3. Create gemini_api_service.dart
4. Create exchange_rate_service.dart
5. Create weather_service.dart
6. Create travel_advisory_service.dart
7. Create places_service.dart
8. Create revenuecat_service.dart
9. Update packing_list_screen with AI
10. Update route_planner_screen with AI
11. Update budget_screen with real exchange rates
12. Update gems_map_screen with real Google Maps
13. Update hotel_finder with real data
14. Update paywall_screen with RevenueCat
15. Test all APIs end-to-end

---

## Testing Checklist

### Phase 2 Tests
- [ ] Signup with email works
- [ ] Login with email works
- [ ] Google Sign-In works
- [ ] User profile saves to Firestore
- [ ] Create trip saves to Firestore
- [ ] Add expense saves to real database
- [ ] Expenses show in real-time
- [ ] Chat messages sync in real-time
- [ ] Medicine reminders notify
- [ ] SOS sends alerts to family
- [ ] Logout clears session

### Phase 3 Tests
- [ ] AI packing list generates
- [ ] AI route planner generates
- [ ] Currency conversion shows correct rates
- [ ] Weather data updates packing suggestions
- [ ] Safety score displays for country
- [ ] Google Maps shows real hotels
- [ ] RevenueCat paywall shows plans
- [ ] Subscribing works end-to-end
- [ ] Geolocation tracks in family mode
- [ ] Push notifications arrive

---

## Files Already Built (No Changes Needed)
✅ main.dart (base structure ready)
✅ app_router.dart (all routes defined)
✅ app_theme.dart (colors defined)
✅ app_constants.dart (constants ready)
✅ All 29 screens (UI complete)
✅ CLAUDE.md (this file)

## Files To Create (Phase 2)
⬜ lib/core/network/auth_service.dart
⬜ lib/core/network/firebase_service.dart
⬜ lib/core/config/env_config.dart
⬜ lib/features/budget/services/budget_service.dart
⬜ lib/features/hidden_gems/services/gems_service.dart
⬜ lib/features/traveler_connect/services/chat_service.dart
⬜ lib/features/senior/services/medicine_service.dart
⬜ lib/features/family/services/family_service.dart
⬜ functions/index.js (Cloud Functions)

## Files To Create (Phase 3)
⬜ lib/core/api/cloud_functions_service.dart
⬜ lib/core/api/gemini_api_service.dart
⬜ lib/core/api/exchange_rate_service.dart
⬜ lib/core/api/weather_service.dart
⬜ lib/core/api/travel_advisory_service.dart
⬜ lib/core/api/places_service.dart
⬜ lib/core/api/revenuecat_service.dart

## Updates Needed (Phase 2)
⬜ Update main.dart to initialize Firebase
⬜ Update login_screen.dart to use real auth
⬜ Update signup_screen.dart to use real auth
⬜ Update budget_screen.dart to use real data
⬜ Update chat_screen.dart to use real data
⬜ Add missing packages to pubspec.yaml

## Updates Needed (Phase 3)
⬜ Update packing_list_screen with Gemini
⬜ Update route_planner_screen with Gemini
⬜ Update budget screens with exchange rates
⬜ Update gems_map_screen with Google Maps
⬜ Update hotel_finder_screen with real data
⬜ Update paywall_screen with RevenueCat
