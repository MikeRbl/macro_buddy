import 'package:flutter/material.dart';

import '../../core/widgets/mb_icon.dart';
import '../../theme/app_theme.dart';

/// Las cuatro secciones de la barra de navegación. Cada una tiene su propio
/// recorrido (se muestra la primera vez) y su botón "?" de ayuda.
enum AppSection { dashboard, nutrition, workout, profile }

/// Un paso de un recorrido: ícono (Material o asset del proyecto), color de
/// acento, título corto y explicación en lenguaje simple.
class OnboardingStep {
  const OnboardingStep({
    required this.title,
    required this.body,
    required this.accent,
    this.icon,
    this.asset,
  });

  final String title;
  final String body;
  final Color accent;
  final IconData? icon;
  final String? asset;
}

/// Contenido de ayuda de una sección.
class SectionGuide {
  const SectionGuide({
    required this.section,
    required this.name,
    required this.summary,
    required this.accent,
    required this.asset,
    required this.steps,
  });

  final AppSection section;
  final String name;
  final String summary;
  final Color accent;
  final String asset;
  final List<OnboardingStep> steps;
}

/// Bienvenida para usuarios nuevos (pantalla completa, una sola vez).
const welcomeSteps = <OnboardingStep>[
  OnboardingStep(
    asset: MbAssets.logo,
    accent: AppColors.primaryCoral,
    title: 'Bienvenido a MacroBuddy',
    body:
        'Registra lo que comes y tus entrenamientos en un solo lugar. '
        'Te enseñamos lo básico en menos de un minuto.',
  ),
  OnboardingStep(
    icon: Icons.view_agenda_outlined,
    accent: AppColors.secondaryCyan,
    title: 'Cuatro secciones',
    body:
        'Abajo tienes la barra con Dash, Nutrición, Workout y Perfil. '
        'Toca una para cambiar de sección.',
  ),
  OnboardingStep(
    asset: MbAssets.plus,
    accent: AppColors.primaryCoral,
    title: 'El botón +',
    body:
        'Está abajo a la derecha y cambia según la sección: registrar un '
        'alimento, tu peso o empezar un entrenamiento.',
  ),
  OnboardingStep(
    icon: Icons.flag_outlined,
    accent: AppColors.successGreen,
    title: 'Pon tus metas',
    body:
        'En Perfil › Editar perfil agrega tu peso, altura y tus objetivos de '
        'macros. Con eso se llenan los anillos y barras del Dashboard.',
  ),
  OnboardingStep(
    icon: Icons.help_outline,
    accent: AppColors.tertiaryPurple,
    title: '¿Tienes dudas?',
    body:
        'Cada sección tiene un botón ? arriba. Te explica la pantalla y te '
        'deja repetir su recorrido cuando quieras.',
  ),
];

const sectionGuides = <AppSection, SectionGuide>{
  AppSection.dashboard: SectionGuide(
    section: AppSection.dashboard,
    name: 'Dashboard',
    asset: MbAssets.dashboard,
    accent: AppColors.primaryCoral,
    summary: 'Tu resumen: cómo vas hoy, esta semana y tu tendencia.',
    steps: [
      OnboardingStep(
        icon: Icons.tune,
        accent: AppColors.primaryCoral,
        title: 'Hoy, Semana o Tendencia',
        body:
            'Arriba eliges el periodo. Las tarjetas cambian para mostrar '
            'hoy, los últimos 7 días o los últimos 30.',
      ),
      OnboardingStep(
        icon: Icons.donut_large,
        accent: AppColors.secondaryCyan,
        title: 'Tus anillos',
        body:
            'Coral son las calorías, cyan los entrenamientos y morado los '
            'pasos. Un anillo lleno significa meta cumplida.',
      ),
      OnboardingStep(
        asset: MbAssets.protein,
        accent: AppColors.successGreen,
        title: 'Macros y peso',
        body:
            'Las barras muestran proteína, carbohidratos y grasa contra tu '
            'objetivo. Abajo ves cómo cambia tu peso.',
      ),
      OnboardingStep(
        icon: Icons.insights,
        accent: AppColors.tertiaryPurple,
        title: 'Insights y hábitos',
        body:
            'Al final hay gráficas de tus entrenamientos y un calendario con '
            'los días que entrenaste.',
      ),
    ],
  ),
  AppSection.nutrition: SectionGuide(
    section: AppSection.nutrition,
    name: 'Nutrición',
    asset: MbAssets.fruit,
    accent: AppColors.primaryCoral,
    summary: 'Tu diario de comidas, organizado por hora.',
    steps: [
      OnboardingStep(
        asset: MbAssets.calendar,
        accent: AppColors.secondaryCyan,
        title: 'Elige el día',
        body:
            'Usa las flechas, la tira de la semana o el calendario para ver '
            'o registrar otro día.',
      ),
      OnboardingStep(
        asset: MbAssets.carb,
        accent: AppColors.warningAmber,
        title: 'Tus totales',
        body:
            'Las cuatro tarjetas muestran calorías, proteína, carbohidratos '
            'y grasa del día contra tu objetivo.',
      ),
      OnboardingStep(
        icon: Icons.schedule,
        accent: AppColors.primaryCoral,
        title: 'Registra por hora',
        body:
            'El día está dividido en horas. Toca el + de una hora para '
            'agregar lo que comiste a esa hora.',
      ),
      OnboardingStep(
        asset: MbAssets.scanBarcode,
        accent: AppColors.successGreen,
        title: 'Escanea o busca',
        body:
            'Con el botón + de abajo puedes escanear un código de barras, '
            'buscar un alimento o registrarlo a mano.',
      ),
    ],
  ),
  AppSection.workout: SectionGuide(
    section: AppSection.workout,
    name: 'Workout',
    asset: MbAssets.dumbbell,
    accent: AppColors.secondaryCyan,
    summary: 'Tu programa de entrenamiento y el registro de tus series.',
    steps: [
      OnboardingStep(
        icon: Icons.view_week_outlined,
        accent: AppColors.secondaryCyan,
        title: 'Tu semana',
        body:
            'La tira de arriba es tu semana de lunes a domingo. Los días con '
            'borde cyan son los que entrenaste.',
      ),
      OnboardingStep(
        icon: Icons.checklist,
        accent: AppColors.successGreen,
        title: 'Programa activo',
        body:
            'Aquí están tus entrenamientos. Toca uno para ver sus ejercicios. '
            'La casilla se marca cuando lo haces esta semana.',
      ),
      OnboardingStep(
        icon: Icons.play_arrow_rounded,
        accent: AppColors.primaryCoral,
        title: 'Empezar siguiente',
        body:
            'El botón grande abre el siguiente entrenamiento pendiente. Ahí '
            'ves los músculos, las series y el tiempo estimado.',
      ),
      OnboardingStep(
        icon: Icons.edit_note,
        accent: AppColors.warningAmber,
        title: 'Registra tus series',
        body:
            'Escribe peso, repeticiones y RIR (cuántas reps te sobraron). '
            'La columna Anterior te muestra tu última vez. Al final toca '
            'Terminar.',
      ),
      OnboardingStep(
        icon: Icons.add_circle_outline,
        accent: AppColors.tertiaryPurple,
        title: 'Más opciones',
        body:
            'Abajo puedes hacer un entrenamiento libre, crear uno nuevo o ver '
            'tu historial y tus récords personales.',
      ),
    ],
  ),
  AppSection.profile: SectionGuide(
    section: AppSection.profile,
    name: 'Perfil',
    asset: MbAssets.profile,
    accent: AppColors.primaryCoral,
    summary: 'Tus datos, tus metas y la configuración de la app.',
    steps: [
      OnboardingStep(
        icon: Icons.person_outline,
        accent: AppColors.primaryCoral,
        title: 'Editar perfil',
        body:
            'Actualiza tu peso, altura y objetivos de macros. Arriba ves tu '
            'peso, grasa corporal y tu racha de días entrenando.',
      ),
      OnboardingStep(
        icon: Icons.sports,
        accent: AppColors.tertiaryPurple,
        title: 'Mi entrenador',
        body:
            'Vincula a tu coach o nutriólogo. En modo guiado, tu profesional '
            'fija tus macros y tus rutinas.',
      ),
      OnboardingStep(
        icon: Icons.timer_outlined,
        accent: AppColors.secondaryCyan,
        title: 'Herramientas y alimentos',
        body:
            'En Herramientas tienes cronómetro y temporizador. En Mis '
            'alimentos guardas los que registras seguido.',
      ),
      OnboardingStep(
        icon: Icons.school_outlined,
        accent: AppColors.successGreen,
        title: 'Repetir tutoriales',
        body:
            'Desde Configuración › Tutoriales puedes ver otra vez la '
            'bienvenida y los recorridos de todas las secciones.',
      ),
    ],
  ),
};
