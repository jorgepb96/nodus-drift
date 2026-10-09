# Investigación de las grabaciones de Drift — 9 de octubre de 2026

> Historical bank: this report concerns the original Moodist MP3s in builds 1–5. All 81 were subsequently replaced. See [the current replacement report](AUDIO_REPLACEMENT_2026-10-09.md); original findings remain preserved below.

**Resultado: cinco de las 81 grabaciones están vinculadas a originales publicados
con CC0. Las otras 76 conservan la declaración general de licencia de Moodist,
pero todavía no tienen una fuente individual comprobada.** No se ha encontrado
una infracción concreta; la investigación no permite confirmar toda la colección.
No se requieren 81 permisos nuevos por defecto: una licencia aplicable ya puede
autorizar la reutilización. No se ha reproducido ningún audio ni subido un build.

Esta investigación complementa la [auditoría inicial](RIGHTS_AUDIT_2026-10-09.md).
Su resultado «0/81» describía la evidencia disponible antes de estas comparaciones.
El estado actualizado está en la [tabla de 81 archivos](rights/audio-source-investigation.csv)
y el [registro detallado](rights/audio-source-investigation.json). No se altera
el inventario histórico para presentar estas pruebas como si ya existieran entonces.

## Qué utiliza realmente la app

El catálogo contiene 89 opciones: **81 MP3 ambientales, tres generadores de ruido
y cinco generadores binaurales**. Los MP3 coinciden byte a byte con la revisión de
Moodist `11c0be2200116a3635880d600fd6953899cc51a3`, según el inventario anterior.

El autor de Moodist afirma expresamente que creó sus binaurales y que obtuvo los
otros sonidos de Pixabay o de selecciones CC0 en Freesound.
[Declaración del mantenedor](https://github.com/remvze/moodist/issues/33#issuecomment-2082429291).
En nuestra app, los binaurales se calculan mediante dos ondas sinusoidales con una
portadora de 100 Hz y diferencias de 2, 5, 10, 20 o 40 Hz. Los ruidos blanco, rosa
y marrón también se sintetizan. No incorporamos grabaciones binaurales ni de ruido
de Moodist; se comprobó el catálogo y [DriftAudioEngine.swift](../ios/NodusDrift/DriftAudioEngine.swift).
No hace falta una autorización sobre una grabación ajena para estas ocho opciones.
La licencia del código es una cuestión distinta.

## Originales CC0 identificados

Se contrastó la señal del MP3 incluido en Drift con la vista previa pública de la
fuente. Los porcentajes siguientes son correlaciones normalizadas de tres ventanas,
no probabilidades jurídicas ni una afirmación de identidad byte a byte entre un
original de Freesound y el MP3 editado de Moodist.

| Opción en Drift | Original y autor | Licencia en la fuente | Correlaciones | Evidencia |
| --- | --- | --- | --- | --- |
| Submarine | [submarine.mp3 — Squeeb, 185589](https://freesound.org/people/Squeeb/sounds/185589/) | CC0 | 98,08 / 98,07 / 98,08 % | [Comparación](rights/source-comparisons/submarine-185589.json) |
| Laundry room | [LaundryRoomAmbience — moviebuffgavin, 411914](https://freesound.org/people/moviebuffgavin/sounds/411914/) | CC0 | 98,71 / 99,37 / 98,70 % | [Ventanas interiores](rights/source-comparisons/laundry-411914-interior.json) |
| Restaurant | [Restaurant_Amb_Int.wav — mshahen, 507218](https://freesound.org/people/mshahen/sounds/507218/) | CC0 | 99,89 / 99,94 / 99,95 % | [Comparación](rights/source-comparisons/restaurant-507218.json) |
| Morse code | [Radio transmission morse code @4606.2kHz Poland — NebulousRoyale, 343740](https://freesound.org/people/NebulousRoyale/sounds/343740/) | CC0 | 99,21 / 99,09 / 95,84 % | [Comparación](rights/source-comparisons/morse-343740.json) |
| Slide projector | [Slideprojector #2.m4a — guyburns, 551486](https://freesound.org/people/guyburns/sounds/551486/) | CC0 | 99,27 / 99,38 / 99,36 % | [Ventanas interiores](rights/source-comparisons/projector-551486.json) |

Las tres ventanas de cada positivo mantienen el mismo desplazamiento temporal.
En Laundry room el final no coincide como el interior; se conserva también esa
[comparación inicial](rights/source-comparisons/laundry-411914.json). Restaurant
y Slide projector utilizan ventanas interiores porque el bucle contiene cambios
en sus extremos. Las pruebas acreditan la derivación del original, sin afirmar que
el archivo entero se haya conservado sin edición ni que se hayan identificado
todos los posibles elementos añadidos.

Restaurant coincide además con el artista «Michael Shahen» de sus metadatos. La
candidata anterior «Resturant Ambience», de vickyleao1, número 366003 y licencia
BY-NC, no coincidía con la señal. No se le puede asignar esa licencia a nuestro MP3.

Tres nombres también aparecen en Pixabay:
[Submarine](https://pixabay.com/sound-effects/film-special-effects-submarine-33709/),
[Laundry room ambience](https://pixabay.com/sound-effects/household-laundry-room-ambience-69911/)
y [Radio transmission morse code](https://pixabay.com/sound-effects/technology-radio-transmission-morse-code-4606-6807/).
No se ha determinado desde qué plataforma los descargó Moodist. Tampoco se afirma
que la vista previa de Pixabay haya sido comparada digitalmente: la identificación
positiva se hizo con el original de Freesound. La publicación del original bajo
CC0 proporciona una vía de permiso de copyright, aunque exista otra publicación
con condiciones distintas. No se presupone que dos nombres de usuario sean una
misma identidad legal.

[CC0](https://creativecommons.org/publicdomain/zero/1.0/) permite copiar, modificar
y distribuir la obra, incluso comercialmente, sin solicitar un nuevo permiso de
copyright. El crédito no es una condición de CC0, aunque conservar los autores
y enlaces ayuda a documentar la procedencia. La licencia pública no es una garantía
independiente de titularidad ni autoriza material ajeno añadido por terceros.

## Cómo se investigó y qué quedó sin identificar

Se revisaron el catálogo fijado, etiquetas de los 81 MP3, historial de archivos,
README, incidencias y posibles fuentes públicas. La búsqueda de enlaces individuales
de Pixabay/Freesound en el historial de Markdown, TypeScript, TSX y JSON de Moodist
no encontró una matriz de procedencia. No demuestra que nunca existiera información
privada o externa. La [consulta pública #113](https://github.com/remvze/moodist/issues/113),
abierta el 3 de octubre por otro desarrollador iOS, seguía sin respuesta pública
al consultar el 9 de octubre.

Se hicieron **17 comparaciones de 16 candidatas distintas**, incluidas las cinco
positivas. Se descartaron las candidatas ensayadas para Clock, Library, Paper,
Cat purring, Singing bowl, Woodpecker y Keyboard, y Slideprojector #1. Sus licencias
solo describen a esas candidatas: no se transfieren a las grabaciones de Drift.
Dos consultas adicionales, para Bubbles y Laboratory, devolvieron HTTP 403 y no se
compararon. No se intentó eludir el acceso restringido.

El [script de comparación](../scripts/compare_source_preview.py) decodifica PCM a
memoria con ffmpeg, sin abrir un dispositivo de audio. Busca cada ventana en toda
la candidata y refina el desfase de muestreo. El criterio de coincidencia fuerte
requiere correlación mínima 0,95 y dispersión del desplazamiento máxima 0,02 s.
Las ventanas duran hasta cinco segundos; sus posiciones y duración exacta constan
en cada JSON. Un resultado negativo no excluye transformaciones como cambios de
velocidad, filtros intensos o montajes. Las vistas previas pueden diferir del
original descargable. No se aplican criterios solo por título o duración.

Los registros conservan URLs, hashes SHA-256 de grabación, página y vista previa,
métricas y licencia observada. Los MP3 descargados para comparar y el HTML completo
permanecen en `.build/rights-research`, ignorado por Git. No se añaden grabaciones
de candidatos al producto ni al repositorio.

## La duda específica de Pixabay

La licencia de Pixabay permite usos comerciales y gratuitos. También excluye la
distribución independiente de contenido sustancialmente igual y permite combinarlo
en una obra creativa nueva. Que Drift sea gratis no elimina esa condición. Su mixer,
interfaz y animación aportan creación propia; determinar si bastan para el uso de
cada grabación es una interpretación que esta investigación no convierte en un
permiso confirmado. [Condiciones, apartados 4 y 5](https://pixabay.com/service/terms/).

La [FAQ](https://pixabay.com/service/faq/) pone ejemplos de incorporación de fotos
en apps y juegos, y de música integrada en proyectos mayores. No resuelve
expresamente el caso de una app de sonidos ambientales que permite escuchar una
grabación sola. No se extrapola el ejemplo de fotos como una autorización específica
para todo nuestro catálogo.

## Cómo cerrar lo que falta

El siguiente dato útil es la relación **archivo de Moodist → URL original y
licencia**, con los cambios realizados para crear el bucle. Se ha actualizado una
[consulta concreta al mantenedor](rights/PERMISSION_REQUESTS_DRAFT.md), aún sin enviar,
con los cinco originales ya identificados y las 76 fuentes pendientes. Pedir esa
información no equivale a pedir 76 licencias nuevas. Para un original CC0 identificado
ya hay permiso; solo haría falta una aclaración o autorización adicional cuando
la licencia aplicable no cubra el uso previsto.

Tras revisar la propuesta, el usuario ha optado por conservar solo el informe y
no contactar con Moodist. No se ha enviado ninguna consulta ni obtenido una
respuesta nueva; las 76 fuentes pendientes permanecen sin identificación individual.

La declaración del usuario de que es propietario de Nodus queda registrada como
aclaración de la titularidad del material propio. No sustituye los derechos de los
autores de las grabaciones. Esta investigación no cambia la licencia del código ni
concede una excepción Apple en nombre de terceros. Las traducciones, auditorías
de la app y publicación externa siguen pendientes; las subidas permanecen en pausa
por la petición del usuario de aclarar esta cuestión antes de publicar.
