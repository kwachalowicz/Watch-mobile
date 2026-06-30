import 'package:watch_me/objectbox.g.dart';

import '../models/app_user.dart';
import '../models/auth_session.dart';
import 'objectbox_service.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Logowanie/rejestracja "na razie lokalnie", dopóki nie ma backendu.
///
/// UWAGA: hasło jest hashowane bardzo prostym sposobem tylko po to, żeby
/// nie trzymać go w bazie jawnym tekstem podczas developmentu. To NIE jest
/// bezpieczne rozwiązanie produkcyjne - gdy powstanie prawdziwe API,
/// hashowaniem hasła (bcrypt/argon2) zajmie się serwer, a ta klasa zostanie
/// podmieniona na wywołania HTTP (patrz INTEGRATION.md).
class AuthRepository {
  AuthRepository(this._service);
  final ObjectBoxService _service;

  String _devHash(String password) =>
      '${password.split('').reversed.join()}:${password.length}';

  /// Sesja jest jednowierszowym "singletonem" w boxie - zamiast zgadywać
  /// jego ID (ObjectBox nie pozwala z góry narzucić ID, którego jeszcze
  /// nie było), po prostu bierzemy pierwszy (i jedyny) wiersz, jaki tam jest.
  AuthSession? _readSession() {
    final all = _service.authSessionBox.getAll();
    return all.isEmpty ? null : all.first;
  }

  /// Zwraca aktualnie zalogowanego użytkownika albo null.
  AppUser? currentUser() {
    final userId = _readSession()?.userId;
    if (userId == null) return null;
    return _service.userBox.get(userId);
  }

  AppUser register({
    required String email,
    required String password,
    String? name,
  }) {
    final key = email.toLowerCase().trim();
    if (key.isEmpty || !key.contains('@')) {
      throw AuthException('Podaj poprawny adres e-mail.');
    }
    if (password.length < 6) {
      throw AuthException('Hasło musi mieć co najmniej 6 znaków.');
    }

    final existing = _service.userBox
        .query(AppUser_.email.equals(key))
        .build()
        .findFirst();
    if (existing != null) {
      throw AuthException('Użytkownik o tym adresie e-mail już istnieje.');
    }

    final user = AppUser(
      email: key,
      passwordHash: _devHash(password),
      name: name,
    );
    final id = _service.userBox.put(user);
    user.id = id;
    _setSession(id);
    return user;
  }

  AppUser login({required String email, required String password}) {
    final key = email.toLowerCase().trim();
    final user = _service.userBox
        .query(AppUser_.email.equals(key))
        .build()
        .findFirst();

    if (user == null || user.passwordHash != _devHash(password)) {
      throw AuthException('Nieprawidłowy e-mail lub hasło.');
    }

    _setSession(user.id);
    return user;
  }

  void logout() {
    final existing = _readSession();
    _service.authSessionBox.put(
      AuthSession(id: existing?.id ?? 0, userId: null),
    );
  }

  void _setSession(int userId) {
    final existing = _readSession();
    _service.authSessionBox.put(
      AuthSession(id: existing?.id ?? 0, userId: userId),
    );
  }
}
