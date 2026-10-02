import 'package:supabase_flutter/supabase_flutter.dart';

class UserSession {
  UserSession._();

  static String? phoneNumber;
  static String? fullName;
  static String? email;
  static String? userId;

  static bool get isLoggedIn => userId != null;

  static void restore(User? user, {Map<String, dynamic>? profile}) {
    if (user == null) {
      clear();
      return;
    }
    userId = user.id;
    email = user.email;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    fullName = (profile?['full_name'] ?? metadata['full_name']) as String?;
    phoneNumber = profile != null
        ? profile['phone'] as String?
        : (metadata['phone'] ?? user.phone) as String?;
  }

  static void clear() {
    phoneNumber = null;
    fullName = null;
    email = null;
    userId = null;
  }
}
