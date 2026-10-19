# Plan de Corrección UI/UX y Funcionalidad - Macrobuddy

**Regla General:** Respeta los skills cargados (`apple-design`, `caveman`, `ponytail`, `grill-me`). No uses diseños genéricos; sigue estrictamente la jerarquía de widgets, colores hexadecimales y reglas de negocio descritas a continuación.

---

## FASE A: Configuración de Assets, Tema y Componentes Base

1. **Registro de Assets (`pubspec.yaml`):**
   - Registra la carpeta `Assets/` (o `assets/icons/` y `assets/logos/` según el nombre exacto en el directorio) dentro de `pubspec.yaml`.
   - Crea un widget helper `lib/core/widgets/mb_icon.dart` (`MbIcon`) que cargue los iconos personalizados desde `Assets/` aplicando `ColorFilter.mode(color, BlendMode.srcIn)` para cambiar entre estado activo (`Colors.white` o color de acento) e inactivo (`Color(0xFF6E6E73)`).

2. **Paleta de Colores Exacta (`lib/theme/app_theme.dart`):**
   - `background`: `#0A0A0A`
   - `surfaceCard`: `#141416` con borde de 1px `#262629` (`borderRadius: 20`)
   - `primaryCoral`: `#FF6B6B` (Calorías / Botones principales / Acentos de nutrición)
   - `secondaryCyan`: `#00E5FF` (Entrenamiento / Proteína / Sobrecarga)
   - `tertiaryPurple`: `#B388FF` (Pasos / Tendencia de peso / Modo Guiado Pro)
   - `warningAmber`: `#FFB300` (Grasas)
   - `successGreen`: `#00E676` (Indicadores positivos / Carbohidratos alterno)
   - Tipografías: `Inter` para encabezados y cuerpo; `JetBrains Mono` (mediante `google_fonts`) para todos los números, pesos, kcal, gramos y relojes.

---

## FASE B: Corrección del Navbar (4 Tabs) y Botón `+` Flotante Contextual

1. **Bottom Navigation Bar (`lib/features/navigation/main_scaffold.dart`):**
   - **ELIMINAR** el botón `+` de adentro del Navbar.
   - El Navbar debe ser una píldora flotante inferior (`margin: EdgeInsets.fromLTRB(16, 0, 16, 20)`, `height: 68`, `borderRadius: 34`, color `#141416` con `Opacity(0.92)` y `BackdropFilter` blur 16, borde 1px `Colors.white.withOpacity(0.08)`).
   - **Orden estricto de izquierda a derecha (4 ítems distribuidos con `MainAxisAlignment.spaceEvenly`):**
     1. **Dashboard** (Icono Grid / Cuadrícula + label "Dash")
     2. **Nutrición** (Icono Manzana de `Assets` + label "Nutrición")
     3. **Entrenamientos** (Icono Mancuerna de `Assets` + label "Workout")
     4. **Perfil** (Icono Usuario de `Assets` + label "Perfil")
   - Indicador activo: Ícono y texto en color de acento (`#FF6B6B` o `#00E5FF` en Workout) con un pequeño punto brillante de 4px debajo del label.

2. **Botón `+` Flotante Contextual (Encima del Navbar):**
   - Posiciona un `FloatingActionButton` circular (`backgroundColor: Color(0xFFFF6B6B)`, tamaño `56x56`) flotando **por encima** del Navbar (en el extremo inferior derecho, `bottom: 100, right: 20`).
   - **Comportamiento Contextual:**
     - **En Tab 1 (Nutrición):** Al tocarlo, abre el modal/pantalla de **Ingresar Alimento** con acceso directo a Escanear código de barras, Búsqueda en OpenFoodFacts o Registro Manual para la hora actual.
     - **En Tab 2 (Entrenamientos):** Al tocarlo, abre un BottomSheet con: `"Iniciar entrenamiento vacío"`, `"Crear nueva rutina"` y `"Añadir ejercicio"`.
     - **En Tab 0 (Dashboard):** Muestra un menú rápido (Quick Action Sheet) que permite elegir entre `"Registrar Alimento"`, `"Registrar Peso Corporal"` o `"Iniciar Entrenamiento"`.
     - **En Tab 3 (Perfil):** Ocultar el botón `+`.

---

## FASE C: Rediseño de las 5 Vistas Principales

### 1. Vista Dashboard (`dashboard_screen.dart`)
- **Header:** Fila superior con el Logo circular (rayo en círculo) a la izquierda, columna con título `"MACROBUDDY"` (Inter Bold 20) y fecha actual (`"Hoy, 18 de Octubre"`, gris 12), y a la derecha un botón circular oscuro con el icono de campana y punto rojo de notificación.
- **Segmented Control:** Selector de 3 opciones (`"Hoy"`, `"Semana"`, `"Tendencia"`) dentro de un contenedor oscuro redondeado (`#141416`).
- **Tarjeta 1 - OBJETIVOS DIARIOS:**
  - Header de tarjeta: `"OBJETIVOS DIARIOS"` a la izquierda y badge `"78% Completado"` (fondo `#00E5FF` con opacidad 0.12, texto `#00E5FF`) a la derecha.
  - Centro: Gráfico de **3 anillos concéntricos** (`CustomPainter` con `StrokeCap.round`):
    - Anillo Exterior: Calorías (`#FF6B6B`).
    - Anillo Medio: Entrenamiento (`#00E5FF`).
    - Anillo Interior: Pasos (`#B388FF`).
    - Centro de los anillos: Número grande en JetBrains Mono (`"560"`) y subtítulo `"KCAL RESTANTES"`.
  - Parte inferior de la tarjeta: 3 filas de leyenda (`Calorías`, `Entrenamiento`, `Pasos`), cada una con su punto de color a la izquierda y a la derecha el progreso (`1,840 / 2,400` en blanco/gris y debajo `"560 restantes"` en el color del anillo).
- **Tarjeta 2 - DISTRIBUCIÓN DE MACROS:**
  - Header: `"DISTRIBUCIÓN DE MACROS"` y `"Objetivo Diario"`.
  - Contenido: `Row` con 3 sub-tarjetas oscuras (`#1C1C1F`, `borderRadius: 14`).
    1. `Proteína` + porcentaje en cyan (`80%`), barra de progreso cyan, texto inferior `145/180g`.
    2. `Carbos` + porcentaje en coral (`85%`), barra de progreso coral, texto inferior `190/220g`.
    3. `Grasas` + porcentaje en púrpura (`80%`), barra de progreso púrpura, texto inferior `52/65g`.
- **Tarjeta 3 - TENDENCIA DE PESO:**
  - Header `"TENDENCIA DE PESO"` con chevron a la derecha.
  - Fila con peso actual gigante (`"73.4 kg"`) y pill verde (`"↓ -0.4 kg"`).
  - Gráfico de línea curva (`CustomPainter`) en color púrpura (`#B388FF`) con degradado translúcido debajo de la curva y etiquetas `L M X J V S D` en el eje X.

### 2. Vista Nutrición - Bitácora por Horas (`nutrition_screen.dart`)
- **CAMBIO CRÍTICO DE LÓGICA:** Eliminar la agrupación rígida por `"Desayuno"`, `"Comida"` y `"Cena"`. Los alimentos en el modelo `DailyNutritionLog` (Backend y Frontend) deben guardarse con un campo `time` (String `"HH:mm"`, ej. `"08:00"`, `"11:00"`, `"13:00"`, `"16:30"`) y un `label` opcional.
- **Header:** Selector de fecha (`< Ayer, 18 de Octubre >`) e icono de calendario.
- **Tira Semanal (Week Strip):** 7 píldoras verticales (`L 12` a `D 18`). El día seleccionado tiene borde `#FF6B6B` y punto coral inferior.
- **Fila de Mini-Tarjetas de Macros:** 4 contenedores compactos en una sola fila:
  - `CAL 2,120 / 2,400` (barra coral)
  - `P 165g / 180g` (barra cyan)
  - `F 58g / 70g` (barra ámbar)
  - `C 245g / 260g` (barra verde)
- **Timeline Horario (Cuerpo Principal):**
  - Un `ListView` vertical que muestra los bloques de horas del día (por defecto genera bloques cada 2-3 horas o las horas donde el usuario tenga registros: `8:00 AM`, `11:00 AM`, `1:00 PM`, `4:30 PM`, `8:00 PM`, más opción de elegir cualquier hora).
  - **Columna Izquierda (Ancho 56px):** Muestra la hora (`8:00 AM`), debajo un botón circular pequeño `+` (`28x28`) para agregar alimento directamente a esa hora, y una línea vertical gris (`1px`) que conecta con la siguiente hora.
  - **Columna Derecha (Expanded):**
    - Encabezado del bloque horario con la suma de macros de esa hora a la derecha (`125 kcal • 15P • 2F • 18C`).
    - Si hay alimentos en esa hora: Tarjetas oscuras con icono del alimento a la izquierda, título en blanco, subtítulo en JetBrains Mono (`125 kcal • 15P • 2F • 18C`), gramaje (`1 bol (200g)`) e icono de lápiz para editar.
    - Si no hay alimentos en una hora intermedia: Contenedor con borde punteado/sutil que dice `"Sin registros a esta hora"` y botón de texto `"Registrar"` en color coral.
- **Barra de Búsqueda Flotante:** Justo encima del Navbar, un contenedor tipo píldora con icono de lupa, texto `"Buscar o escanear alimento..."` e icono de escáner a la derecha.

### 3. Vista Ingresar Alimento y Escáner (`food_entry_screen.dart` / `barcode_scanner_screen.dart`)
- **Top Bar:** Botón `X` para cerrar, selector de hora en forma de píldora (`"1:30 PM"` con selector `showTimePicker` al tocarlo), y mini indicador circular de calorías restantes (`1,420/2.4k`).
- **Píldoras de Modo (3 botones):**
  1. `Escanear` (icono código de barras cyan — abre el lector de cámara).
  2. `Búsqueda` (borde activo coral).
  3. `IA Foto` (icono púrpura).
- **Buscador:** `TextField` oscuro `"Buscar un alimento, marca o receta..."`.
- **Sección FAVORITOS FRECUENTES:** Carrusel horizontal de tarjetas cuadradas compactas con icono, botón `+`, nombre y kcal/P.
- **Sección PICKS DEL MOMENTO / RESULTADOS:** Lista vertical de tarjetas de alimentos con badge de porción (`200g`), macros coloreados (`330 kcal` en coral, `62g P` en cyan, `0g C` en gris, `7g G` en púrpura) y botón circular de selección a la derecha.
- **Barra Inferior de Confirmación:** Muestra `"X alimentos seleccionados"` + suma de kcal/macros a la izquierda, y botón coral `"Registrar alimentos ->"` a la derecha.

### 4. Vista Entrenamientos (`workouts_screen.dart`)
- **Header:** Título `"WORKOUT"` en negrita y 3 botones circulares a la derecha (Calendario, `+`, Más opciones).
- **Tira Semanal:** Píldoras verticales (`12 Mo` a `17 Sa`), con el día activo bordeado en cyan brillante (`#00E5FF`).
- **Sección Active Program:** Header `"Active Program"` y `"Week 5"`.
- **Tarjeta Principal del Programa:** Encabezado `"Min Max Personal"` (`5 workouts • 2 rest days`) con icono cuadrado cyan a la izquierda.
- **Lista de Rutinas (`Workout A`, `B`, `C`, `D`, `E`):** Cada bloque muestra el nombre del workout, lista de ejercicios en gris, una fila (`Wrap`) de chips oscuros para los músculos (`Biceps`, `Chest`, `Lats`, `Side Delts`, `Triceps`) y un checkbox cuadrado a la derecha.
- **Tarjetas de Descanso:** Al final de la lista, tarjetas internas con fondo oscuro diferenciado para `"Rest Day 1 • Recovery & Mobility"` (badge `"DESCANSO"` morado) y `"Rest Day 2 • Full Regeneration"` (badge `"RECARGA"` cyan).

### 5. Vista Perfil y Ajustes (`more_screen.dart` / `profile_screen.dart`)
- **Top Bar:** Logo + `"Macrobuddy"` a la izquierda, `"PROFILE"` y mini avatar a la derecha.
- **Header:** Subtítulo `"CONFIGURACIÓN PERSONAL"` en coral, título `"Perfil & Ajustes"` y botones circulares de editar y ajustes.
- **Tarjeta de Atleta:** Avatar circular con borde degradado, nombre del usuario, badge `"PRO ⚡"`, `@username`, texto `"Atleta Verificado"` en cyan. Debajo, `Row` con 3 cajas de métricas: `PESO ACTUAL (kg)`, `GRASA EST. (%)`, `RACHA ACTIVA (días)`.
- **Tarjeta Mi Entrenador (Professional Link):**
  - Contenedor con fondo `#1A1426` y borde púrpura `#B388FF` (opacidad 0.3).
  - Header con icono, título `"Mi Entrenador"`, subtítulo `"Professional Link v2.4"` y badge `"MODO GUIADO ACTIVO"` a la derecha.
  - Sub-tarjeta mostrando el profesional vinculado (o estado sin vincular).
  - Caja de bloqueo con icono de candado coral explaining que la edición manual está bloqueada si `isGuidedMode == true`, mostrando chips de `kcal 🔒`, `P 🔒`, `C 🔒`.
  - Dos botones inferiores en fila: `"Ver plan asignado"` (púrpura sólido) y `"Desvincular"` (outlined).
- **Listas de Configuración:** Secciones agrupadas para `"CUENTA & PREFERENCIAS"`, `"ENTRENAMIENTO & DISPOSITIVOS"` y `"SOPORTE & PRIVACIDAD"` (incluyendo `"Cerrar Sesión"` en texto e icono rojo coral).

---

## FASE D: Corrección Técnica de OpenFoodFacts y Red en APK

1. **Servicio OpenFoodFacts (`open_food_facts_service.dart`):**
   - Usa la URL: `https://world.openfoodfacts.org/api/v2/product/$barcode.json?fields=product_name,nutriments,serving_size,quantity`.
   - **Obligatorio:** Envía el header `'User-Agent': 'Macrobuddy - Flutter App - Version 1.0'`.
   - Extrae los datos de `json['product']['nutriments']` manejando tipos `num` o `String` de forma segura (`double.tryParse`):
     - Calorías: `nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'] ?? 0`
     - Proteína: `nutriments['proteins_100g'] ?? nutriments['proteins'] ?? 0`
     - Carbohidratos: `nutriments['carbohydrates_100g'] ?? nutriments['carbohydrates'] ?? 0`
     - Grasas: `nutriments['fat_100g'] ?? nutriments['fat'] ?? 0`
   - En `barcode_scanner_screen.dart`, usa una bandera `_isProcessing = false` en `onDetect`. Al detectar el primer código válido, pon `_isProcessing = true`, detén la cámara (`controller.stop()`), muestra un `CircularProgressIndicator`, consulta OpenFoodFacts y abre el formulario pre-llenado con los datos obtenidos para que el usuario solo ajuste los gramos y la hora (`time`) antes de guardar.
   - Si `status != 1` en la respuesta de OpenFoodFacts, muestra un `SnackBar` claro: `"Producto no encontrado en OpenFoodFacts ($barcode). Regístralo manualmente."` y abre el formulario manual.

2. **Conexión del APK al Servidor Local (`api_config.dart`):**
   - Permite configurar la URL base mediante `--dart-define=API_BASE_URL=http://TU_IP_LOCAL:3000` o agrega una opción visible en la pantalla de Login/Ajustes para cambiar la IP del servidor backend sin tener que recompilar el APK cuando se prueba en un dispositivo físico.




   