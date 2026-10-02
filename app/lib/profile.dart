import 'package:supabase_flutter/supabase_flutter.dart';

// Name and profile picture live in the Supabase user's metadata.

String? fullName(User? user) {
  final name = (user?.userMetadata?['full_name'] as String?)?.trim();
  return name == null || name.isEmpty ? null : name;
}

String? firstName(User? user) => fullName(user)?.split(RegExp(r'\s+')).first;

String? avatarUrl(User? user) => user?.userMetadata?['avatar_url'] as String?;

/// "JP" for Julien Polycarpe, "J" for julien@example.com.
String initials(User? user) {
  final name = fullName(user);
  if (name != null) {
    final parts = name.split(RegExp(r'\s+'));
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }
  final email = user?.email ?? '';
  return email.isEmpty ? '?' : email[0].toUpperCase();
}
