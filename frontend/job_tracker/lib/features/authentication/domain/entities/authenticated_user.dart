import 'package:equatable/equatable.dart';

/// Application-level authenticated user. [id] is the Firebase UID.
class AuthenticatedUser extends Equatable {
  const AuthenticatedUser({
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

  @override
  List<Object?> get props => [id, email, displayName, photoUrl, emailVerified];
}
