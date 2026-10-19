Plan de Corrección Quirúrgica UI/UX - Macrobuddy
Instrucción para el Agente: Corrige los siguientes errores visuales y de experiencia de usuario en los archivos de Flutter. Revisa cuidadosamente los Row, Expanded y Stack para evitar desbordamientos de texto (text wrapping) y superposición de elementos.

1. Corrección del main_scaffold.dart (Navbar y FAB)
Orden del Navbar: Asegúrate de que el Row del bottom navigation bar tenga EXACTAMENTE 4 botones en este orden: Dashboard (ícono grid), Nutrición (ícono manzana), Workouts (ícono mancuerna), Perfil (ícono usuario).

Remover el + del Navbar: El botón de agregar no debe ser parte de los tabs.

Posicionamiento del FAB: Añade un FloatingActionButton real al Scaffold (usa floatingActionButton: ... y floatingActionButtonLocation: FloatingActionButtonLocation.endFloat).

Padding inferior: Para que el FAB y el Navbar flotante no tapen el contenido de las pantallas (como las listas de nutrición o entrenamientos), asegúrate de que el cuerpo del Scaffold (o las vistas hijas) tengan un padding inferior de al menos 120 px.

2. Corrección de la Vista Nutrición (nutrition_screen.dart)
Eliminar buscador flotante: Elimina el contenedor flotante (Positioned o Stack) que dice "Buscar o escanear alimento..." que estorba en la parte inferior. La búsqueda se manejará al presionar el FAB (+).

Timeline de 24 Horas: Modifica la lista del diario. En lugar de un listado estático, utiliza un ListView.builder que genere 24 bloques de tiempo (de 00:00 a 23:00 horas).

Cada bloque de hora debe mostrar su etiqueta (ej. 08:00 AM).

Cada bloque debe permitir hacer clic en un mini botón + a su izquierda para registrar comida específicamente a esa hora.

El diseño visual de la línea de tiempo (línea vertical a la izquierda) debe mantenerse limpio.

3. Corrección de la Vista Ingresar Alimento (food_entry_screen.dart)
Arreglar Header (Text Wrapping): El título "Ingresar alimento" se está aplastando verticalmente letra por letra. En el Row superior del header, envuelve el Text("Ingresar alimento") con un Expanded y usa maxLines: 1, overflow: TextOverflow.ellipsis, o quita los anchos fijos (width) que lo estén comprimiendo contra el reloj y el badge de calorías.

Eliminar "IA Foto": En la fila de botones/píldoras de acción, elimina por completo el botón/tab de "IA Foto". Solo deben quedar "Escanear" y "Búsqueda".

4. Corrección de la Vista Perfil (profile_screen.dart / more_screen.dart)
Eliminar Comunidad: En la lista de opciones debajo de "Professional Link", elimina por completo el ListTile o botón que hace referencia a "Comunidad".