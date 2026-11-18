import 'user.dart';

/// Hasil login/register: token JWT + user.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final User user;
}
