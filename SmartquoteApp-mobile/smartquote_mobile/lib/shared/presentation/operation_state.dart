import 'package:flutter/material.dart';

abstract class OperationState<T extends StatefulWidget> extends State<T> {
  bool busy = false;
  Object? error;
  Future<R?> perform<R>(Future<R> Function() action) async {
    if (busy || !mounted) return null;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      return await action();
    } catch (e) {
      if (mounted) setState(() => error = e);
      return null;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
