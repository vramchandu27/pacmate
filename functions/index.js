const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { user: authUser } = require('firebase-functions/v1/auth');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const axios = require('axios');

const GEMINI_KEY       = defineSecret('GEMINI_KEY');
const EXCHANGE_RATE_KEY = defineSecret('EXCHANGE_RATE_KEY');
const PLACES_KEY       = defineSecret('PLACES_KEY');

admin.initializeApp();
const db = admin.firestore();

// ─── ABUSE PROTECTION HELPERS ─────────────────────────────────────────────────

/**
 * Fixed-window rate limiter with per-minute, per-hour, and per-day counters.
 * Each counter resets independently when its window expires.
 * Throws HttpsError('resource-exhausted') when a limit is breached.
 *
 * @param {string} uid   - Firebase UID (or 'global' for anonymous checks).
 * @param {string} action - Logical action name, e.g. 'ai_packing'.
 * @param {{ perMinute?: number, perHour?: number, perDay?: number }} limits
 */
async function enforceRateLimit(uid, action, limits) {
  const now   = Date.now();
  const MIN   = 60_000;
  const HOUR  = 3_600_000;
  const DAY   = 86_400_000;

  const ref = db.collection('rateLimits').doc(`${uid}_${action}`);

  const denied = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d    = snap.exists ? snap.data() : {};

    // ── Decode current window counters ───────────────────────────────────
    const mStart = d.mResetAt?.toMillis() ?? 0;
    const hStart = d.hResetAt?.toMillis() ?? 0;
    const dStart = d.dResetAt?.toMillis() ?? 0;

    const mCount = now - mStart < MIN  ? (d.mCount ?? 0) : 0;
    const hCount = now - hStart < HOUR ? (d.hCount ?? 0) : 0;
    const dCount = now - dStart < DAY  ? (d.dCount ?? 0) : 0;

    // ── Check limits ─────────────────────────────────────────────────────
    if (limits.perMinute && mCount >= limits.perMinute) {
      const wait = Math.ceil((mStart + MIN - now) / 1000);
      return `Rate limit: max ${limits.perMinute}/min. Retry in ${wait}s.`;
    }
    if (limits.perHour && hCount >= limits.perHour) {
      const wait = Math.ceil((hStart + HOUR - now) / 60_000);
      return `Hourly limit: max ${limits.perHour}/hr. Retry in ${wait} min.`;
    }
    if (limits.perDay && dCount >= limits.perDay) {
      return `Daily limit reached (max ${limits.perDay}/day). Try again tomorrow.`;
    }

    // ── Increment counters ───────────────────────────────────────────────
    const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };

    if (limits.perMinute) {
      updates.mCount = mCount + 1;
      if (now - mStart >= MIN)  updates.mResetAt = admin.firestore.Timestamp.fromMillis(now);
    }
    if (limits.perHour) {
      updates.hCount = hCount + 1;
      if (now - hStart >= HOUR) updates.hResetAt = admin.firestore.Timestamp.fromMillis(now);
    }
    if (limits.perDay) {
      updates.dCount = dCount + 1;
      if (now - dStart >= DAY)  updates.dResetAt = admin.firestore.Timestamp.fromMillis(now);
    }

    tx.set(ref, updates, { merge: true });
    return null; // allowed
  });

  if (denied) throw new HttpsError('resource-exhausted', denied);
}

/**
 * Checks Firebase App Check token. Throws if missing.
 * Enable enforcement in the Firebase console for production.
 */
function requireAppCheck(request) {
  if (!request.app) {
    throw new HttpsError(
      'failed-precondition',
      'App Check verification required. Request blocked.',
    );
  }
}

/**
 * Resolves caller UID from multiple sources.
 * v2 onCall may not populate request.auth with some Flutter SDK versions,
 * so we also try the Authorization header manually.
 * Returns null if the caller is genuinely unauthenticated.
 */
async function resolveUid(request) {
  if (request.auth?.uid) return request.auth.uid;

  const authHeader = request.rawRequest?.headers?.authorization ?? '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (token) {
    try {
      const decoded = await admin.auth().verifyIdToken(token);
      return decoded.uid;
    } catch (_) {}
  }
  return null;
}

// ─── INPUT VALIDATION HELPERS ─────────────────────────────────────────────────

function requireString(val, name, { maxLen = 500, minLen = 1 } = {}) {
  if (typeof val !== 'string') {
    throw new HttpsError('invalid-argument', `${name} must be a string.`);
  }
  const trimmed = val.trim();
  if (trimmed.length < minLen) {
    throw new HttpsError('invalid-argument', `${name} is required.`);
  }
  if (trimmed.length > maxLen) {
    throw new HttpsError('invalid-argument', `${name} exceeds ${maxLen} characters.`);
  }
  return trimmed;
}

function requireNumber(val, name, { min = 0, max = 1_000_000 } = {}) {
  if (typeof val !== 'number' || !isFinite(val)) {
    throw new HttpsError('invalid-argument', `${name} must be a number.`);
  }
  if (val < min || val > max) {
    throw new HttpsError('invalid-argument', `${name} must be between ${min} and ${max}.`);
  }
  return val;
}

function requireCoordinate(lat, lng) {
  requireNumber(lat, 'latitude',  { min: -90,  max: 90  });
  requireNumber(lng, 'longitude', { min: -180, max: 180 });
}

function optionalString(val, name, maxLen = 200) {
  if (val === undefined || val === null) return '';
  return requireString(val, name, { maxLen, minLen: 0 });
}

// ─── HELPERS ──────────────────────────────────────────────────────────────────

function dateKey(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

// ─── FUNCTION 1: generatePackingList ──────────────────────────────────────────

exports.generatePackingList = onCall(
  { region: 'asia-south1', secrets: [GEMINI_KEY], enforceAppCheck: false, invoker: 'public' },
  async (request) => {
    const uid = (await resolveUid(request)) ?? 'anon';

    // 5 calls/min · 20 calls/hr · 50 calls/day per user
    await enforceRateLimit(uid, 'packing_ai', { perMinute: 5, perHour: 20, perDay: 50 });

    const geminiKey = GEMINI_KEY.value();
    if (!geminiKey) throw new HttpsError('failed-precondition', 'Gemini key not configured.');

    // ── Validate inputs ──────────────────────────────────────────────────
    const destination  = requireString(request.data?.destination,  'destination',  { maxLen: 100 });
    const month        = requireString(request.data?.month,        'month',        { maxLen: 20  });
    const travelStyle  = optionalString(request.data?.travelStyle, 'travelStyle',  50);
    const accommodation = optionalString(request.data?.accommodation, 'accommodation', 50);
    const durationDays = requireNumber(request.data?.durationDays, 'durationDays', { min: 1, max: 365 });

    const activities     = Array.isArray(request.data?.activities)     ? request.data.activities.slice(0, 10).map(String) : [];
    const kidsAges       = Array.isArray(request.data?.kidsAges)       ? request.data.kidsAges.slice(0, 5).map(String)    : [];
    const medicalConds   = Array.isArray(request.data?.medicalConditions) ? request.data.medicalConditions.slice(0, 5).map(String) : [];
    const isSoloFemale   = Boolean(request.data?.isSoloFemale);
    const nutAllergy     = Boolean(request.data?.nutAllergy);
    const hasKids        = Boolean(request.data?.hasKids);
    const isSenior       = Boolean(request.data?.isSenior);

    const cacheKey = `packing_${destination}_${durationDays}_${month}`.toLowerCase().replace(/\s+/g, '_');
    const cached   = await db.collection('aiCache').doc(cacheKey).get();
    if (cached.exists && cached.data().expiresAt.toDate() > new Date()) {
      return cached.data().result;
    }

    const prompt = `Generate a comprehensive packing list for:
Destination: ${destination}
Duration: ${durationDays} days in ${month}
Style: ${travelStyle || 'budget'} | Stay: ${accommodation || 'hostel'}
Activities: ${activities.join(', ') || 'general sightseeing'}
${isSoloFemale ? '- Solo female traveler (include safety items)' : ''}
${nutAllergy    ? '- Has nut allergy (include allergy card, EpiPen reminder)' : ''}
${hasKids       ? `- Travelling with kids aged ${kidsAges.join(', ')}` : ''}
${isSenior      ? `- Senior traveler with: ${medicalConds.join(', ')}` : ''}

Return a JSON object where keys are category names and values are arrays of item strings.
Categories: Clothing, Toiletries, Documents, Electronics, Health & Medicine, Footwear, Accessories, Snacks & Food, Safety, Miscellaneous
Only return valid JSON, no markdown.`;

    const genAI  = new GoogleGenerativeAI(geminiKey);
    const model  = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });
    const result = await model.generateContent(prompt);
    const text   = result.response.text().trim().replace(/```json|```/g, '');
    const parsed = JSON.parse(text);

    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await db.collection('aiCache').doc(cacheKey).set({
      result:    parsed,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return parsed;
  },
);

// ─── FUNCTION 2: generateRoute ────────────────────────────────────────────────

exports.generateRoute = onCall(
  { region: 'asia-south1', secrets: [GEMINI_KEY], enforceAppCheck: false, invoker: 'public' },
  async (request) => {
    const uid = (await resolveUid(request)) ?? 'anon';

    // 1 call/min · 3 calls/hr · 5 calls/day per user
    await enforceRateLimit(uid, 'route_ai', { perMinute: 1, perHour: 3, perDay: 5 });

    const geminiKey = GEMINI_KEY.value();
    if (!geminiKey) throw new HttpsError('failed-precondition', 'Gemini key not configured.');

    // ── Validate inputs ──────────────────────────────────────────────────
    const startCity      = requireString(request.data?.startCity,  'startCity',  { maxLen: 100 });
    const endCity        = requireString(request.data?.endCity,    'endCity',    { maxLen: 100 });
    const durationDays   = requireNumber(request.data?.durationDays, 'durationDays', { min: 1, max: 90 });
    const dailyBudgetINR = requireNumber(request.data?.dailyBudgetINR, 'dailyBudgetINR', { min: 100, max: 1_000_000 });
    const interests      = Array.isArray(request.data?.interests) ? request.data.interests.slice(0, 10).map(String) : [];
    const pace           = optionalString(request.data?.pace, 'pace', 20);
    const isSenior       = Boolean(request.data?.isSenior);
    const maxWalkingKm   = request.data?.maxWalkingKm ? requireNumber(request.data.maxWalkingKm, 'maxWalkingKm', { min: 0, max: 50 }) : 10;
    const vegetarianOnly = Boolean(request.data?.vegetarianOnly);

    const cacheKey = `route_${startCity}_${endCity}_${durationDays}_${dailyBudgetINR}`.toLowerCase().replace(/\s+/g, '_');
    const cached   = await db.collection('aiCache').doc(cacheKey).get();
    if (cached.exists && cached.data().expiresAt.toDate() > new Date()) {
      return cached.data().result;
    }

    const prompt = `Plan a ${durationDays}-day backpacker trip from ${startCity} to ${endCity}.
Daily budget: ₹${dailyBudgetINR} INR
Interests: ${interests.join(', ') || 'culture, food, nature'}
Pace: ${pace || 'moderate'}
${isSenior ? `- Senior traveler, max walking: ${maxWalkingKm}km/day` : ''}
${vegetarianOnly ? '- Vegetarian food only' : ''}

Return a JSON array of day objects. Each day:
{
  "day": 1,
  "title": "Day 1: Arrival in...",
  "location": "City Name",
  "morning": "activity description",
  "afternoon": "activity description",
  "evening": "activity description",
  "accommodation": "hostel/hotel suggestion",
  "estimatedCostINR": 1500,
  "tips": "local tip"
}
Only return valid JSON array, no markdown.`;

    const genAI  = new GoogleGenerativeAI(geminiKey);
    const model  = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });
    const result = await model.generateContent(prompt);
    const text   = result.response.text().trim().replace(/```json|```/g, '');
    const parsed = JSON.parse(text);

    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await db.collection('aiCache').doc(cacheKey).set({
      result:    parsed,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return parsed;
  },
);

// ─── FUNCTION 3: getExchangeRates ─────────────────────────────────────────────

exports.getExchangeRates = onCall(
  { region: 'asia-south1', secrets: [EXCHANGE_RATE_KEY], invoker: 'public' },
  async (request) => {
    const uid = (await resolveUid(request)) ?? 'anon';

    // 10/min · 60/hr per user — mostly served from cache anyway
    await enforceRateLimit(uid, 'exchange_rates', { perMinute: 10, perHour: 60 });

    const base        = optionalString(request.data?.baseCurrency, 'baseCurrency', 10) || 'INR';
    const exchangeKey = EXCHANGE_RATE_KEY.value();
    if (!exchangeKey) throw new HttpsError('failed-precondition', 'Exchange rate key not configured.');

    const cacheRef  = db.collection('currencyCache').doc(base);
    const cached    = await cacheRef.get();
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

    if (cached.exists && cached.data().updatedAt.toDate() > oneHourAgo) {
      return { rates: cached.data().rates, base };
    }

    const response = await axios.get(
      `https://v6.exchangerate-api.com/v6/${exchangeKey}/latest/${base}`,
    );
    const rates = response.data.conversion_rates;

    await cacheRef.set({
      rates,
      base,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { rates, base };
  },
);

// ─── FUNCTION 4: sendNotification ─────────────────────────────────────────────

exports.sendNotification = onCall(
  { region: 'asia-south1', invoker: 'public' },
  async (request) => {
    const uid = await resolveUid(request);
    if (!uid) throw new HttpsError('unauthenticated', 'Sign in to send notifications.');

    // 10/min · 50/hr · 200/day — prevents notification spam campaigns
    await enforceRateLimit(uid, 'send_notification', { perMinute: 10, perHour: 50, perDay: 200 });

    const toUserId  = requireString(request.data?.toUserId, 'toUserId', { maxLen: 128 });
    const title     = requireString(request.data?.title,    'title',    { maxLen: 100 });
    const body      = requireString(request.data?.body,     'body',     { maxLen: 500 });
    const type      = optionalString(request.data?.type, 'type', 50) || 'general';
    const extraData = (typeof request.data?.extraData === 'object' && !Array.isArray(request.data.extraData))
      ? request.data.extraData : {};

    if (toUserId === uid) {
      throw new HttpsError('invalid-argument', 'Cannot send a notification to yourself.');
    }

    const userDoc = await db.collection('users').doc(toUserId).get();
    if (!userDoc.exists) throw new HttpsError('not-found', 'Recipient not found.');

    const fcmToken = userDoc.data().fcmToken;
    let messageSent = false;

    if (fcmToken) {
      await admin.messaging().send({
        token:        fcmToken,
        notification: { title, body },
        data:         { type, ...(extraData || {}) },
        android:      { priority: 'high' },
        apns:         { payload: { aps: { sound: 'default' } } },
      });
      messageSent = true;
    }

    await db.collection('notifications').add({
      to:        toUserId,
      from:      uid,
      type,
      title,
      body,
      data:      extraData,
      isRead:    false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      ),
    });

    return { success: messageSent };
  },
);

// ─── FUNCTION 5: triggerSOS ───────────────────────────────────────────────────
// No rate limit — SOS is an emergency and must never be blocked.

exports.triggerSOS = onCall(
  { region: 'asia-south1', invoker: 'public' },
  async (request) => {
    const uid = await resolveUid(request);
    if (!uid) throw new HttpsError('unauthenticated', 'Sign in to trigger SOS.');

    const latitude  = requireNumber(request.data?.latitude,  'latitude',  { min: -90,  max: 90  });
    const longitude = requireNumber(request.data?.longitude, 'longitude', { min: -180, max: 180 });
    const address   = optionalString(request.data?.address, 'address', 300);

    const userDoc  = await db.collection('users').doc(uid).get();
    const userName = userDoc.data()?.fullName || 'Unknown';

    const familySnap = await db.collection('familyLinks')
      .where('parentId', '==', uid)
      .where('isActive', '==', true)
      .get();

    const childIds = familySnap.docs.map(d => d.data().childId);
    let familyNotified = 0;

    for (const childId of childIds) {
      const childDoc = await db.collection('users').doc(childId).get();
      if (!childDoc.exists) continue;
      const fcmToken = childDoc.data().fcmToken;
      if (!fcmToken) continue;

      await admin.messaging().send({
        token:        fcmToken,
        notification: {
          title: '🆘 SOS ALERT',
          body:  `${userName} needs help at ${address || 'unknown location'}`,
        },
        data: {
          type:      'sos_alert',
          userId:    uid,
          latitude:  String(latitude),
          longitude: String(longitude),
          address:   address || '',
        },
        android: { priority: 'high' },
        apns:    { payload: { aps: { sound: 'default', badge: 1 } } },
      });

      await db.collection('notifications').add({
        to:    childId,
        from:  uid,
        type:  'sos_alert',
        title: '🆘 SOS ALERT',
        body:  `${userName} needs help at ${address || 'unknown location'}`,
        data:  { latitude, longitude, address },
        isRead:    false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      familyNotified++;
    }

    await db.collection('sosEvents').add({
      userId:         uid,
      userName,
      latitude,
      longitude,
      address:        address || '',
      familyNotified,
      timestamp:      admin.firestore.FieldValue.serverTimestamp(),
    });

    await db.collection('users').doc(uid).update({
      location: new admin.firestore.GeoPoint(latitude, longitude),
      lastSeen: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { familyNotified };
  },
);

// ─── FUNCTION 6: checkMedicineMissed (Pub/Sub every 30 min) ──────────────────

exports.checkMedicineMissed = onSchedule(
  { schedule: 'every 30 minutes', region: 'asia-south1' },
  async () => {
    const now         = new Date();
    const currentHour = now.getHours();
    const today       = dateKey(now);

    const timeSlots = [
      { name: 'Morning',   hour: 9  },
      { name: 'Afternoon', hour: 14 },
      { name: 'Evening',   hour: 18 },
      { name: 'Night',     hour: 22 },
    ];

    const overdueSlots = timeSlots
      .filter(slot => currentHour >= slot.hour + 1)
      .map(slot => slot.name);

    if (overdueSlots.length === 0) return;

    const medicinesSnap = await db.collection('medicines')
      .where('isActive', '==', true)
      .get();

    for (const doc of medicinesSnap.docs) {
      const med        = doc.data();
      const takenDates = med.takenDates || [];
      if (takenDates.includes(today)) continue;

      const missedSlots = (med.times || []).filter(t => overdueSlots.includes(t));
      if (missedSlots.length === 0) continue;

      const familySnap = await db.collection('familyLinks')
        .where('parentId', '==', med.userId)
        .where('isActive', '==', true)
        .get();

      for (const link of familySnap.docs) {
        const childDoc = await db.collection('users').doc(link.data().childId).get();
        if (!childDoc.exists) continue;
        const fcmToken = childDoc.data().fcmToken;
        if (!fcmToken) continue;

        await admin.messaging().send({
          token:        fcmToken,
          notification: {
            title: '💊 Medicine Missed',
            body:  `${med.name} (${missedSlots.join(', ')}) not taken today`,
          },
          data:    { type: 'medicine_missed', medicineId: doc.id },
          android: { priority: 'normal' },
        });
      }
    }
  },
);

// ─── FUNCTION 7: onUserCreated ────────────────────────────────────────────────

exports.onUserCreated = authUser().onCreate(async (user) => {
  const { uid, email, displayName, photoURL } = user;
  const now = Date.now();

  // ── Bot-burst detection ────────────────────────────────────────────────────
  // If >30 accounts are created globally in under 60 seconds, auto-disable
  // subsequent ones. Protects against mass account-creation bots.
  const burstRef = db.collection('rateLimits').doc('global_signup_burst');

  const isBurst = await db.runTransaction(async (tx) => {
    const snap    = await tx.get(burstRef);
    const d       = snap.exists ? snap.data() : {};
    const wStart  = d.wResetAt?.toMillis() ?? 0;
    const isActive = now - wStart < 60_000;
    const count   = isActive ? (d.count ?? 0) : 0;

    tx.set(burstRef, {
      count:    count + 1,
      wResetAt: isActive
        ? d.wResetAt
        : admin.firestore.Timestamp.fromMillis(now),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return count >= 30; // threshold: 30 accounts/minute = bot burst
  });

  if (isBurst) {
    // Silently disable the account and log for review.
    await admin.auth().updateUser(uid, { disabled: true });
    await db.collection('users').doc(uid).set({
      uid,
      email:        email || '',
      blocked:      true,
      blockReason:  'suspicious_mass_signup',
      createdAt:    admin.firestore.FieldValue.serverTimestamp(),
    });
    return;
  }

  // ── Normal profile creation ───────────────────────────────────────────────
  const trialEnd = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  await db.collection('users').doc(uid).set({
    uid,
    email:           email || '',
    fullName:        displayName || 'Traveler',
    photoUrl:        photoURL || null,
    homeCountry:     '',
    currency:        'INR',
    travelStyle:     'budget',
    travelType:      'solo',
    seniorMode:      false,
    familyMode:      false,
    isPro:           false,
    plan:            'free',
    fcmToken:        null,
    location:        null,
    isOnline:        true,
    profileComplete: false,
    totalTrips:      0,
    trialEndsAt:     admin.firestore.Timestamp.fromDate(trialEnd),
    createdAt:       admin.firestore.FieldValue.serverTimestamp(),
    lastSeen:        admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
});

// ─── FUNCTION 8: onUserDeleted ────────────────────────────────────────────────

exports.onUserDeleted = authUser().onDelete(async (user) => {
  const uid      = user.uid;
  const batch    = db.batch();
  const userRef  = db.collection('users').doc(uid);

  // Subcollections under users/{uid}/ — trips, expenses, packingLists
  const subcollections = ['trips', 'expenses', 'packingLists'];
  for (const col of subcollections) {
    const snap = await userRef.collection(col).get();
    for (const doc of snap.docs) batch.delete(doc.ref);
  }

  // Root collections that still use a userId field
  const rootCollections = ['medicines', 'familyLinks', 'notifications'];
  for (const col of rootCollections) {
    const snap = await db.collection(col).where('userId', '==', uid).get();
    for (const doc of snap.docs) batch.delete(doc.ref);
  }

  batch.delete(userRef);
  await batch.commit();

  try {
    await admin.storage().bucket().deleteFiles({ prefix: `profile_photos/${uid}/` });
  } catch (_) {}
});

// ─── FUNCTION: dailyGemNotifications (Pub/Sub daily at 6 PM IST) ─────────────
// Groups gems added in the last 24 hours by city.
// Cities with 3+ new gems get ONE broadcast notification — no per-gem spam.

exports.dailyGemNotifications = onSchedule(
  { schedule: '0 18 * * *', timeZone: 'Asia/Kolkata', region: 'asia-south1' },
  async () => {
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const gemsSnap = await db.collection('hiddenGems')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(yesterday))
      .get();

    if (gemsSnap.empty) return;

    // Group by city
    const byCity = {};
    gemsSnap.docs.forEach(doc => {
      const data = doc.data();
      const city = (data.city || '').trim();
      if (!city) return;
      if (!byCity[city]) {
        byCity[city] = { gemIds: [], latitude: data.latitude, longitude: data.longitude };
      }
      byCity[city].gemIds.push(doc.id);
    });

    // Collect all FCM tokens once (reused across cities)
    const usersSnap = await db.collection('users')
      .where('fcmToken', '!=', null)
      .get();
    const allTokens = usersSnap.docs
      .map(d => d.data().fcmToken)
      .filter(t => typeof t === 'string' && t.length > 0);

    for (const [city, { gemIds, latitude, longitude }] of Object.entries(byCity)) {
      if (gemIds.length < 3) continue;

      const count = gemIds.length;
      const title = `${count} new hidden gems in ${city}!`;
      const body  = 'Tap to explore what travellers just discovered today';

      // Write one Firestore broadcast — client 50 km filter shows it to nearby users
      await db.collection('notifications').add({
        userId:      'broadcast',
        title,
        body,
        type:        'gemAdded',
        actionRoute: '/gems',
        metadata:    { city, latitude, longitude, gemIds, count },
        isRead:      false,
        createdAt:   admin.firestore.FieldValue.serverTimestamp(),
      });

      // FCM push — city name in title lets irrelevant users self-filter
      if (allTokens.length === 0) continue;
      for (let i = 0; i < allTokens.length; i += 500) {
        const chunk = allTokens.slice(i, i + 500);
        await admin.messaging().sendEachForMulticast({
          tokens:       chunk,
          notification: { title, body },
          data: {
            type:   'gemBatch',
            city,
            gemIds: JSON.stringify(gemIds),
            route:  '/gems',
          },
          android: {
            notification: { channelId: 'packmate_default' },
            priority: 'normal',
          },
          apns: { payload: { aps: { sound: 'default' } } },
        });
      }
    }
  },
);

// ─── FUNCTION: getNearbyPlaces ────────────────────────────────────────────────

exports.getNearbyPlaces = onCall(
  { region: 'asia-south1', secrets: [PLACES_KEY], invoker: 'public' },
  async (request) => {
    const uid = await resolveUid(request);
    if (!uid) throw new HttpsError('unauthenticated', 'Sign in to search nearby places.');

    // 15/min · 100/hr · 500/day — protects the Places API billing
    await enforceRateLimit(uid, 'places_api', { perMinute: 15, perHour: 100, perDay: 500 });

    const key = PLACES_KEY.value();
    if (!key) throw new HttpsError('failed-precondition', 'Places key not configured.');

    const latitude  = requireNumber(request.data?.latitude,  'latitude',  { min: -90,  max: 90  });
    const longitude = requireNumber(request.data?.longitude, 'longitude', { min: -180, max: 180 });
    const type      = requireString(request.data?.type, 'type', { maxLen: 50 });
    const radius    = request.data?.radius
      ? requireNumber(request.data.radius, 'radius', { min: 100, max: 50_000 })
      : 20_000;
    const keyword   = optionalString(request.data?.keyword, 'keyword', 100);

    const params = { location: `${latitude},${longitude}`, radius, type, key };
    if (keyword) params.keyword = keyword;

    try {
      const res = await axios.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        { params },
      );
      const { status, results = [], error_message } = res.data;
      if (status !== 'OK' && status !== 'ZERO_RESULTS') {
        throw new HttpsError('failed-precondition', `Places API: ${status} — ${error_message || ''}`);
      }
      return { places: results };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      throw new HttpsError('internal', err.message);
    }
  },
);
