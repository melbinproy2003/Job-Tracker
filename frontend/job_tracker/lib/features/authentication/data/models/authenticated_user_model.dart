import '../../domain/entities/authenticated_user.dart';

class AuthenticatedUserModel {
  const AuthenticatedUserModel({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;

  factory AuthenticatedUserModel.fromJson(Map<String, dynamic> json) {
    return AuthenticatedUserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      emailVerified: json['email_verified'] as bool? ?? false,
    );
  }

  AuthenticatedUser toEntity() {
    return AuthenticatedUser(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      emailVerified: emailVerified,
    );
  }
}
