import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/sound_util.dart';
import 'community_provider.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  void _showCheerSnackBar(BuildContext context, CheerEvent cheer) {
    SoundUtil.playBeep();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Text(cheer.emoji),
            const SizedBox(width: 8),
            Expanded(child: Text('${cheer.fromUsername} te está animando!')),
          ],
        ),
      ),
    );
  }

  void _showCheerOptions(
    BuildContext context,
    WidgetRef ref,
    ActiveUser user,
  ) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🔥', style: TextStyle(fontSize: 20)),
              title: const Text('Fuego'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(communityProvider.notifier).cheer(
                      user.userId,
                      reactionType: 'fire',
                    );
              },
            ),
            ListTile(
              leading: const Text('💪', style: TextStyle(fontSize: 20)),
              title: const Text('Fuerza'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(communityProvider.notifier).cheer(
                      user.userId,
                      reactionType: 'bicep',
                    );
              },
            ),
            ListTile(
              leading: const Text('🏋️', style: TextStyle(fontSize: 20)),
              title: const Text('Pesas'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(communityProvider.notifier).cheer(
                      user.userId,
                      reactionType: 'dumbbell',
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final community = ref.watch(communityProvider);

    ref.listen(communityProvider.select((s) => s.lastCheer), (prev, next) {
      if (next != null && next != prev) {
        _showCheerSnackBar(context, next);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comunidad',
                style: textTheme.headlineSmall?.copyWith(
                  color: cs.onSurface,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Entrenando ahora',
                style: textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (community.activeUsers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'El gimnasio está vacío en este momento',
                      style: textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 96,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: community.activeUsers.length,
                    itemBuilder: (context, index) {
                      final user = community.activeUsers[index];
                      final isTraining = user.status == 'training';
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: InkWell(
                          onTap: isTraining
                              ? () => _showCheerOptions(context, ref, user)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: isTraining
                                      ? Border.all(
                                          color: Colors.greenAccent,
                                          width: 3,
                                        )
                                      : Border.all(
                                          color: Colors.grey.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 1,
                                        ),
                                ),
                                child: CircleAvatar(
                                  radius: 27,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  child: Text(
                                    user.username.isNotEmpty
                                        ? user.username
                                              .substring(0, 1)
                                              .toUpperCase()
                                        : '?',
                                    style: textTheme.titleLarge?.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                user.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: isTraining
                                      ? cs.onSurface
                                      : cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 28),
              Text(
                'Actividad global',
                style: textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (community.feed.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Sin actividad todavía. Completa un entrenamiento para aparecer aquí.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                for (final item in community.feed)
                  _FeedCard(
                    item: item,
                    relativeTime: _relativeTime(item.at),
                    onReact: (type) => ref
                        .read(communityProvider.notifier)
                        .cheer(
                          item.userId,
                          workoutId: item.workoutId,
                          reactionType: type,
                        ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.item,
    required this.relativeTime,
    required this.onReact,
  });

  final FeedItem item;
  final String relativeTime;
  final void Function(String reactionType) onReact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: cs.surfaceContainerHighest,
                child: Text(
                  item.username.isNotEmpty
                      ? item.username.substring(0, 1).toUpperCase()
                      : '?',
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                relativeTime,
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Completó el entrenamiento ${item.workoutName}',
            style: textTheme.bodyMedium?.copyWith(color: cs.onSurface),
          ),
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.note!,
              style: textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ReactionButton(
                emoji: '🔥',
                count: item.reactions['fire'] ?? 0,
                onTap: () => onReact('fire'),
              ),
              const SizedBox(width: 8),
              _ReactionButton(
                emoji: '💪',
                count: item.reactions['bicep'] ?? 0,
                onTap: () => onReact('bicep'),
              ),
              const SizedBox(width: 8),
              _ReactionButton(
                emoji: '🏋️',
                count: item.reactions['dumbbell'] ?? 0,
                onTap: () => onReact('dumbbell'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.emoji,
    required this.count,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(color: cs.onSurface, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
