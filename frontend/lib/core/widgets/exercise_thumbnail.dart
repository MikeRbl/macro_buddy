import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../../theme/app_theme.dart';

class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({super.key, required this.url, this.size = 48});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final Widget placeholder = Container(
      width: size,
      height: size,
      color: c.input,
      child: Icon(
        Icons.fitness_center,
        size: size * 0.5,
        color: c.textSecondary,
      ),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        ApiConfig.baseUrl + url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}
