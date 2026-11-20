# Revisión del informe v9 y de la app · 19/11/2026

## 1. Norma ANSI/TIA-568: edición usada

| Documento | Edición vigente | Qué se usa en la app |
|---|---|---|
| ANSI/TIA-568.2-E | Octubre de 2024 | Componentes de cobre (Cat 5e, 6, 6A): el canal se certifica por el componente de **menor** categoría |
| ANSI/TIA-568.1-E | 2020 | Diseño del cableado de edificios comerciales: enlace permanente horizontal ≤ 90 m, canal ≤ 100 m |
| ANSI/TIA-568.0-E | 2020 | Requisitos genéricos |

La app antes solo decía "ANSI/TIA-568" sin edición. Ahora la constante `TIA568Calculator.normaReferencia` ("ANSI/TIA-568.1-E y 568.2-E") se imprime en el PDF de la cotización.
Verificar antes de entregar: TIA está consolidando 568.0 y 568.1 en una edición "F" (previsión: fines de 2026 o inicios de 2027); mientras no se publique, las "E" siguen vigentes.

## 2. Cambios en la app

| Archivo | Cambio |
|---|---|
| `core/engine/tia568_calculator.dart` | Troncal del IDF limitado a 90 m en cobre; switches por bloque de puertos; constante de norma; comentarios que distinguen norma de criterio de empresa |
| `screens/cotizador/bom_preview_screen.dart` | Jacks, patch panels y patch cords de la **misma categoría** que el cable; switches según puntos; el correlativo se asigna **al guardar** (antes se gastaba al abrir la pantalla y dejaba huecos); PDF previo sale como PROFORMA |
| `screens/cotizador/cotizador_screen.dart` | Se retira "Fibra OM3" (generaba una lista de cobre); validación del troncal ≤ 90 m; ayuda "ingrese el punto más lejano" |
| `services/catalogo_repository.dart` | `buscarMejor` admite `algunoDe` y `excluidos` |
| `services/pdf_service.dart` | Muestra la edición de la norma |
| `screens/trazabilidad/evidencia_form_screen.dart` | Tras escanear un QR busca el SKU en el catálogo (estaba definido y nunca se usaba) |
| `screens/proyectos/proyecto_detail_screen.dart` | Corrección del contexto tras `await` |
| `android/app/build.gradle.kts` | Firma de release con `key.properties` si existe (si no, usa la llave de depuración) |
| `android/app/src/main/AndroidManifest.xml` | Nombre visible de la app: "EJARAD TIC" (era "ejarad_app") |
| `supabase/migrations/20261119_fase5_estados_proyecto.sql` | Agrega 'Pausado' y 'Completado' a `estado_proyecto` (idempotente) |
| `test/tia568_calculator_test.dart` | 14 pruebas del motor (100 % de cobertura) |

Resultado: `flutter analyze` 0 errores, 0 advertencias, 22 sugerencias de estilo · `flutter test` 25/25 · motor 33/33 líneas.

## 3. Hallazgos que quedan abiertos

1. **Archivos vacíos (0 bytes)**: `lib/config/supabase_config.dart`, `lib/models/anexo_model.dart`, `catalogo_item.dart`, `cotizacion_model.dart`, `proyecto_model.dart`. No se importan en ningún lado; conviene borrarlos.
2. **`anexo_form_screen.dart`** no es alcanzable desde ninguna pantalla (código muerto). La Figura 34 todavía dibuja un nodo "Anexo".
3. **`enviarRecuperacion()`** en `auth_service.dart` no tiene pantalla; el informe ya no promete la recuperación de contraseña.
4. **Esquema base** (tablas de la Fase 1) y los enums no están en `supabase/migrations`; solo están las fases 2 a 5. Exportar con `supabase db dump --schema public`.
5. **Catálogo**: no hay jacks, patch panels ni patch cords Cat 6A. Con cable Cat 6A el BOM mostrará ítems referenciales sin precio de catálogo hasta que se agreguen.
6. **APK release** firmado con la llave de depuración (y `applicationId` = `com.example.ejarad_app`). Para firmar con llave propia: crear el keystore y `android/key.properties`.
7. **Proyecto Supabase**: desde este equipo la dirección `mtlwfvnsghoysqksebbo.supabase.co` no resuelve (DNS). Lo más probable es que el plan gratuito lo haya pausado por inactividad; restaurarlo desde el panel antes de probar o exponer.
8. **Arquitectura "limpia"**: el código tiene tres capas, pero no define casos de uso ni interfaces de repositorio; el informe lo presenta como "capas inspiradas en Clean Architecture", que es defendible.

## 4. Cambios en el informe (copia `INFORME_PRACTICAS_v10_revisado.docx`)

Todo lo nuevo o modificado está **resaltado en amarillo** (33 párrafos y celdas): quitar el resaltado cuando se revise.
Incluye: portada, roles del capítulo II, marco teórico, burn-up (en lugar de burndown), títulos de las Figuras 17 y 18, fichas HU-03, HU-09 y HU-13 alineadas con la app, Tablas 22, 24, 31, 35, 36 (D-12 a D-15), 37, 40 y 42, límites del motor de estimación, resumen ejecutivo, sugerencias 3.4, referencias (ISO/IEC 25010, ANSI/TIA-568.1-E y 568.2-E, Ley 29733) y gráfico de la Figura 59.

## 5. Pendiente de hacer en Word

- Tabla de contenido (Referencias → Tabla de contenido) y listas de tablas y figuras.
- Dedicatoria (sigue diciendo "Opcional.").
- Anexos 01 a 13.
- Rehacer la captura de la Figura 43 (BOM) después de agregar al catálogo los componentes Cat 6A, y regenerar la Figura 34 sin el nodo "Anexo".

## 6. Actualización del 19/11/2026 (tarde)

- **Supabase verificado** (proyecto activo): Fase 4 aplicada (el acceso anónimo a `anexos_proyecto`, `anexo_detalles` y `actas_entrega` responde `42501`), Fase 5 aplicada (`estado_proyecto` acepta 'Pausado' y 'Completado'). El estado 'Planificación' no existe en la base; los filtros de la app pasaron a 'Pendiente'.
- **Limpieza de código**: ver `INFORME_LIMPIEZA_CODIGO.md` (5 archivos vacíos y la pantalla de anexos eliminados; respaldo en `D:\Michel-Proyect\ejarad_app_respaldo_2026-11-19.zip`).
- **Cable por categoría**: ahora el cable también se elige por categoría; 9 pruebas nuevas (34 en total).
- **Catálogo**: `supabase/datos/20261119_catalogo_cat6a_cat5e.sql` inserta los ítems Cat 6A y el cable Cat 5e **inactivos** y con precios referenciales; revisar precios y activar desde la app.
- **Informe v11** (`INFORME_PRACTICAS_v11_revisado.docx`): los cambios nuevos están resaltados en **cian** y los de la v10 siguen en amarillo.
- **Anexo 01** (`ANEXO_01_Fichas_Historias_de_Usuario.docx`): las 13 fichas alineadas con la app.
- **Sin repositorio Git** (se resolvió en la sección 7).

## 7. Actualización del 19/11/2026 (noche)

- **Recuperación de contraseña** con código enviado al correo (pantalla nueva, 3 pasos). Falta un paso en el panel de Supabase: pegar `supabase/plantillas/recuperar_contrasena.html` en *Authentication → Emails → Templates → Reset password* y comprobar que *Email OTP Length* sea 6. Probado contra el servidor: un código falso responde `otp_expired` y la app lo traduce; el correo inexistente no revela si la cuenta existe.
- **Evidencias y equipo**: el Admin/Supervisor puede eliminar una evidencia (si era la única, el hito vuelve a Pendiente) y quitar personal de una obra. El catálogo tiene interruptor Activo/Inactivo por ítem.
- **Catálogo Cat 6A / Cat 5e**: `supabase/datos/20261119_catalogo_cat6a_cat5e.sql` usa precios de tiendas peruanas del 19/11/2026 (sin IGV). Los dos patch panels Cat 6A van inactivos porque no se halló precio Cat 6A en soles.
- **Pruebas**: 36 (motor 14, validadores 12, insumos por categoría 9, arranque 1); cobertura de `validators.dart` 58,8 % (60/102); 33 archivos Dart y 13 190 líneas. `flutter analyze`: 0 errores y 0 advertencias.
- **Informe v12** (`INFORME_PRACTICAS_v12_revisado.docx`): sin dedicatoria; cambios en **verde**. Se quitó la cursiva de las Tablas 2 y 29 (eran las únicas de las 47 en cursiva y ya lo estaban en la v9), y los pies de las Figuras 17 y 18 recuperaron el formato rótulo en negrita + descripción en cursiva.
- **Anexos**: ver `ANEXOS_GUIA.md` (01, 02, 03 y 06 generados).
- **Git**: repositorio local en `main` con la etiqueta `v1.0.0`. Falta crear el repositorio remoto en GitHub y hacer `git push` (ver instrucciones en la respuesta).
