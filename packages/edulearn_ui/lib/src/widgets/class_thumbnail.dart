import 'package:edulearn_core/edulearn_core.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Class cover image. Until a teacher uploads one (Class Settings), shows a
/// sky-to-hills illustration tinted with the class color.
class ClassThumbnail extends StatelessWidget {
  const ClassThumbnail({
    super.key,
    required this.classRoom,
    this.width,
    this.height = 72,
    this.radius = 10,
  });

  final ClassRoom classRoom;
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = classRoom.coverImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? _Fallback(color: AppColors.forClass(classRoom.colorIndex))
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    _Fallback(color: AppColors.forClass(classRoom.colorIndex)),
              ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBFE6F7), Color(0xFFE9F6EC)],
        ),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final h = c.maxHeight;
        return Stack(
          children: [
            Positioned(
              left: -h * 0.4,
              right: c.maxWidth * 0.35,
              bottom: -h * 0.35,
              height: h * 0.75,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.all(Radius.elliptical(c.maxWidth, h)),
                ),
              ),
            ),
            Positioned(
              left: c.maxWidth * 0.3,
              right: -h * 0.4,
              bottom: -h * 0.4,
              height: h * 0.8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.all(Radius.elliptical(c.maxWidth, h)),
                ),
              ),
            ),
            Center(
              child: Icon(Icons.account_balance_rounded,
                  size: h * 0.42, color: Colors.white.withValues(alpha: 0.95)),
            ),
          ],
        );
      }),
    );
  }
}
