# Informe de limpieza de código · 19/11/2026

Respaldo previo: `D:\Michel-Proyect\ejarad_app_respaldo_2026-11-19.zip` (lib, test, migraciones, función de servidor, build.gradle.kts, AndroidManifest y pubspec). El proyecto no es un repositorio Git, por eso el respaldo es el único camino de vuelta.

## 1. Qué se elimina

| Archivo | Por qué | Comprobación |
|---|---|---|
| `lib/config/supabase_config.dart` | 0 bytes | Ningún `import` en `lib/` ni `test/` (la URL y la llave pública están en `main.dart`) |
| `lib/models/anexo_model.dart` | 0 bytes | Sin referencias |
| `lib/models/catalogo_item.dart` | 0 bytes | Sin referencias (el catálogo se maneja como `Map` con extensiones en `catalogo_repository.dart`) |
| `lib/models/cotizacion_model.dart` | 0 bytes | Sin referencias |
| `lib/models/proyecto_model.dart` | 0 bytes | Sin referencias |
| `lib/screens/proyectos/anexo_form_screen.dart` | Pantalla "Anexo" a la que no lleva ningún botón ni ruta; la clase `AnexoFormScreen` no se instancia en ningún lado | `grep` de `AnexoFormScreen` y `anexo_form`: solo aparece en su propio archivo |

Riesgo adicional de dejar `anexo_form_screen.dart`: marca un hito como completado con solo escribir observaciones, sin pasar por la regla de "completar sin evidencia" (motivo técnico de al menos 10 caracteres). Si alguien la conectara por error, se saltaría esa regla.

## 2. Qué se modifica

| Archivo | Cambio | Motivo |
|---|---|---|
| `screens/proyectos/proyectos_list_screen.dart` y `screens/dashboard/dashboard_screen.dart` | El filtro "Planificación" pasa a "Pendiente" | "Planificación" no existe en el enum `estado_proyecto` de la base de datos (comprobado: PostgREST responde `invalid input value for enum`) y la app nunca crea obras en ese estado; el filtro no podía mostrar nada |
| `screens/cotizador/bom_preview_screen.dart` | El cable también se elige por categoría (Cat 5e, 6 o 6A) | Con "Cat 5e UTP" el BOM tomaba el cable Cat 6 del catálogo por coincidencia parcial de palabras |
| `test/catalogo_matching_test.dart` (nuevo) | Pruebas de la elección por categoría | Evita que vuelva a mezclarse Cat 6 con Cat 6A |

## 3. Qué se deja (y por qué)

| Elemento | Motivo para dejarlo |
|---|---|
| Tablas `anexos_proyecto` y `anexo_detalles`; columnas `proyecto_materiales.anexo_id` y `es_adicional` | Forman parte del modelo de datos descrito en el informe (E-R y diccionario) como presupuestos adicionales. Tienen RLS por rol desde la Fase 4 y el acceso anónimo está revocado (comprobado el 19/11/2026: `42501 permission denied`) |
| Tabla `actas_entrega` | Tabla heredada documentada en el informe; solo el Admin accede. Se puede eliminar más adelante tras exportar sus datos (hoy no contiene registros) |
| `AuthService.enviarRecuperacion()` | Ya tiene pantalla: `lib/screens/auth/recuperar_contrasena_screen.dart` (correo, código de un solo uso y contraseña nueva). Requiere pegar la plantilla `supabase/plantillas/recuperar_contrasena.html` en Supabase |
| `SupabaseService.eliminarEvidencia()` y `quitarMiembroEquipo()` | Ya tienen interfaz, solo para Admin y Supervisor y con la obra abierta: papelera en la lista de evidencias de un hito completado y botón de quitar personal en la pestaña Equipo (ambos piden confirmación) |
| `SupabaseService.toggleActivoCatalogo()` | Ahora la usa el interruptor Activo/Inactivo de cada ítem del catálogo |
| `SupabaseService.actualizarPrecioInsumo()` y `EvidenciaRepository.tomar()` | **Eliminados**: el formulario del catálogo ya edita costo y precio, y la pantalla de evidencia toma la foto con su propio selector |
| Migraciones de las Fases 2 a 5 y la Edge Function `admin-users` | Son el historial real del esquema y de la seguridad |

## 4. Fuera del código: lo que debe actualizarse a mano

- **Figura 34** del informe (mapa de navegación): la imagen todavía dibuja el nodo "Anexo". Hay que regenerarla sin ese nodo (prompt actualizado en `PROMPTS_FIGURAS_27-42.md`).
- **Figura 26** (componentes): verificar que no mencione `anexo_form`.
