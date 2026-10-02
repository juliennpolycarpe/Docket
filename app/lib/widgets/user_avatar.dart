import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile.dart';

/// Profile picture, or initials if there isn't one (or it fails to load).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 16});

  final User? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = avatarUrl(user);
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: url != null ? NetworkImage(url) : null,
      child: Text(
        initials(user),
        style: TextStyle(fontSize: radius * 0.8, color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
      ),
    );
  }
}
