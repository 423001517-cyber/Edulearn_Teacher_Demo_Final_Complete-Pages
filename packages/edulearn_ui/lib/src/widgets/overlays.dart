import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Opens a card anchored to the widget that owns [context] (the popovers in
/// the design). Falls back to a bottom sheet on phones.
Future<T?> showAnchoredPopover<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 340,
}) {
  final box = context.findRenderObject()! as RenderBox;
  final overlay = Navigator.of(context, rootNavigator: true).overlay!.context.findRenderObject()!
      as RenderBox;
  final anchor = Rect.fromPoints(
    box.localToGlobal(Offset.zero, ancestor: overlay),
    box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
  );

  if (overlay.size.width < 600) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(child: builder(ctx)),
      ),
    );
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.04),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (ctx, animation, secondary) => CustomSingleChildLayout(
      delegate: _PopoverLayout(anchor: anchor, width: width),
      child: Material(
        color: Colors.white,
        elevation: 14,
        shadowColor: const Color(0x33000000),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(child: builder(ctx)),
      ),
    ),
    transitionBuilder: (ctx, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout({required this.anchor, required this.width});

  final Rect anchor;
  final double width;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
        minWidth: math.min(width, constraints.maxWidth - 24),
        maxWidth: math.min(width, constraints.maxWidth - 24),
        maxHeight: constraints.maxHeight - 24,
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final maxLeft = math.max(12.0, size.width - child.width - 12);
    final left = (anchor.right - child.width).clamp(12.0, maxLeft).toDouble();
    var top = anchor.bottom + 6;
    if (top + child.height > size.height - 12) {
      final above = anchor.top - child.height - 6;
      top = above >= 12 ? above : math.max(12.0, size.height - child.height - 12);
    }
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_PopoverLayout old) => old.anchor != anchor || old.width != width;
}

/// Right-hand drawer (Student Support, Quick View, report details).
/// Full screen on phones.
Future<T?> showSidePanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 420,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.22),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, animation, secondary) {
      final screen = MediaQuery.sizeOf(ctx);
      final full = screen.width < 600;
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: full ? EdgeInsets.zero : const EdgeInsets.all(12),
          child: Material(
            color: Colors.white,
            elevation: 16,
            borderRadius: full ? null : BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: full ? screen.width : width,
              height: double.infinity,
              child: SafeArea(child: builder(ctx)),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondary, child) {
      if (MediaQuery.disableAnimationsOf(ctx)) return child;
      return SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

/// Title row with a close button for popovers, panels and dialogs.
class PanelHeader extends StatelessWidget {
  const PanelHeader({super.key, required this.title, this.leading, this.subtitle, this.trailing});

  final String title;
  final Widget? leading;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.dialogTitle.copyWith(fontSize: 18)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppText.meta.copyWith(fontSize: 13.5)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded, color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

/// White rounded dialog shell with a max width.
class AppDialog extends StatelessWidget {
  const AppDialog({super.key, required this.child, this.maxWidth = 520});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.dialogTitle),
          const SizedBox(height: 8),
          Text(message, style: AppText.meta.copyWith(fontSize: 14, height: 1.45)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: destructive
                      ? FilledButton.styleFrom(backgroundColor: AppColors.red)
                      : null,
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}
