# Guía práctica de validación: informe ↔ app y QA (19/11/2026)

Sirve para una sola pasada por la app, con el celular en la mano: cada paso dice qué hacer, qué debe pasar y qué captura del informe sale de ahí. No es documentación nueva; solo hay que anotar lo que falle (sección 6).

**Antes de empezar**
- Instala el APK recompilado hoy: `build/app/outputs/flutter-apk/app-release.apk` (incluye la corrección de redondeo de jacks y bobinas; ver 6).
- Cuentas: un Admin, un Supervisor, un Técnico activos y un Técnico desactivado. Si el Técnico no está asignado a ninguna obra, asígnalo en la obra de prueba.
- Capturas: en vertical, mismo celular (ABR-NX3, Android 16), PNG. Usa DNI, teléfonos y RUC **ficticios** (Ley 29733); el informe los menciona como dato protegido.
- Catálogo: el SQL ya está ejecutado. Quedan activos el jack, los patch cords Cat 6A y el cable Cat 5e; los dos patch panels Cat 6A siguen inactivos (sin precio real).

## 1. Recorrido con capturas

Marca ✔ cuando coincida. Si no coincide, anótalo en la sección 6.

### A. Sin sesión (HU-01)
| Paso | Debe ocurrir | Captura |
|---|---|---|
| Abrir la app | Pantalla de bienvenida | Fig. 35 |
| "Iniciar Sesión" | Login con correo, contraseña y el enlace "¿Olvidaste tu contraseña?" | **Fig. 36 (recapturar)** |
| Contraseña mala | "Credenciales no válidas" y se borra la contraseña | |
| Recuperar: correo → "Enviar código" | Llega el código por correo; paso 2 con contador "Reenviar en 60s" | Anexo 02 (opcional) |
| Código falso | "El código es incorrecto o ya venció. Solicita uno nuevo." | |
| Código bueno + contraseña nueva | Vuelve al login con el correo cargado; entra con la contraseña nueva | |
| En el paso 3 pulsar atrás | Vuelve al login y no queda sesión abierta | |
| Correo inexistente | Mismo mensaje que uno existente (no revela cuentas) | |

### B. Admin (HU-02)
| Paso | Debe ocurrir | Captura |
|---|---|---|
| Entrar como Admin | Módulos: Dashboard, Operaciones, Clientes, Usuarios | Fig. 37 |
| Usuarios | Lista con "+" y lápiz | Fig. 39 |
| "+" | Formulario: nombres, DNI, teléfono, correo, contraseña (mín. 6), código, rol, cargo | Fig. 40 |
| Repetir un DNI existente | "Ya existe un usuario registrado con el DNI…" (no "database error") | |
| Desactivar al Técnico | Ese Técnico ya no entra: "Tu usuario está desactivado." | |

### C. Supervisor (HU-03, 04, 13)
Cotizador Paramétrico, con estos casos. Se calculan solos; **comprueba las cifras del BOM**:

| Caso | Entradas | Esperado |
|---|---|---|
| 1 | 24 puntos, 45 m, sin IDF, switch "24 Puertos PoE" | 1 188 m · 4 bobinas · 27 jacks · 48 patch cords · 1 panel de 24 · 1 organizador · 1 switch |
| 2 | 50 puntos, 30 m, sin IDF | 1 650 m · 6 bobinas · **55 jacks** · 100 patch cords · 1 panel de 48 + 1 de 24 · 2 organizadores · 3 switches |
| 3 | 60 puntos, distancia total 120 m, IDF activado, troncal 40 m | tramo IDF→puntos 80 m · 5 324 m · 18 bobinas · 66 jacks · 120 patch cords · 1 panel de 48 + 1 de 24 · 3 switches |
| 4 | 95 m sin IDF | No deja continuar: "Supera 90 m: incluye un gabinete intermedio (IDF) o reduce la distancia" y aparece la alerta de exceso |
| 5 | IDF con troncal 95 m | El campo lo rechaza (máximo 90 m); el tramo IDF→puntos debe quedar entre 10 y 90 m |

Total del BOM = (materiales + mano de obra) × 1,05 de imprevistos × 1,30 de margen × 1,18 de IGV (con los valores por defecto de los deslizadores).

| Paso | Debe ocurrir | Captura |
|---|---|---|
| Pasos del cotizador | Cable Cat 5e / Cat 6 / Cat 6A, sin fibra OM3; IDF y troncal | **Fig. 41 (recapturar)** |
| Distancia > 90 m | Mensaje de exceso y opción de IDF | **Fig. 42 (recapturar)** |
| BOM con Cat 6A y con Cat 5e | Cable, jacks y patch cords de la misma categoría; panel Cat 6A sin precio de catálogo (referencial) mientras esté inactivo | **Fig. 43 (recapturar)** |
| Ícono PDF antes de guardar | Sale como PROFORMA, sin correlativo, con "Norma: ANSI/TIA-568.1-E y 568.2-E" | **Fig. 44 (recapturar)** |
| Abrir el BOM dos veces sin guardar y luego "Aprobar Cotización y Crear Proyecto" | El correlativo COT-2026-NNN es el siguiente al último; no hay huecos | |
| Aprobar | Se crea la obra con 4 hitos y materiales presupuestados | |
| Clientes | Búsqueda por RUC/nombre; RUC inválido se rechaza | Fig. 45 |
| Catálogo | Interruptor Activo/Inactivo y lápiz por ítem; activar un ítem inactivo lo hace aparecer en el cotizador | **Fig. 46 (recapturar)** |
| Gestión de Obras | Lista con filtros (Pendiente, En Proceso, …); abrir la obra | Fig. 47 |
| Pestaña Equipo | Asignar un Técnico (Líder o Técnico), cambiar rol, quitar con el ícono rojo | **Fig. 48 (recapturar)** |
| Usuarios | Solo lectura: sin "+" y al tocar un usuario no se abre la edición | |

### D. Técnico (HU-05, 06, 07, 08, 09, 10)
| Paso | Debe ocurrir | Captura |
|---|---|---|
| Entrar como Técnico | Módulos: solo Operaciones. Sin Cotizador, Dashboard, Clientes ni Usuarios | Fig. 38 |
| Mis Obras Asignadas | Solo las suyas | |
| Catálogo | Solo lectura: sin "+", lápiz ni interruptor (ver duda 2 de la sección 5) | |
| Detalle de la obra | Sin "Añadir Personal", sin ⋮, sin papelera ni quitar personal | |
| Hito → "Registrar Evidencia (Foto, GPS y QR)" | GPS con precisión en metros; escáner QR con linterna e "Ingreso manual por teclado" | Fig. 49 |
| QR de un SKU del catálogo | "Reconocido en catálogo: SKU · descripción" | **Fig. 49 (recapturar)** |
| Foto | Peso original, comprimido y ahorro en % (≈ 90 %; nunca "0,9 %") | **Fig. 50 (recapturar)** |
| Modo avión, guardar 2 evidencias | Mensaje "Guardado offline en el dispositivo…" y chip "2 pendientes" arriba | Fig. 51 |
| Quitar modo avión | Chip "Sincronizando…" (o tocarlo para forzar) y luego desaparece; en Supabase 2 filas, sin duplicados. Una evidencia guardada con señal muestra "Evidencia y foto sincronizadas correctamente con el servidor" | Figs. 52 y 53 |
| "Completar sin evidencia" | Exige motivo de 10 o más caracteres | |
| Con los 4 hitos completos: "Generar Acta y Firmar" | Datos del firmante, firma sin desbordes, "Limpiar Trazo" y "Guardar Firma" | **Fig. 54 (recapturar)** |
| "Generar Acta As-Built y Cerrar Proyecto" | PDF con equipo, hitos, fotos y firma; la obra queda Completada | **Fig. 55 (recapturar)** |
| Obra Completada | Aviso "No se pueden modificar los hitos"; botón "Ver Acta As-Built PDF" | |

Como Supervisor o Admin, en un hito completado: lista de evidencias con papelera; al borrar la única, el hito vuelve a Pendiente. En obra Completada o Cancelada no aparece.

### E. Dashboard y tiempos (HU-11, RNF-01)
| Paso | Debe ocurrir | Captura |
|---|---|---|
| Dashboard (Supervisor o Admin) | Obras activas, estimaciones, actas cerradas, pendientes de firma; filtros por estado, fechas y texto; tiempo de carga en pantalla (~1,5 s) | **Fig. 56 (recapturar)** |
| Filtro "Pendiente" | Muestra las obras en ese estado (antes "Planificación" no mostraba nada) | |

Las mediciones de la Tabla 35 (20 evidencias sin conexión, 10 fotos, 10 lecturas QR, dashboard 5 veces) ya están hechas; solo repítelas si cambia el celular o la versión de Android.

## 2. Capturas del Anexo 02 (manual)
Sale de lo anterior: inicio de sesión (Fig. 36), Panel de Operaciones y Módulos, pasos del cotizador con la alerta de 90 m (Figs. 41–42), Presupuesto y BOM (Fig. 43), detalle de obra (Fig. 48), formulario de evidencia y escáner QR (Figs. 49–50), firma y acta (Figs. 54–55) y dashboard (Fig. 56). Opcional: las tres pantallas de recuperación de contraseña.
Anexo 05: guarda el PDF de la cotización aprobada y el del acta cerrada de la obra de prueba.

## 3. Informe ↔ app: qué revisar mientras lees
| Dónde | Qué comprobar |
|---|---|
| Resumen y 3.1.7 (Sprints 1 a 6) | Que las funciones listadas existan en la app (recorrido A–E); la recuperación de contraseña, el borrado de evidencias y el quitar personal figuran en el Sprint 6 |
| Roles (Tabla de permisos) | Técnico, Supervisor y Admin se comportan como en los recorridos B, C y D |
| Reglas del motor (3.1.7.2 y Tabla 31) | Los casos 1 a 5 de la sección C |
| Figura 34 (mapa de navegación) | Módulos por rol como en B, C y D; sin nodo "Anexo" |
| Fichas HU-03, 07, 09 y 13 y Anexo 01 | Los botones y mensajes citados existen. Cruce automático hecho hoy: 45 de 51 textos entre comillas están en el código; los 6 restantes son abreviaturas o mensajes del servidor, salvo el de abajo |
| Tablas 31 a 36 | Cifras con los comandos de la sección 4 |

El cruce automático dejó un texto por decidir: HU-07 y el informe dicen que el registro local queda como "Pendiente de Sincronización"; en la app el estado se llama "Pendiente" y la pantalla muestra "N pendientes". Conviene escribir "Pendiente".

## 4. Cifras del informe: cómo recomprobarlas
Desde `D:\Michel-Proyect\ejarad_app`:

```bash
flutter test --coverage
```
Debe decir 36 pruebas aprobadas (Tabla 31). El motor TIA-568 tiene 33/33 líneas.

```bash
flutter analyze
```
Debe decir 22 sugerencias, 0 errores (Tabla 32).

En el SQL Editor de Supabase:

```sql
select count(*) as tablas_con_rls from pg_tables where schemaname = 'public' and rowsecurity;
select tablename from pg_tables where schemaname = 'public' and not rowsecurity;
select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.prosecdef order by 1;
select id, public from storage.buckets;
```
Esperado: 15 tablas con RLS (el informe dice 15), ninguna sin RLS, las funciones de seguridad (el informe dice 6), y dos buckets: `evidencias-hitos` (público) y `actas` (privado). Si una cifra no coincide, se corrige el número en el informe, no la base de datos.

## 5. Dudas para resolver al revisar
1. **Sesión tras cerrar la app en el paso 3 de la recuperación:** si se cierra la app a la fuerza después de validar el código y antes de guardar la contraseña, queda una sesión abierta (con el botón atrás sí se cierra). Quien lo hiciera ya tenía acceso al correo, así que no sube de privilegio; el informe no lo menciona.
2. **Precios del catálogo para el Técnico:** la política RLS le deja leer el catálogo y la pantalla muestra costo base y precio de venta. La revisión del Sprint 3 solo pidió ocultar precios y márgenes de las **cotizaciones**, y eso se cumple. Decide si el catálogo en solo lectura con precios es aceptable o se oculta.
3. **Paneles Cat 6A:** siguen inactivos; con cable Cat 6A el BOM mostrará el panel con un precio referencial hasta que actives uno con su precio real.

## 6. Registro de hallazgos
Copia una fila por cada cosa que no coincida. Los defectos nuevos van a la Tabla 36 del informe (D-18 ya está registrado; los nuevos empiezan en D-19).

| Dónde | Qué pasó | Severidad | ¿Se corrige antes del 27/11? |
|---|---|---|---|
| Ejemplo: Fig. 43 | El panel de 48 salió con precio 0 | Baja | Sí |

**Hallazgo de hoy, ya corregido y registrado como D-18 (informe, PPT y Anexo 03 ya dicen 18 defectos):** el cálculo de jacks y bobinas usaba decimales y fallaba en algunos conteos (50 puntos daban 56 jacks en vez de 55; 61 puntos × 50 m pedían 12 bobinas en vez de 11). Se cambió a aritmética exacta y se reforzaron dos pruebas existentes. Los defectos que encuentres en el recorrido empiezan en D-19.
