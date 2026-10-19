Fase 3: Vistas y Binding de Datos (Frontend)

Dashboard: Implementa la vista con los 3 anillos de progreso (Calorías, Entrenamiento, Pasos) y las tarjetas de gráficos de tendencias. Conecta esto a los endpoints del usuario para que se actualice en tiempo real.

Nutrition & Food Logs: Crea la vista de Macros. Instala y configura el paquete mobile_scanner en Flutter.

Integración OpenFoodFacts: Crea un servicio en Flutter open_food_facts_service.dart que reciba un código de barras del escáner, consulte la API [https://world.openfoodfacts.org/api/v2/product/](https://world.openfoodfacts.org/api/v2/product/)[barcode].json, extraiga los macros (kcal, proteínas, carbohidratos, grasas) y permita al usuario guardar esto en su DailyNutritionLog mediante nuestro backend.

Workouts (Sobrecarga Progresiva): Actualiza la vista de rutina activa. La tabla de sets debe mostrar el "Rendimiento Anterior" y resaltar visualmente la "Sugerencia de Sobrecarga" (peso/reps) calculada por el backend.

Perfil y Entrenador: Crea la vista de perfil incluyendo la tarjeta "Professional Link". Implementa la lógica donde, si isGuidedMode == true, los inputs de edición de macros y rutinas se deshabilitan.
