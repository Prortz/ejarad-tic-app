# Guía de anexos del informe (19/11/2026)

El índice del informe (tras "ANEXOS") lista 13 anexos en dos bloques. Esta tabla dice qué archivo es cada uno, en qué estado está y qué falta.

## A. Documentos y evidencias del sistema

| Anexo | Contenido | Archivo | Estado | Qué falta |
|---|---|---|---|---|
| 01 | Fichas de historias de usuario HU-01 a HU-13 | `ANEXO_01_Fichas_Historias_de_Usuario.docx` | Listo (15 páginas) | Nada. HU-01 incluye los escenarios de recuperación de contraseña |
| 02 | Manual de usuario | `ANEXO_02_Manual_de_Usuario.docx` | Listo salvo capturas (5 páginas) | Insertar 8 capturas donde dice "(Inserte aquí la captura…)": inicio de sesión, Panel de Operaciones y Módulos, pasos del cotizador y advertencia de 90 m, Presupuesto y BOM, detalle de obra, formulario de evidencia y escáner QR, firma y acta PDF, dashboard. Opcional: las tres pantallas de recuperación de contraseña |
| 03 | Acta de conformidad del producto | `ANEXO_03_Acta_de_Conformidad.docx` | Formato listo, **sin firmas** | Imprimir, completar DNI y fecha, hacer firmar al Product Owner (Ing. Arteaga) y escanear; reemplazar la página por el escaneo |
| 04 | Actas de reunión (Sprint Planning, seguimiento semanal, Sprint Review) | Carpeta de actas de reunión del practicante | Lo aporta el practicante | Escanear o exportar las actas firmadas y pegarlas en este orden: Sprint 1 a Sprint 6. Las fechas de cada reunión están en la tabla de eventos por Sprint del informe |
| 05 | Cotización y Acta As-Built generadas por la app | PDF generados por la app | Lo aporta el practicante | Generar una cotización aprobada y un acta cerrada de una obra de prueba, y adjuntar los dos PDF |
| 06 | Migraciones SQL y políticas RLS | `ANEXO_06_Migraciones_SQL_y_RLS.docx` | Listo (14 páginas) | Nada. Incluye las Fases 2 a 5 y la Edge Function `admin-users` |

## B. Documentación administrativa de la práctica

Los anexos 07 a 13 son documentos de la universidad y de la empresa (solicitud y carta de presentación, convenio y carta de aceptación, contrato, plan de prácticas aprobado, constancia y carta de conformidad). Son del practicante: se insertan escaneados, uno por anexo, con el título del índice del informe.

## Cómo armar el documento final

1. En Word, después de la sección "ANEXOS", pegar cada archivo con *Insertar → Objeto → Texto de archivo* en el orden 01, 02, 03, 04, 05, 06, 07 a 13.
2. Antes de cada anexo, un salto de página y el título exacto del índice ("ANEXO 03: …").
3. Actualizar la tabla de contenido (Referencias → Actualizar tabla) y las listas de tablas y figuras.
4. Quitar el resaltado de colores del informe (amarillo = v10, cian = v11, verde = v12).

Las capturas de pantalla (Anexo 02) y la cotización/acta (Anexo 05) deben salir de la versión final del APK (`build/app/outputs/flutter-apk/app-release.apk`).
