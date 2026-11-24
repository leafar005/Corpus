// lib/models/user_profile.dart
//
// Modelo tipado para los datos de perfil de usuario.
// Sustituye Map<String, dynamic> en pantallas como ProfileScreen,
// ActivityScreen, FriendPicker y CopilotPicker.

import 'package:flutter/foundation.dart';

const Object _sentinel = Object();

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
  String get effectiveName =>
      displayName?.isNotEmpty == true ? displayName! : username;

  /// Construye un [UserProfile] desde una fila de Supabase.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      displayName: map['display_name']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      bio: map['bio']?.toString(),
      xp:
          (map['xp'] as num?)?.toInt() ??
          int.tryParse(map['xp']?.toString() ?? ''),
      level:
          (map['level'] as num?)?.toInt() ??
          int.tryParse(map['level']?.toString() ?? ''),
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
    Object? displayName = _sentinel,
    Object? avatarUrl = _sentinel,
    Object? bio = _sentinel,
    Object? xp = _sentinel,
    Object? level = _sentinel,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      displayName: identical(displayName, _sentinel)
          ? this.displayName
          : displayName as String?,
      avatarUrl: identical(avatarUrl, _sentinel)
          ? this.avatarUrl
          : avatarUrl as String?,
      bio: identical(bio, _sentinel) ? this.bio : bio as String?,
      xp: identical(xp, _sentinel) ? this.xp : xp as int?,
      level: identical(level, _sentinel) ? this.level : level as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserProfile(id: $id, username: $username)';
}
