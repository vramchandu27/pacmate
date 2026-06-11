import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/auth_service.dart';
import '../models/user_model.dart';

// Streams the Firestore UserModel for the currently signed-in user.
// Delegates to authServiceProvider — single source of truth.
final currentUserProvider = StreamProvider<UserModel?>(
  (ref) => ref.watch(authServiceProvider).watchCurrentUser(),
);
