# EJARAD TIC · App móvil de estimación y trazabilidad

Aplicación Android (Flutter + Supabase) para **EJARAD TIC SOLUCIONES INFORMÁTICAS E.I.R.L.** (Castilla, Piura).
Estima y cotiza proyectos de cableado estructurado según **ANSI/TIA-568.1-E y 568.2-E**, controla la ejecución en
campo con evidencias georreferenciadas y cierra cada obra con un acta de conformidad As-Built firmada.

Proyecto de prácticas preprofesionales II (Ingeniería de Sistemas, UCV Piura). Metodología: PMI + Scrum, seis Sprints de dos semanas.

## Funciones

| Módulo | Qué hace |
|---|---|
| Acceso y roles | Inicio de sesión con Supabase Auth (JWT), roles Admin / Supervisor / Técnico, recuperación de contraseña con código enviado al correo |
| Cotizador ANSI/TIA-568 | Metrado con 10 % de reserva, bobinas de 305 m, jacks, patch panels y patch cords de la misma categoría que el cable (Cat 5e / 6 / 6A), switches, gabinete intermedio (IDF) y troncal ≤ 90 m |
| Obras e hitos | Hitos técnicos, equipo con rol Líder / Técnico, materiales As-Built con alerta de exceso |
| Trazabilidad | Foto comprimida, GPS con precisión, QR de equipos y registro sin conexión (SQLite) con sincronización sin duplicados |
| Acta As-Built | Firma del cliente, PDF y cierre de la obra |
| Catálogo, clientes, usuarios, dashboard | Gestión de precios por categoría, clientes, cuentas del personal e indicadores gerenciales |

## Puesta en marcha

```bash
flutter pub get
flutter run
```

La URL del proyecto y la llave **pública** (publishable/anon) de Supabase están en `lib/main.dart`. La seguridad
no depende de esa llave sino de las políticas RLS (ver `supabase/migrations`).

## Backend (Supabase)

1. Esquema base de tablas (Fase 1) y luego las migraciones de `supabase/migrations` en orden (Fases 2 a 5).
2. Edge Function de administración de usuarios: `supabase functions deploy admin-users`.
3. Recuperación de contraseña por código:
   - Habilitar un **SMTP propio** en *Authentication → Emails → SMTP Settings* (el servicio de correo integrado de Supabase
     solo sirve para pruebas y no entrega a usuarios finales). Las credenciales SMTP se guardan en Supabase, nunca en el repositorio.
   - Pegar `supabase/plantillas/recuperar_contrasena.html` en *Authentication → Emails → Templates → Reset password*
     (la plantilla usa `{{ .Token }}`). La app acepta códigos de 6 a 10 dígitos, así que no depende de la longitud configurada.
4. Datos opcionales del catálogo (Cat 6A y Cat 5e): `supabase/datos/20261119_catalogo_cat6a_cat5e.sql`.

## Calidad

```bash
flutter analyze
flutter test --coverage
```

36 pruebas unitarias (motor de estimación, validadores y elección de insumos por categoría); el motor
`tia568_calculator.dart` tiene 100 % de cobertura de líneas.

## APK de producción

```bash
flutter build apk --release
```

Sin `android/key.properties` el APK se firma con la llave de depuración. Para publicar, cree un keystore y
`android/key.properties` (ambos están excluidos del repositorio).

## Documentación

- `docs/informe/`: fichas de historias de usuario (Anexo 01), manual de usuario (Anexo 02), acta de conformidad (Anexo 03),
  migraciones SQL y RLS (Anexo 06) y guía de anexos.
- `docs/figuras/generar_figuras.py`: genera los gráficos de velocidad, burn-up, calidad y tiempos de respuesta.

Autor: Patricio Michael Ramos Ortiz (practicante).
