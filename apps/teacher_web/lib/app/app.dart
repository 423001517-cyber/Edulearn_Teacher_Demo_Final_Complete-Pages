import 'package:edulearn_ui/edulearn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation.dart';
import 'router.dart';

class EduLearnApp extends ConsumerWidget {
  const EduLearnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'EduLearn Teacher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scaffoldMessengerKey: rootMessengerKey,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
