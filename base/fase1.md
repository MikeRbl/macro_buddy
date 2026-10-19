Fase 1: Refactorización y Modelos Base (Backend)

Renombra las referencias de elite_training a macrobuddy en ambos repositorios (pubspec.yaml, build.gradle, Info.plist, package.json, etc.).

En el backend, actualiza models/User.ts para incluir metas de macros (targetCalories, targetProtein, targetCarbs, targetFats) y un booleano isGuidedMode.

Crea el modelo models/DailyNutritionLog.ts para guardar el registro de alimentos por día (userId, date, macros totales, y array de consumedItems).

Actualiza models/UserWorkout.ts para soportar la lógica de sobrecarga progresiva (agrega campos suggestedNextWeight y suggestedNextReps).

Crea los endpoints REST en Next.js para hacer CRUD sobre DailyNutritionLog.