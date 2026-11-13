import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/mb_icon.dart';
import '../../theme/app_theme.dart';
import 'onboarding_content.dart';
import 'onboarding_controller.dart';

// ─────────────────────────────────────────────────────────────────────────
// Bienvenida (pantalla completa)
// ─────────────────────────────────────────────────────────────────────────

/// Bienvenida para usuarios nuevos. `AuthGate` la muestra antes de la app la
/// primera vez; desde Perfil › Tutoriales se abre otra vez como ruta.
class WelcomeOnboardingScreen extends StatefulWidget {
  const WelcomeOnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<WelcomeOnboardingScreen> createState() =>
      _WelcomeOnboardingScreenState();
}

class _WelcomeOnboardingScreenState extends State<WelcomeOnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == welcomeSteps.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final accent = welcomeSteps[_page].accent;
    return Scaffold(
      backgroundColor: c.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppColors.screenPadding),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: _isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: _isLast ? null : widget.onDone,
                    child: Text(
                      'Omitir',
                      style: TextStyle(color: c.textSecondary),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: welcomeSteps.length,
                  onPageChanged: (p) => setState(() => _page = p),
                  itemBuilder: (_, i) =>
                      _StepPage(step: welcomeSteps[i], large: true),
                ),
              ),
              _Dots(count: welcomeSteps.length, index: _page, color: accent),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _next,
                child: Text(
                  _isLast ? 'Empezar' : 'Siguiente',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre la bienvenida sobre la app (desde Perfil) y reinicia los recorridos
/// de cada sección para que se vuelvan a mostrar al visitarlas.
Future<void> replayAllTutorials(BuildContext context, WidgetRef ref) async {
  await ref.read(onboardingProvider.notifier).resetSections();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) =>
          WelcomeOnboardingScreen(onDone: () => Navigator.of(ctx).pop()),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Recorrido de una sección (hoja inferior con páginas)
// ─────────────────────────────────────────────────────────────────────────

/// Muestra el recorrido de [section] y lo marca como visto al cerrarlo.
Future<void> showSectionTour(
  BuildContext context,
  WidgetRef ref,
  AppSection section,
) async {
  final guide = sectionGuides[section]!;
  // Se toma antes de abrir la hoja: al cerrarla el widget que llamó puede
  // ya no estar montado.
  final notifier = ref.read(onboardingProvider.notifier);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ThemeColors.of(context).card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SectionTourSheet(guide: guide),
  );
  await notifier.markSectionSeen(section);
}

class _SectionTourSheet extends StatefulWidget {
  const _SectionTourSheet({required this.guide});

  final SectionGuide guide;

  @override
  State<_SectionTourSheet> createState() => _SectionTourSheetState();
}

class _SectionTourSheetState extends State<_SectionTourSheet> {
  final _controller = PageController();
  int _page = 0;

  List<OnboardingStep> get _steps => widget.guide.steps;
  bool get _isLast => _page == _steps.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    final guide = widget.guide;
    final height = MediaQuery.sizeOf(context).height;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 12),
            Row(
              children: [
                MbIcon(guide.asset, size: 20, color: guide.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Así funciona ${guide.name}',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_page + 1}/${_steps.length}',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                  ).merge(AppTypography.numeric),
                ),
              ],
            ),
            SizedBox(
              height: (height * 0.42).clamp(280.0, 380.0),
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (_, i) => _StepPage(step: _steps[i]),
              ),
            ),
            _Dots(
              count: _steps.length,
              index: _page,
              color: _steps[_page].accent,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (!_isLast)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Omitir',
                      style: TextStyle(color: c.textSecondary),
                    ),
                  ),
                if (!_isLast) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _next,
                    child: Text(
                      _isLast ? 'Entendido' : 'Siguiente',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Botón "?" y hoja de ayuda
// ─────────────────────────────────────────────────────────────────────────

/// Botón redondo "?" para el encabezado de cada sección. Abre la ayuda de
/// la sección, desde donde se puede repetir su recorrido.
class SectionHelpButton extends ConsumerWidget {
  const SectionHelpButton({super.key, required this.section, this.size = 40});

  final AppSection section;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ThemeColors.of(context);
    return Tooltip(
      message: 'Ayuda de ${sectionGuides[section]!.name}',
      child: Material(
        color: c.input,
        shape: CircleBorder(side: BorderSide(color: c.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showSectionHelp(context, ref, section),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.question_mark_rounded,
              size: size * 0.5,
              color: c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja con la explicación de la sección y el botón para repetir su
/// recorrido.
Future<void> showSectionHelp(
  BuildContext context,
  WidgetRef ref,
  AppSection section,
) async {
  final guide = sectionGuides[section]!;
  final replay = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ThemeColors.of(context).card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SectionHelpSheet(guide: guide),
  );
  if (replay == true && context.mounted) {
    await showSectionTour(context, ref, section);
  }
}

class _SectionHelpSheet extends StatelessWidget {
  const _SectionHelpSheet({required this.guide});

  final SectionGuide guide;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scroll) => SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            const _SheetHandle(),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: guide.accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: MbIcon(
                          guide.asset,
                          size: 22,
                          color: guide.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ayuda · ${guide.name}',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              guide.summary,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: Icon(Icons.close, color: c.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final step in guide.steps) ...[
                    GlassCard(
                      color: c.input,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StepIcon(step: step, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.title,
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  step.body,
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.replay),
                label: const Text(
                  'Repetir recorrido de la sección',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Piezas compartidas
// ─────────────────────────────────────────────────────────────────────────

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step, this.large = false});

  final OnboardingStep step;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepIcon(step: step, size: large ? 120 : 84),
          SizedBox(height: large ? 36 : 24),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: large ? 26 : 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: large ? 16 : 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Círculo con el acento al 14 % y glow suave, como las tarjetas destacadas.
class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.step, required this.size});

  final OnboardingStep step;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = size * 0.46;
    // El logo va a color completo; los demás assets se tiñen con el acento.
    final Widget child;
    if (step.asset == MbAssets.logo) {
      child = Image.asset(step.asset!, width: size * 0.62, height: size * 0.62);
    } else if (step.asset != null) {
      child = MbIcon(step.asset!, size: glyph, color: step.accent);
    } else {
      child = Icon(step.icon, size: glyph, color: step.accent);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: step.accent.withValues(alpha: 0.14),
        border: Border.all(color: step.accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: step.accent.withValues(alpha: 0.18),
            blurRadius: size * 0.3,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.color});

  final int count;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = ThemeColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? color : c.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: ThemeColors.of(context).border,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
