import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/auth_repository.dart';
import '../../data/models/app_user.dart';
import '../../data/local/objectbox_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ObjectBoxService.instance);
});

sealed class AuthState {
  const AuthState();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AppUser user;
}

/// Stan auth dla całej apki. go_router (w app.dart) obserwuje to przez
/// redirect i sam przerzuca użytkownika na /login albo /home.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final user = ref.read(authRepositoryProvider).currentUser();
    return user != null ? AuthAuthenticated(user) : const AuthUnauthenticated();
  }

  /// Rzuca [AuthException] przy błędnych danych - łap to w UI.
  Future<void> login(String email, String password) async {
    final user = ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    state = AuthAuthenticated(user);
  }

  /// Rzuca [AuthException] przy błędnych danych - łap to w UI.
  Future<void> register(String email, String password, {String? name}) async {
    final user = ref
        .read(authRepositoryProvider)
        .register(email: email, password: password, name: name);
    state = AuthAuthenticated(user);
  }

  void logout() {
    ref.read(authRepositoryProvider).logout();
    state = const AuthUnauthenticated();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
