import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../shared/domain/api_contract.dart';
import '../domain/session.dart';

class SessionController extends ChangeNotifier {
  SessionController(this.repository, this.client) {
    client.renewSession = renew;
  }
  final IdentityRepository repository;
  final SessionTransport client;
  Session? session;
  Timer? _timer;
  Future<bool>? _renewal;
  bool _disposed = false;
  int _generation = 0;
  void _accept(Session next) {
    session = next;
    client.accessToken = next.token;
    _timer?.cancel();
    _timer = Timer(
      Duration(seconds: (next.expiresIn - 30).clamp(5, 86400)),
      renew,
    );
    if (!_disposed) notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final generation = ++_generation;
    final next = await repository.login(email, password);
    if (!_disposed && generation == _generation) _accept(next);
  }

  Future<bool> renew() {
    if (session == null || _disposed) return Future.value(false);
    return _renewal ??= _renew().whenComplete(() => _renewal = null);
  }

  Future<bool> _renew() async {
    final generation = _generation;
    try {
      final next = await repository.refresh();
      if (_disposed || generation != _generation) return false;
      _accept(next);
      return true;
    } catch (_) {
      if (!_disposed && generation == _generation) await clear();
      return false;
    }
  }

  Future<void> clear() async {
    ++_generation;
    _timer?.cancel();
    session = null;
    await client.clearSession();
    if (!_disposed) notifyListeners();
  }

  Future<void> logout() async {
    try {
      await repository.logout();
    } finally {
      await clear();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    client.renewSession = null;
    super.dispose();
  }
}
