// lib/models/user_profile.dart
//
// Modelo tipado para los datos de perfil de usuario.
// Sustituye Map<String, dynamic> en pantallas como ProfileScreen,
// ActivityScreen, FriendPicker y CopilotPicker.

import 'package:flutter/foundation.dart';

/// Perfil público de un usuario de Corpus.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.xp,
    this.level,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final int? xp;
  final int? level;

  /// Nombre visible: preferimos `display_name` si existe, si no `username`.
  String get effectiveName => displayName?.isNotEmpty == true ? displayName! : username;

  /// Construye un [UserProfile] desde una fila de Supabase.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String? ?? '',
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      bio: map['bio'] as String?,
      xp: (map['xp'] as num?)?.toInt(),
      level: (map['level'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'username': username,
    if (displayName != null) 'display_name': displayName,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    if (bio != null) 'bio': bio,
    if (xp != null) 'xp': xp,
    if (level != null) 'level': level,
  };

  UserProfile copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    int? xp,
    int? level,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      xp: xp ?? this.xp,
      level: level ?? this.level,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserProfile(id: $id, username: $username)';
}
