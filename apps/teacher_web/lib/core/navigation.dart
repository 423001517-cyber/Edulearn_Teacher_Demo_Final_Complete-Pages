import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// A context that outlives popovers and dialogs. Use it to open a follow-up
/// dialog right after closing the current one.
BuildContext get rootContext => rootNavigatorKey.currentContext!;

void showToast(String message, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = rootMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, textColor: const Color(0xFF9BE3B8), onPressed: onAction ?? () {}),
    ));
}

/// Navigate from anywhere (including right after closing a popover).
void goTo(String location) => GoRouter.of(rootContext).go(location);
