# Catálogo de alimentos propio

Reemplaza la consulta en vivo a OpenFoodFacts (OFF) por un catálogo propio:
sembrado con la exportación de OFF filtrada a México, guardado en MongoDB,
copiado al teléfono como SQLite y completado poco a poco por los usuarios.

## Cómo funciona

**Al escanear un código** la app busca, en orden:

1. Mis alimentos (productos que el usuario creó, en su teléfono)
2. Catálogo local (SQLite, funciona sin internet)
3. Servidor de MacroBuddy (`GET /api/foods/barcode/:code`, lo aprobado después del último sync)
4. API de OFF como último recurso (`FoodRepository.useOpenFoodFactsFallback`)
5. Si nadie lo tiene → hoja de registro manual

Cada código que no aparece en el servidor se cuenta en `missingbarcodes`:
es la lista de qué productos conviene agregar primero.

**Al registrar un producto nuevo** (manual, o encontrado solo en OFF), la
hoja tiene el interruptor "Guardar en mis alimentos". Si el producto tiene
código de barras, después de guardar aparece:

> ¿Quieres contribuir? Si quieres contribuir a tener este producto en
> MacroBuddy, manda una solicitud de verificación. Si no, este producto
> solo se almacenará en tu equipo.

- **Solo en mi equipo** → queda en `user_foods.db`; no se vuelve a preguntar salvo que cambien los datos.
- **Enviar solicitud** → valida los macros (regla de Atwater), pide foto de la tabla nutrimental y lo manda a `POST /api/foods/contributions`.

**Aprobación**

- Automática por consenso: 3 usuarios distintos (`FOOD_CONSENSUS_MIN`) mandan el mismo código con macros que coinciden (±10 %) → se aprueba con la mediana. Las correcciones de productos existentes y las capturas dudosas siempre pasan por un revisor.
- Manual: un correo en `ADMIN_EMAILS` revisa la cola con los endpoints de `/api/admin/*`.

Lo aprobado sube la `version` del catálogo; la app lo baja en su próximo
sync (al iniciar sesión, máximo cada 12 h) y la copia del usuario pasa a
"aprobada".

## Puesta en marcha

### Backend

```bash
cd backend
npm i -D @duckdb/node-api        # lector de Parquet, solo para importar
```

En `.env`:

```
ADMIN_EMAILS=tu@correo.com
FOOD_CONSENSUS_MIN=3
```

Descarga `food.parquet` (~4 GB) de
https://huggingface.co/datasets/openfoodfacts/product-database
a `backend/data/` (ignorado por git) y luego:

```bash
# 1. ver qué saldría, sin escribir en Mongo
npm run import:foods -- --parquet data/food.parquet --dry-run

# 2. importar OFF (México) + genéricos
npm run import:foods -- --parquet data/food.parquet --generics data/genericos_mx.csv

# 3. generar el SQLite que va dentro de la app (Node ≥ 22.13)
npm run export:catalog -- --max-items 40000
#    → frontend/Assets/catalog/food_catalog.db + food_catalog.json
```

El import se puede repetir: actualiza en lugar de duplicar y solo cambia la
versión de lo que cambió. Une duplicados de OFF (mismo nombre, marca y
macros con distinto código) en un solo alimento con varios códigos.

`--max-items` controla el peso de la app. Entran todos los genéricos y los
productos más escaneados; el resto se encuentra igual al escanear (servidor)
o al buscar con pocos resultados (`GET /api/foods/search`).

### Genéricos (`backend/data/genericos_mx.csv`)

Valores por 100 g (o 100 ml). Porciones separadas por `|`:

```
name,kcal,protein,carbs,fat,base_unit,servings,popularity,source_ref
"Tortilla de maíz",...,...,...,...,g,"1 pieza:30|2 piezas:60",,<fuente>
```

Fuentes posibles: USDA FoodData Central (dominio público), SMAE o tablas del
INSP (revisar licencia antes de usarlas). Filas con macros imposibles se
reportan y no se importan.

### App

```bash
cd frontend
flutter pub get
```

Nuevas dependencias: `sqflite`, `path`, `http_parser`, `image_picker`. Se
agregó `NSPhotoLibraryUsageDescription` en iOS. Si la app se compila sin
`food_catalog.db`, crea el catálogo vacío y lo llena con el sync.

## Endpoints

| Método | Ruta | Para qué |
|---|---|---|
| GET | `/api/foods/sync?since=N&limit=500` | Deltas del catálogo (incluye borrados) |
| GET | `/api/foods/barcode/:code` | Un producto por código; 404 lo cuenta como faltante |
| GET | `/api/foods/search?q=` | Búsqueda en todo el catálogo |
| GET | `/api/foods/contributions` | Estado de mis solicitudes |
| POST | `/api/foods/contributions` | Enviar producto (multipart, con fotos) |
| GET | `/api/admin/contributions?status=pending` | Cola de revisión |
| PATCH | `/api/admin/contributions/:id` | `{action:"approve", edits?}` o `{action:"reject", note}` |
| GET | `/api/admin/food-photos/:id` | Foto de una solicitud |
| GET | `/api/admin/missing-barcodes` | Códigos más buscados que faltan |

## Licencia de los datos

Los datos de OFF son ODbL: la base derivada debe compartirse bajo la misma
licencia y hay que dar atribución ("Datos de Open Food Facts,
openfoodfacts.org") en la app, por ejemplo en la pantalla de Perfil o Acerca de.

## Pendiente

- Pantalla "Mis alimentos" (listar, editar, borrar y reenviar productos propios; el repositorio ya expone `myFoods()` y `deleteUserFood()`).
- Panel web de revisión para los admins (hoy son endpoints).
- Mandar a OFF las contribuciones aprobadas, para devolver a la comunidad.
- Si el catálogo local crece mucho, cambiar la búsqueda `LIKE` por FTS4.
