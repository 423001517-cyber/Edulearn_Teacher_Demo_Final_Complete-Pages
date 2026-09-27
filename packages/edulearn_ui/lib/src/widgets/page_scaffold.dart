import 'package:flutter/material.dart';

/// Scrollable page body with the standard padding, max width and spacing.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.header, required this.children, this.gap = 20});

  final Widget header;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final pad = c.maxWidth < 600 ? 16.0 : 28.0;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                for (final child in children) ...[SizedBox(height: gap), child],
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Two columns on wide screens (3:2 like the mockups), one column otherwise.
class TwoColumn extends StatelessWidget {
  const TwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.narrowOrder,
    this.breakpoint = 1000,
    this.leftFlex = 13,
    this.rightFlex = 10,
    this.gap = 20,
  });

  final List<Widget> left;
  final List<Widget> right;

  /// Order for the single-column layout; defaults to left then right.
  final List<Widget>? narrowOrder;
  final double breakpoint;
  final int leftFlex;
  final int rightFlex;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < breakpoint) {
        return _column(narrowOrder ?? [...left, ...right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex, child: _column(left)),
          SizedBox(width: gap),
          Expanded(flex: rightFlex, child: _column(right)),
        ],
      );
    });
  }

  Widget _column(List<Widget> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            items[i],
          ],
        ],
      );
}
