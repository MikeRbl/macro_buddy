import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/workout_session.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_controller.dart';

class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  ConsumerState<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  late Future<List<WorkoutSession>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<WorkoutSession>> _load() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) {
      throw const ApiException('Sesión expirada. Inicia sesión de nuevo.');
    }
    final items = await ref
        .read(apiClientProvider)
        .fetchUserWorkouts(token: token);
    return items
        .map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de entrenos')),
      body: FutureBuilder<List<WorkoutSession>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No se pudo cargar el historial.',
                    style: TextStyle(color: c.textSecondary, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: _retry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final sessions = snapshot.data ?? const <WorkoutSession>[];
          if (sessions.isEmpty) {
            return Center(
              child: Text(
                'Sin entrenamientos registrados todavía.',
                style: TextStyle(color: c.textSecondary, fontSize: 14),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) =>
                _SessionCard(session: sessions[index]),
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final date = session.date;
    final title = 'Entreno · ${date.day}/${date.month}/${date.year}';
    final duration = session.duration;
    final durationLabel = duration != null
        ? ' · ${'${duration ~/ 3600}h ${(duration % 3600) ~/ 60}m'}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                durationLabel,
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
            ],
          ),
          if (session.note != null && session.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Nota: ${session.note}',
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ],
          if (session.sets.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final set in session.sets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        set.exerciseName ?? 'Ejercicio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textPrimary, fontSize: 14),
                      ),
                    ),
                    Text(
                      _setLabel(set),
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _setLabel(WorkoutSessionSet set) {
    final parts = <String>[];
    if (set.weight != null) parts.add('${set.weight!.round()} kg');
    if (set.reps != null) parts.add('${set.reps} reps');
    if (set.isWarmup) parts.add('W');
    if (set.rir != null) parts.add('RIR ${set.rir}');
    return parts.join(' · ');
  }
}
