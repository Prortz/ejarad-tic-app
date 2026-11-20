# Prompts personalizados · Figuras 27 a 42

**Cómo usarlos:** pega primero tu **prompt maestro** ("IDENTIDAD VISUAL CORPORATIVA – EJARAD TIC S.I.E.I.R.L.", secciones 1 a 11) y debajo el bloque de la figura que vas a generar. Cada bloque indica la línea visual (A oscura / B clara), el encabezado, el contenido exacto y las reglas técnicas que la IA no debe cambiar.

Los nombres de tablas, archivos y funciones son los **reales de tu proyecto**; no los traduzcas ni los "embellezcas", porque tu asesor puede compararlos con el código.

| Figura | Cómo se obtiene |
|---|---|
| 27, 28, 30, 31, 32, 33, 34 | Prompt de IA (abajo) |
| 29 | Captura real de Supabase (instrucciones abajo) |
| 35 a 40 | Capturas reales de la app sobre una plantilla (prompt de plantilla abajo) |
| 41, 42 | Ya generadas con datos exactos: `FIG41_velocidad.png`, `FIG42_burnup.png` |

---

## FIGURA 27 · Modelo de datos de la empresa por áreas temáticas

```
TIPO DE DIAGRAMA: Modelo conceptual de datos empresarial por áreas temáticas.
LÍNEA VISUAL: B – Académica clara (fondo blanco / azul hielo #EAF5FA).
FORMATO: 16:9, 1920 × 1080 px.

ENCABEZADO:
- Título: "MODELO DE DATOS DE LA EMPRESA"
- Subtítulo (cian): "Áreas temáticas de información de EJARAD TIC y cobertura de la aplicación móvil"

CONTENIDO CENTRAL:
Seis contenedores grandes de esquinas redondeadas, distribuidos en 2 filas de 3. Cada contenedor tiene
un encabezado de color con ícono y, dentro, sus entidades como óvalos o píldoras blancas:

1. CLIENTES (ícono edificio) — encabezado azul corporativo #003B70
   Entidades: Cliente (RUC) · Sede / Dirección · Contacto
2. COMERCIAL (ícono calculadora) — encabezado turquesa #00A99D
   Entidades: Catálogo de precios · Cotización · Detalle de materiales (BOM) · Correlativo
3. OPERACIONES DE OBRA (ícono casco / red) — encabezado turquesa #00A99D
   Entidades: Proyecto · Equipo · Hito · Evidencia · Materiales · Anexo
4. DOCUMENTACIÓN DE CIERRE (ícono documento con firma) — encabezado verde #16B978
   Entidades: Acta de conformidad · Firma · PDF
5. PERSONAL (ícono usuarios) — encabezado violeta #8055E8
   Entidades: Usuario · Perfil · Rol · Especialidad
6. CONTABILIDAD Y LOGÍSTICA (ícono factura / almacén) — encabezado gris acero #64748B, contenedor en gris claro
   Entidades: Comprobante electrónico (SUNAT) · Kardex · Guía de remisión

RELACIONES ENTRE ÁREAS (líneas azules con etiqueta):
- Clientes → Comercial: "solicita cotización"
- Comercial → Operaciones de obra: "cotización aprobada origina proyecto"
- Operaciones de obra → Documentación de cierre: "obra concluida genera acta"
- Personal → Operaciones de obra: "integra equipo / registra evidencias"
- Documentación de cierre → Contabilidad y logística: línea GRIS DISCONTINUA "PDF para facturación (fuera del sistema)"

ELEMENTO CLAVE:
Un marco de línea discontinua cian que encierra las áreas 1 a 5 con la etiqueta
"Base de datos centralizada – Supabase / PostgreSQL (App EJARAD TIC)".
El área 5 (Personal) lleva una pequeña insignia "Cobertura parcial".
El área 6 queda FUERA del marco, en gris, con la insignia "Fuera de alcance".

PIE DE PÁGINA (franja azul marino):
Leyenda: marco cian = cubierto por la app · gris = fuera de alcance · línea discontinua = intercambio externo.

RESTRICCIONES: no agregar áreas ni entidades nuevas; no conectar Contabilidad con línea continua.
```

---

## FIGURA 28 · Modelo entidad-relación del sistema

> Es el diagrama más denso. Genera en **4:3 (1600 × 1200)** o divídelo en dos figuras (28a comercial, 28b obra y cierre) si el texto sale pequeño. Revisa letra por letra los nombres de columnas al terminar: las IA suelen alterarlos.

```
TIPO DE DIAGRAMA: Modelo entidad-relación (notación pata de gallo / crow's foot).
LÍNEA VISUAL: B – Académica clara.
FORMATO: 4:3, 1600 × 1200 px (o 16:9 si cabe con texto legible).

ENCABEZADO:
- Título: "MODELO ENTIDAD-RELACIÓN"
- Subtítulo: "Base de datos del sistema móvil de estimación y trazabilidad – Supabase / PostgreSQL 17"

ENTIDADES (tarjeta con encabezado de color y lista de atributos; marcar PK con llave dorada,
FK con llave azul, UK con insignia "UK"). Usar EXACTAMENTE estos nombres:

Grupo CLIENTES Y PERSONAL (encabezados azul corporativo #003B70):
- perfiles: PK id · UK user_id (FK → auth.users) · UK numero_documento · nombre · apellido · rol · activo
- clientes: PK id · UK ruc_cliente · razon_social · contacto_nombre · telefono
- direcciones_clientes: PK id · FK cliente_id · provincia · distrito · direccion_especifica · es_principal

Grupo COMERCIAL (encabezados turquesa #00A99D):
- catalogo_precios: PK id · UK sku · categoria · descripcion · unidad_medida · costo_base · precio_venta_default · activo
- cotizaciones: PK id · UK codigo_cotizacion · FK cliente_id · FK direccion_id · FK creado_por · puntos_totales · distancia_promedio (10–90 m) · metrado_cable_total · precio_total · estado
- cotizacion_detalles: PK id · FK cotizacion_id · FK catalogo_id · descripcion · cantidad · precio_unitario · subtotal
- correlativos: PK clave · ultimo   (tabla aislada, sin relaciones; nota: "solo vía función RPC")

Grupo OBRA (encabezados cian #00D5E8 con texto azul marino):
- proyectos: PK id · UK codigo_proyecto · FK cotizacion_id · FK cliente_id · FK direccion_id · FK lider_id · nombre_obra · estado · fecha_inicio · fecha_cierre_estimada
- proyecto_equipo: PK id · FK proyecto_id · FK perfil_id · rol_en_proyecto
- proyecto_materiales: PK id · FK proyecto_id · item_descripcion · cantidad_presupuestada · cantidad_instalada
- hitos_proyecto: PK id · FK proyecto_id · FK completado_por · fase · orden · completado
- evidencias_proyecto: PK id · FK hito_id · FK registrado_por · foto_url · latitud · longitud · precision_m · numero_serie · ubicacion (geography)
- anexos_proyecto: PK id · FK proyecto_id · numero_anexo · monto_total · estado
- anexo_detalles: PK id · FK anexo_id · FK catalogo_id · cantidad · subtotal

Grupo CIERRE (encabezado verde #16B978):
- actas_conformidad: PK id · UK codigo_acta · UK FK proyecto_id · FK cliente_id · FK generado_por · firmante_nombre · pdf_path · fecha_cierre

RELACIONES (pata de gallo; NO cambiar cardinalidades):
- clientes 1 ── N direcciones_clientes
- clientes 1 ── N cotizaciones
- direcciones_clientes 1 ── N cotizaciones
- cotizaciones 1 ── N cotizacion_detalles
- catalogo_precios 1 ── 0..N cotizacion_detalles
- catalogo_precios 1 ── 0..N anexo_detalles
- cotizaciones 1 ── 0..N proyectos
- clientes 1 ── N proyectos
- proyectos 1 ── N proyecto_equipo ;  perfiles 1 ── N proyecto_equipo
- proyectos 1 ── N proyecto_materiales
- proyectos 1 ── N hitos_proyecto
- hitos_proyecto 1 ── 0..N evidencias_proyecto
- proyectos 1 ── 0..N anexos_proyecto ;  anexos_proyecto 1 ── N anexo_detalles
- proyectos 1 ── 0..1 actas_conformidad
- perfiles 1 ── 0..N cotizaciones (creado_por), proyectos (lider_id), hitos_proyecto (completado_por),
  evidencias_proyecto (registrado_por), actas_conformidad (generado_por)
  → dibujar estas 5 relaciones de perfiles con líneas GRIS más finas para no saturar.

DISPOSICIÓN: flujo de izquierda a derecha Clientes → Comercial → Obra → Cierre;
perfiles arriba al centro; correlativos abajo a la izquierda, aislada.

PIE (franja azul marino): Leyenda PK · FK · UK · "1 ── N = uno a muchos" · "0..1 = opcional".

RESTRICCIONES: no inventar columnas ni tablas; no incluir actas_entrega (tabla heredada).
```

---

## FIGURA 29 · Modelo físico de la base de datos en Supabase (captura real)

No uses IA. En Supabase: **Database → Schema Visualizer → esquema `public`** → acomoda las tablas en el mismo orden que la Figura 28 (Clientes → Comercial → Obra → Cierre) → "Auto layout" si queda desordenado → captura con `Win + Shift + S`.

Para que combine con tu estilo, pega la captura dentro de este marco (en PowerPoint o Canva, 1920 × 1080):

```
Plantilla de marco: franja superior azul marino #061B38 con logotipo EJARAD TIC a la izquierda,
título "MODELO FÍSICO DE BASE DE DATOS" y subtítulo cian "Esquema public · PostgreSQL 17.6 · Supabase";
área central blanca con borde cian de 3 px y esquinas redondeadas donde va la captura;
franja inferior con la leyenda "UUID gen_random_uuid() · CHECK · UNIQUE · geography(Point,4326) · RLS activo".
```

---

## FIGURA 30 · Flujo de autorización JWT y evaluación de políticas RLS

```
TIPO DE DIAGRAMA: Diagrama de secuencia UML.
LÍNEA VISUAL: B – Académica clara.
FORMATO: 16:9, 1920 × 1080 px.

ENCABEZADO:
- Título: "FLUJO DE AUTORIZACIÓN JWT + RLS"
- Subtítulo: "Cómo Supabase decide qué filas ve cada usuario de la app EJARAD TIC"

PARTICIPANTES (cajas arriba con ícono y línea de vida discontinua hacia abajo):
1. Usuario (Técnico de campo) — ícono persona con casco
2. App móvil Flutter — ícono smartphone
3. Supabase Auth (GoTrue) — ícono escudo con llave
4. PostgREST API — ícono engranaje / API
5. PostgreSQL + RLS — ícono base de datos con candado

MENSAJES NUMERADOS (círculos turquesa con el número):
1. Usuario → App: "Ingresa correo y contraseña"
2. App → Supabase Auth: "signInWithPassword()" (flecha azul)
3. Supabase Auth → App: "Token JWT (auth.uid())" (flecha turquesa de retorno, discontinua)
4. App → PostgREST: "GET /rest/v1/proyectos + Authorization: Bearer JWT" (flecha azul)
5. PostgREST → PostgreSQL: "SELECT * FROM proyectos" (flecha azul)
6. Dentro de PostgreSQL, una caja de evaluación (fondo azul hielo, borde naranja):
   "Política proyectos_select → puede_ver_proyecto(id)"
   con dos ramas tipo compuerta:
   - "is_gestor() → Admin / Supervisor: todas las filas"
   - "es_miembro_proyecto(id) → Técnico: solo obras asignadas"
7. PostgreSQL → PostgREST: "Solo filas autorizadas" (flecha turquesa)
8. PostgREST → App: "JSON con proyectos permitidos" (flecha turquesa)
9. App → Usuario: "Lista de mis obras"

NOTA DESTACADA (tarjeta con borde verde e ícono de escudo):
"Un técnico no asignado recibe 0 filas, no un error. La seguridad vive en la base de datos, no solo en la interfaz."

TARJETA LATERAL DERECHA "Funciones de seguridad" (fondo blanco, borde azul):
mi_perfil_id() · is_admin() · is_gestor() · es_miembro_proyecto() · puede_ver_proyecto() · proyecto_de_hito()
y una línea pequeña: "SECURITY DEFINER – evitan recursión de RLS".

PIE (franja azul marino): "Ley N° 29733 · Privilegio mínimo · HTTPS/TLS · JWT".

RESTRICCIONES: respetar el orden 1→9; los retornos van en línea discontinua; no mostrar llaves secretas.
```

---

## FIGURA 31 · Secuencia de registro offline y sincronización store-and-forward

```
TIPO DE DIAGRAMA: Diagrama de secuencia UML con fragmentos alt.
LÍNEA VISUAL: B – Académica clara.
FORMATO: 16:9, 1920 × 1080 px.

ENCABEZADO:
- Título: "REGISTRO OFFLINE-FIRST Y SINCRONIZACIÓN"
- Subtítulo: "Patrón store-and-forward de evidencias de campo – SQLite → Supabase"

PARTICIPANTES (izquierda a derecha, con ícono):
Técnico · EvidenciaForm · ImageService · LocationService · LocalDb (SQLite) · SyncService · Supabase Storage · PostgreSQL

MENSAJES:
1. Técnico → EvidenciaForm: "Toma foto + comentario + serie QR"
2. EvidenciaForm → ImageService: "comprimir()" ; retorno: "Foto ≥ 70 % más liviana"
3. EvidenciaForm → LocationService: "capturar()" ; retorno: "latitud, longitud, precisión (m)"
4. EvidenciaForm → LocalDb: "insertar evidencia · UUID v4 · estado = Pendiente"

FRAGMENTO alt (recuadro con etiqueta en la esquina, borde naranja):
  [Sin señal]  (sección superior, fondo gris muy claro)
    5a. LocalDb → EvidenciaForm: "Guardado local"
    5b. EvidenciaForm → Técnico: "Chip: 1 evidencia pendiente" (ícono nube tachada)
  [Señal recuperada o cada 90 s]  (sección inferior, fondo azul hielo)
    6. SyncService → LocalDb: "leer pendientes"
    7. SyncService → Supabase Storage: "subir foto" ; retorno: "URL"
    8. SyncService → PostgreSQL: "UPSERT por UUID (sin duplicados)"
    9. SyncService → LocalDb: "estado = Sincronizado · borrar foto local"
    10. SyncService → Técnico: "Chip: sincronizado" (ícono nube con check verde)

NOTAS (tarjetas pequeñas a la derecha):
- "UUID generado en el dispositivo = 0 duplicados"
- "Si falla la red, la cola se conserva para el siguiente intento"
- "Se respeta la hora real de captura (capturado_en)"

PIE: "connectivity_plus · sqflite · flutter_image_compress · geolocator · Supabase Storage".

RESTRICCIONES: mantener el orden; la subida de la foto (7) va ANTES del UPSERT (8).
```

---

## FIGURA 32 · Stack tecnológico de la solución

```
TIPO DE DIAGRAMA: Diagrama de stack tecnológico por capas.
LÍNEA VISUAL: A – Tecnológica oscura (fondo azul marino #061B38 con circuitos discretos).
FORMATO: 16:9, 1920 × 1080 px.

ENCABEZADO:
- Título: "STACK TECNOLÓGICO DE LA SOLUCIÓN"
- Subtítulo: "Flutter + Supabase · Aplicación móvil de estimación y trazabilidad"
- Frase derecha: "Tecnologías y versiones del proyecto"

CAPAS APILADAS (de arriba hacia abajo, paneles anchos con encabezado de color y logos/íconos):
1. DISPOSITIVO – Smartphone Android 8.0+ con GPS y cámara (ícono smartphone isométrico)
2. APLICACIÓN FLUTTER (Dart ^3.13 · Material Design 3) — tres sub-bloques en fila:
   Presentación (screens / widgets) · Dominio (TIA568Calculator · Validators) · Datos (services)
3. PLUGINS NATIVOS — fila de chips con nombre y versión:
   geolocator 14.0 · mobile_scanner 7.4 · image_picker 1.1 · flutter_image_compress 2.3 ·
   signature 5.5 · pdf 3.11 · printing 5.13 · sqflite 2.4 · connectivity_plus 7.3 · uuid 4.6
4. COMUNICACIÓN — banda delgada cian: "HTTPS / TLS · supabase_flutter 2.8 · JWT"
5. SUPABASE (BaaS) — cuatro tarjetas: Auth (GoTrue · JWT) · PostgREST (API REST) ·
   Storage (buckets evidencias-hitos y actas) · Edge Functions (Deno · admin-users)
6. DATOS — PostgreSQL 17.6 · PostGIS · PL/pgSQL · Row Level Security

BARRA VERTICAL IZQUIERDA "HERRAMIENTAS DE DESARROLLO":
Antigravity IDE · Flutter SDK · Android SDK · flutter_lints · flutter_test · Git

CONEXIONES: flechas cian verticales entre capas (de arriba hacia abajo).

PIE (franja): "SEGURIDAD · ESCALABILIDAD · TRAZABILIDAD · EFICIENCIA".

RESTRICCIONES: no agregar BLoC, Provider, Firebase ni PostgreSQL 15; escribir las versiones tal como están.
```

---

## FIGURA 33 · Infraestructura tecnológica de EJARAD TIC con la solución móvil

```
TIPO DE DIAGRAMA: Diagrama de infraestructura y red.
LÍNEA VISUAL: A – Tecnológica oscura, con ilustraciones isométricas sutiles de hardware.
FORMATO: 16:9, 1920 × 1080 px.

ENCABEZADO:
- Título: "INFRAESTRUCTURA TECNOLÓGICA"
- Subtítulo: "EJARAD TIC S.I.E.I.R.L. · Oficina, campo y nube"

TRES ZONAS (contenedores grandes con borde cian y etiqueta superior):

ZONA 1 – "OFICINA EJARAD TIC · Urb. Monteverde, Castilla – Piura" (izquierda):
- PC de gerencia (Windows · navegador · consola Supabase)
- Laptop de desarrollo (Windows 11 · Antigravity IDE · Android SDK) con un cable USB hacia un celular de pruebas
- Impresora multifuncional
- Router Wi-Fi del proveedor de Internet

ZONA 2 – "CAMPO · Obras en Piura y Castilla" (centro-abajo):
- 3 smartphones Android con íconos de GPS y cámara
- Una antena 4G/LTE
- Uno de los celulares con ícono "sin señal" y la etiqueta "Cola local SQLite (offline)"
- Satélites GPS en la parte superior de la zona, con líneas punteadas hacia los celulares

ZONA 3 – "NUBE · Supabase sobre AWS us-east-1 (Virginia, EE. UU.)" (derecha):
- Auth (JWT) · PostgreSQL 17 + PostGIS · Storage · Edge Functions

CONEXIONES:
- Router de oficina → Internet → Supabase: flecha cian "HTTPS / TLS"
- Antena 4G → Internet → Supabase: flecha cian "HTTPS / TLS"
- Celular sin señal → (línea gris discontinua) → "sincroniza al recuperar señal"
- Una nube central "Internet" entre las zonas

INDICADOR (tarjeta pequeña junto a la flecha hacia la nube):
"Latencia medida: ≈ 0,33 s por solicitud"

PIE: "Sin servidores propios · Backend como servicio · Datos centralizados".

RESTRICCIONES: no inventar marcas ni modelos de equipos; no mostrar personas reales.
```

---

## FIGURA 34 · Mapa de navegación de la aplicación por rol

```
TIPO DE DIAGRAMA: Mapa de navegación de pantallas (flujo de pantallas).
LÍNEA VISUAL: B – Académica clara.
FORMATO: 16:9, 1920 × 1080 px.

ENCABEZADO:
- Título: "MAPA DE NAVEGACIÓN DE LA APLICACIÓN"
- Subtítulo: "Pantallas y acceso según rol: Admin (A) · Supervisor (S) · Técnico (T)"

NODOS (tarjetas con forma de mini pantalla de celular, nombre y chips de rol):
Nivel 1: "Bienvenida / Inicio de sesión" [A S T]
Nivel 2: "Inicio" [A S T] → "Módulos" [A S T]
Nivel 3: cuatro tarjetas del menú Módulos (tal como aparecen en la app):
  "Dashboard" [A S] · "Operaciones" [A S T] · "Clientes" [A S] · "Usuarios" [A S]
Nivel 4 (ramas), agrupadas por color de módulo:
- Desde Operaciones, M1 Estimación (turquesa): "Cotizador" [A S] → "Vista previa BOM" [A S] → (botón "Aprobar") → "Detalle de proyecto" ;
  "Catálogo de precios" [A S]
- Desde Operaciones, M2 Obra (cian): "Proyectos" [A S T] (para el Técnico: "Mis obras") → "Detalle de proyecto" [A S T]
  con pestañas Hitos · Equipo · Materiales · Acta
    · desde Detalle → "Evidencia" [A S T] → "Escáner QR" [A S T]
- M3 Cierre (verde): desde Detalle → "Firma del acta" [A S T] → "Vista previa del acta" [A S T]
- Desde Clientes (turquesa claro): "Lista de clientes" [A S] → "Detalle de cliente" [A S]
- Desde Usuarios, M0 Seguridad (azul): "Lista de usuarios" [A S] → "Formulario de usuario" [A] (crear y editar solo Admin)
- Dashboard (violeta): indicadores, filtro por fechas [A S]

CONEXIONES: flechas azules con dirección; la flecha "Aprobar" de Vista previa BOM a Detalle de proyecto en naranja.

LEYENDA (pie): chips A = Admin (azul) · S = Supervisor (turquesa) · T = Técnico (verde) · colores por módulo M0–M3.

RESTRICCIONES: no agregar pantallas; el Técnico NO accede a Cotizador, Clientes, Catálogo, Usuarios ni Dashboard.
```

> Los roles salen de `modulos_screen.dart`: Dashboard, Clientes y Usuarios solo aparecen si `puedeGestionar` (Admin o Supervisor), y la Edge Function que crea o edita usuarios solo acepta al Admin.

---

## FIGURAS 35 a 40 · Pantallas de los incrementos (capturas reales)

No generes las pantallas con IA: inventaría la interfaz y tu asesor lo notaría. Toma capturas reales en tu celular (con datos de prueba, sin DNI ni teléfonos reales) y colócalas sobre esta plantilla. Genera la plantilla **una sola vez** y reutilízala en las seis figuras:

```
TIPO: Plantilla de presentación de pantallas móviles (sin contenido dentro de los celulares).
LÍNEA VISUAL: A – Tecnológica oscura.
FORMATO: 16:9, 1920 × 1080 px.

ENCABEZADO: logotipo EJARAD TIC a la izquierda; título "INCREMENTO DEL SPRINT [N]";
subtítulo cian "[Sprint Goal]"; a la derecha una píldora turquesa "HU-xx · HU-yy".

CENTRO: cuatro marcos de smartphone Android modernos, alineados en fila y equidistantes,
con la pantalla completamente VACÍA en color blanco liso (para pegar capturas encima).
Debajo de cada celular, una etiqueta en tarjeta azul hielo con texto de ejemplo "Nombre de pantalla".

PIE: franja azul marino con "Sprint [N] · [fechas] · Review: [fecha]".

RESTRICCIONES: no dibujar interfaces, textos ni íconos dentro de las pantallas de los celulares.
```

Contenido de cada figura (para reemplazar los textos de la plantilla):

| Fig. | Sprint · fechas · Review | HU | Capturas sugeridas |
|---|---|---|---|
| 35 | S1 · 07/09–18/09 · 18/09 | HU-01, HU-02 | Bienvenida/login · Inicio con menú por rol · Lista de usuarios · Formulario de usuario |
| 36 | S2 · 21/09–02/10 · 02/10 | HU-03, HU-04 | Cotizador (pasos) · Alerta de exceso de 90 m · Vista previa BOM · PDF de cotización |
| 37 | S3 · 05/10–16/10 · 16/10 | HU-13, HU-05, HU-06 | Lista de proyectos · Detalle con hitos y equipo · Captura GPS · Escáner QR con linterna |
| 38 | S4 · 19/10–30/10 · 30/10 | HU-07, HU-08 | Formulario de evidencia con % de ahorro · Chip de pendientes (modo avión) · Chip sincronizado |
| 39 | S5 · 02/11–13/11 · 13/11 | HU-09, HU-10 | Firma del acta · Vista previa del acta PDF · Acta descargable en el detalle |
| 40 | S6 · 16/11–27/11 · 27/11 | HU-11, HU-12 | Dashboard con indicadores · Filtro por fechas · App instalada desde el APK release |

---

## FIGURAS 41 y 42 · Gráficos de velocidad y burn-up

Ya están generados con los datos exactos del capítulo (las IA de imágenes suelen dibujar barras con valores equivocados):

- `FIG41_velocidad.png` – SP planificados vs. terminados por Sprint (5, 13, 15, 11, 8, 8) y velocidad promedio de 10 SP.
- `FIG42_burnup.png` – Alcance total 55 → 60 SP (HU-13 agregada en S2) y SP acumulados 5, 18, 33, 44, 52, 60.
