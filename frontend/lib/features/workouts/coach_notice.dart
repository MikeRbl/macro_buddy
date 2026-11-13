import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/workout_plan.dart';
import '../../theme/app_theme.dart';
import 'workouts_provider.dart';

/// Aviso de que el entrenador creó o cambió un programa, con el detalle.
class CoachNoticeCard extends StatelessWidget {
  const CoachNoticeCard({
    super.key,
    required this.notices,
    required this.onDismiss,
  });

  final List<AppNotification> notices;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.tertiaryPurple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(
          color: AppColors.tertiaryPurple.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final n in notices.take(3)) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                    color: AppColors.tertiaryPurple,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.body == null ? n.title : '${n.title} ${n.body}',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final d in n.details.take(4))
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '• $d',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      if (n.details.length > 4)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'y ${n.details.length - 4} cambios más',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDismiss,
              child: const Text(
                'Entendido',
                style: TextStyle(
                  color: AppColors.tertiaryPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Lista de avisos sin leer; se abre desde la campana del Dashboard.
void showNoticesSheet(BuildContext context) {
  final c = ThemeColors.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final notices = ref.watch(notificationsProvider);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Avisos',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (notices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'No tienes avisos nuevos. Aquí verás cuando tu '
                      'entrenador cree o cambie tu programa.',
                      style: TextStyle(color: c.textSecondary, fontSize: 14),
                    ),
                  )
                else
                  CoachNoticeCard(
                    notices: notices,
                    onDismiss: () {
                      ref.read(notificationsProvider.notifier).markAllRead();
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
