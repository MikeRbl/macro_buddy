. Solución al Error 503 de OpenFoodFacts (Frontend)
El servidor de OpenFoodFacts está rechazando las peticiones por falta de identificación adecuada.

En el archivo open_food_facts_service.dart, actualiza la cabecera HTTP de todas las peticiones GET.

Agrega: headers: {'User-Agent': 'MacrobuddyApp/1.0 (maicoalf77@gmail.com)'}.

Maneja el error 503: Si el código de respuesta es 503 o 504, lanza un mensaje específico "El servidor de OpenFoodFacts está temporalmente saturado. Intenta de nuevo en unos momentos o usa el registro manual."

2. Rediseño de la Pestaña "Escanear" (food_entry_screen.dart / barcode_scanner_screen.dart)
Actualmente, el escáner ocupa toda la pantalla de forma confusa. Vamos a limitarlo.

Overlay y Cuadrícula:

Envuelve la vista de la cámara (MobileScanner) en un contenedor con altura fija (ej. 300px).

Dibuja un "Overlay" oscuro con un recorte cuadrado transparente en el centro y esquinas blancas (guías de enfoque) usando un CustomPainter.

Agrega el texto "Alinea el código de barras dentro del recuadro" encima del escáner.

Ingreso Manual de Código de Barras:

Justo debajo de la vista de la cámara, añade un divisor "O ingresa el código".

Coloca un TextField tipo numérico (keyboardType: TextInputType.number) y un botón "Buscar Código". Al presionarlo, debe ejecutar la misma función de búsqueda en OpenFoodFacts que usa el escáner automático.

3. Rediseño de la Pestaña "Búsqueda" (food_entry_screen.dart)
Fix de Superposición del Teclado:

Envuelve el cuerpo principal de la vista en un SingleChildScrollView o asegura que el Scaffold tenga resizeToAvoidBottomInset: true para que el teclado no tape los resultados ni el modal inferior.

Modal de "Registrar alimento" (Manual):

Asegúrate de que el modal inferior se desplace hacia arriba cuando el teclado se abre (usando Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom))).
