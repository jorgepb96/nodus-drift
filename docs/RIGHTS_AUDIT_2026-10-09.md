# Auditoría de distribución de Nodus Drift — 9 de octubre de 2026

> Historical bank: this report concerns the original Moodist MP3s in builds 1–5. All 81 were subsequently replaced. See [the current replacement report](AUDIO_REPLACEMENT_2026-10-09.md); original findings remain preserved below.

**Conclusión: quedan condiciones de licencia y evidencias pendientes para cerrar la publicación pública.** Hay una
vía documentada para resolver el material propio de Nodus. El bloqueo principal son
las grabaciones: su identidad está comprobada; la investigación posterior ha
identificado cinco originales CC0 y mantiene 76 fuentes individuales pendientes.
La falta de evidencia no demuestra una infracción; tampoco permite
dar por cerrados los derechos al presentar la app.

Esta es una auditoría de evidencias y condiciones, no un dictamen jurídico ni una
garantía de titularidad. No se ha concedido ninguna licencia en nombre del autor.

### Aclaración y actualización posterior del mismo día

La [investigación de fuentes originales](AUDIO_SOURCE_INVESTIGATION_2026-10-09.md)
identifica Submarine, Laundry room, Restaurant, Morse code y Slide projector mediante
comparaciones digitales con originales CC0. El estado actualizado es **5/81**, con
76 fuentes pendientes. Los «0/81» de las tablas y archivos de la revisión inicial
se conservan como registro histórico y no describen ya el resultado actual.
El usuario ha aclarado expresamente que es propietario de Nodus; no se le exige
pedirse autorización a sí mismo para su material propio. Esa titularidad no se
extiende automáticamente a grabaciones ajenas. Los cinco binaurales y tres ruidos
de iOS son generadores locales, sin grabaciones de Moodist incorporadas.

No se exige obtener 81 autorizaciones nuevas por defecto. Una licencia pública
aplicable puede dar ya permiso suficiente: CC0 permite reutilización sin pedir
permiso de copyright al autor; Pixabay permite numerosos usos, con restricciones
como la distribución independiente, también gratuita. La declaración general de
Moodist es evidencia que debe conservarse. El resultado «0/81» se refiere a la
ausencia de un vínculo individual comprobado entre cada archivo y su licencia
original; no demuestra que las grabaciones carezcan de licencia o que exista una
infracción. Hay que identificar las licencias y evaluar su alcance antes de decidir
si hace falta un permiso adicional para algún uso concreto.

Después de la revisión inicial se subieron el código y las instrucciones al
repositorio en el commit `5954092717ac07341e74f6d2a300a90d601ff39f`. Sigue siendo
privado, por lo que el enlace no proporciona acceso al código a futuros testers
externos. La referencia a un repositorio vacío y al build 1.0.0 (1) en el cuerpo
describe el estado de la revisión inicial. La beta interna actual es 0.1.0 (5).
El usuario ha pedido una explicación antes de nuevas subidas; no se realizarán
subidas a TestFlight ni GitHub mientras se aclara esta cuestión.

## Alcance y método

Revisión de los archivos incluidos en la app, historial completo de los repositorios
de referencia, licencias, registro de CLA, incidencias públicas y condiciones
oficiales disponibles el día de la auditoría. Se fijan estas versiones:

| Referencia | Revisión |
| --- | --- |
| Nodus utilizado por la adaptación | `68fa0210dc8407938d644978291840d85aeb49b1` |
| Nodus histórico MIT, v3.2.7 | `cfc0f7f03649fe4a6b80bd2ad97b4b7a81aa6441` |
| Moodist / grabaciones | `11c0be2200116a3635880d600fd6953899cc51a3` |
| Registro público de firmas CLA | `60139d3d3c1276d0fd2942c1b14eeab6f6b07895` |
| Binario existente en TestFlight | 1.0.0 (1), beta interna del titular |

El script [audit_rights.py](../scripts/audit_rights.py) comprueba cada SHA-256, tamaño
y SHA-1 de objeto Git; recoge etiquetas de contenedor y pistas mediante ffprobe y
sigue el historial de cada archivo, incluidos cambios de nombre. No asigna licencias
por el nombre, la fecha de incorporación a Git ni similitudes de títulos.

## 1. Material de Nodus y AGPL

### Nodi y la N: permiso histórico MIT comprobado

La [versión publicada v3.2.7](https://github.com/jorgepb96/nodus/releases/tag/v3.2.7)
contiene una [licencia MIT](https://github.com/jorgepb96/nodus/blob/cfc0f7f03649fe4a6b80bd2ad97b4b7a81aa6441/LICENSE).
Los tres archivos siguientes coinciden byte a byte con los de la revisión actual
utilizada para la adaptación:

| Archivo original | SHA-256 en ambas versiones |
| --- | --- |
| `src/components/nodi/Nodi.tsx` | `c7482c56378d9419edccdb5c39d46f8e6c5d81422072a009148c7a180005ee19` |
| `src/assets/nodus-logo.svg` | `fc676b5e5d7def435d465eaad7582e28523c8d62928f85946e977bedba602d0f` |
| `src/components/nodi/nodi.css` | `4d5a11409cf97b155fb7738be9dc41f9c58338383739c3f38020e71419183f1d` |

La posterior AGPL no elimina ese permiso MIT. Se puede documentar la adaptación
de estos archivos desde v3.2.7 conservando el aviso completo de copyright y licencia,
guardado en [NODUS-HISTORICAL-MIT.txt](rights/NODUS-HISTORICAL-MIT.txt). Ya se ha
incorporado al código y a los créditos de Settings para el próximo build. El binario
1.0.0 (1) ya subido no cambia. MIT no concede por sí sola derechos de marca. Se limita
a esos archivos; no convierte todo DRIFT en MIT.

### DRIFT de septiembre: autoría y CLA

El [registro por archivos](rights/first-party-material.json) cubre el Nodi original,
logo, estilos, vista y componentes de DRIFT y datos/estado compartidos. Los 14 commits
que afectan a ese ámbito figuran como 13 de Drakonis96 y uno de Jorge Pérez Burgueño.
Sus cuerpos contienen una atribución a Claude, pero no otro coautor humano declarado.
Esto describe la evidencia de Git: no descarta derechos de un empleador, material
ajeno no identificado o errores de atribución.

La [firma pública de CLA](https://github.com/jorgepb96/nodus/blob/60139d3d3c1276d0fd2942c1b14eeab6f6b07895/signatures/v1/68b2b9153b43fb63d3f8d7bee0156375d02005d3023dc73822994a0273fdbaf1/MDQ6VXNlcjQxMDI3MDAz.json)
de Drakonis96, de 5 de septiembre, coincide con el identificador estable del perfil
actual jorgepb96. Se comprobó el SHA-256 del documento firmado:
`68b2b9153b43fb63d3f8d7bee0156375d02005d3023dc73822994a0273fdbaf1`.
El [CLA](https://github.com/jorgepb96/nodus/blob/68fa0210dc8407938d644978291840d85aeb49b1/CLA.md)
permite al mantenedor relicenciar las aportaciones cubiertas, incluidas obras derivadas.
Excluye aportaciones fusionadas antes de aceptar y derechos ajenos. Las adiciones
de DRIFT revisadas son posteriores a la firma; para contribuciones propias también
importa la titularidad directa. El registro acredita una vía, no una licencia Apple
ya adoptada para esta app.

### Qué falta para cerrar esta parte

La [licencia vigente](https://github.com/jorgepb96/nodus/blob/68fa0210dc8407938d644978291840d85aeb49b1/LICENSE)
es AGPL-3.0-only. El código nativo y sus avisos siguen bajo ella. No se encontró una
excepción Apple aprobada en las excepciones del repositorio.

La AGPL exige cumplir las condiciones para distribuir binarios y proporcionar el
código fuente correspondiente; su §7 admite permisos adicionales cuando existe
autoridad para concederlos. Sus §§3 y 10 importan al analizar medidas técnicas y
restricciones posteriores. La información de instalación del §6 tiene condiciones
específicas: no se afirma que todo envío de una app exija entregar claves privadas.
Véase el [texto oficial AGPL](https://www.gnu.org/licenses/agpl-3.0.html), también
conservado íntegramente en el proyecto.

La EULA estándar actual de Apple contiene una salvedad para las licencias de
componentes abiertos en su prohibición de copiar, modificar o investigar el código.
Mantiene restricciones de transferencia y redistribución. Esa salvedad ayuda, pero
no demuestra por sí sola compatibilidad con todas las obligaciones AGPL y condiciones
de distribución. No se mantiene la afirmación anterior de que Apple prohíba
automáticamente cualquier app AGPL.
[EULA oficial](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/).

Se ha preparado un [permiso adicional Apple sin adoptar](rights/APPLE_PERMISSION_DRAFT.md),
limitado al material propio o autorizado por CLA. Requiere una decisión explícita
del titular sobre alcance y licencia. No autoriza los MP3. Otra vía sería una
licencia alternativa suficiente para todo el material propio cubierto; no se ha
elegido ni aplicado una relicencia general.

**Problema adicional comprobado:** «View source code» apunta a un repositorio privado
y vacío (`private=true`, `size=0` según GitHub). Para receptores externos ese enlace
no proporciona el código de este build. AGPL no obliga a usar GitHub público, pero
sí a facilitar el código a los destinatarios conforme a la modalidad aplicable.
Hace falta un snapshot exacto, avisos e instrucciones de compilación y un acceso
que funcione para ellos. La beta actual tiene al titular como único tester; no se
afirma que eso ya constituya un incumplimiento frente a terceros.

## 2. Las 81 grabaciones

| Comprobación | Resultado |
| --- | --- |
| Coinciden con catálogo y archivos de Moodist fijados | **81/81** |
| Tamaño conjunto | 103.863.687 bytes |
| Primera incorporación rastreada | 51 en 2023, 29 en 2024, 1 en 2025 |
| Incorporadas después de la aclaración de abril de 2024 | 14 |
| Fuente original individual acreditada | **0/81** |
| Licencia individual acreditada | **0/81** |
| Declaración general conservada | Pixabay Content License o CC0 |

El [CSV de 81 filas](rights/audio-recordings.csv) y el [JSON detallado](rights/audio-recordings.json)
permiten completar fuente, creador y prueba de licencia sin perder la relación con
los archivos reales. Un hash comprueba identidad, no autorización.

El árbol y los mensajes del historial consultados no aportan una matriz de fuentes
y licencias por grabación. La [declaración de Moodist](https://github.com/remvze/moodist/blob/11c0be2200116a3635880d600fd6953899cc51a3/README.md#license)
distingue su código MIT de los activos sonoros. En [la respuesta del mantenedor de abril de 2024](https://github.com/remvze/moodist/issues/33#issuecomment-2082429291)
se afirma que los sonidos proceden de Pixabay o Freesound y que los de Freesound se
eligieron con CC0. No da enlaces individuales. Catorce de nuestros archivos se
incorporaron después de esa respuesta. La [consulta #113](https://github.com/remvze/moodist/issues/113),
abierta el 3 de octubre de 2026 para pedir las fuentes originales, continuaba abierta
y sin respuestas al comprobarla. Esa consulta pertenece a otra persona; no se ha
enviado un mensaje en nombre de Nodus.

### Alcance permitido y cuestiones pendientes

Pixabay permite usos gratuitos y comerciales, pero prohíbe distribuir contenido
independiente, también gratis. Admite combinaciones que crean una obra nueva; su
FAQ menciona incorporar imágenes a apps. Eso favorece ciertos usos integrados, pero
no resuelve automáticamente un catálogo de sonidos originales reproducibles por
separado. Nodi y el mezclador aportan creación; seleccionar una sola pista original
en bucle deja una cuestión real sobre el alcance permitido. La fecha en Git no
acredita la fecha original que Pixabay utiliza para identificar su contenido CC0
anterior al 9 de enero de 2019. Debe aclararse el uso concreto con fuentes identificadas.
[Términos §4–5](https://pixabay.com/service/terms/), [FAQ](https://pixabay.com/service/faq/).

Una dedicación CC0 auténtica permite amplia reutilización, pero debe proceder de
quien pueda conceder los derechos; no despeja derechos de terceros ajenos al autor.
Es necesario vincular cada MP3 con su fuente y dedicación, en lugar de extender
MIT o AGPL a los sonidos.
[CC0, texto legal](https://creativecommons.org/publicdomain/zero/1.0/legalcode.en).

Excluir los MP3 de Git, impedir exportarlos o aplicar crossfades en memoria no
cambia su licencia dentro de la IPA. La decisión histórica de aprobarlos **dentro
de Nodus desktop** se conserva; no aporta por sí sola un nuevo permiso iOS.

### Pista de metadatos: comprobación para evitar falsos positivos

Solo `places/restaurant.mp3` contiene nombre y artista: «Resturant Ambience» y
«Michael Shahen». Los demás metadatos no identifican autor/fuente/licencia. Buscar
ese título llevó a [Freesound 366003](https://freesound.org/people/vickyleao1/sounds/366003/),
con otro usuario, duración y licencia CC BY-NC. Se contrastaron tres ventanas de
cinco segundos del archivo local contra su preescucha pública, a 8 kHz, mediante
correlación normalizada exhaustiva: máximos 0,049 / 0,063 / 0,068, sin desplazamiento
común. **No se estableció identidad.** El título no basta para asignar esa licencia
a nuestro archivo ni acusar una infracción. No se descarta toda transformación
posible; la fuente de nuestro MP3 sigue sin acreditar.
[Resultado de la comparación](rights/restaurant-candidate-comparison.json).

## 3. Apple y gratuidad

El acuerdo público de Apple exige cumplir las licencias abiertas. Su Schedule 1
cubre apps gratuitas: requiere derechos de reproducción, distribución, entrega
a usuarios y los usos de Apple para prestar el servicio. También abarca beta testing
y no elimina derechos de terceros en TestFlight. La aprobación técnica de un build
no es un permiso de copyright.
[Acuerdo oficial, §3.3 y Schedule 1 §§1.2, 1.5, 4.1](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/).

Apple exige contenido propio o licenciado y puede solicitar autorización. Un problema
de derechos puede impedir o retirar la distribución.
[App Review §§5.2–5.2.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property).

En el navegador integrado se comprobó que el acuerdo de apps gratuitas figura
**Activo**, con período de 31 de agosto de 2026 a 31 de agosto de 2027. La interfaz
consultada no expone el texto de la versión firmada. Se contrastaron textos públicos
actuales; **no se certificó la versión contractual firmada**, ni se configuró una
EULA nueva. Esa comprobación debe
acompañar la adopción del permiso para el siguiente lanzamiento. Esta auditoría no
es una búsqueda mundial de marcas ni una revisión de privacidad de cada voz grabada
o de derechos no revelados por los proveedores.

## Cierre verificable antes de publicar

1. Adoptar y registrar una vía de licencia suficiente para el material de Nodus
   utilizado; conservar MIT histórico donde corresponda y actualizar avisos/EULA
   del nuevo build. El borrador requiere titularidad o autoridad suficiente.
2. Obtener enlaces originales y licencia/prueba para cada grabación. Para los sonidos
   Pixabay cuyo uso siga siendo dudoso, obtener confirmación suficiente del proveedor
   o titular, con alcance App Store, TestFlight, reproducción individual, mezcla y
   distribución sin conexión.
3. Sustituir los sonidos cuya autorización no pueda acreditarse por grabaciones
   propias o con permisos documentados. Mantener originales sin evidencia no cierra
   el problema; sustituirlos cambia la paridad sonora y requiere una decisión de producto.
4. Proporcionar código y datos de compilación del release por una vía accesible
   a sus receptores; comprobar los avisos del binario y el acuerdo/EULA.

Los [borradores de solicitudes](rights/PERMISSION_REQUESTS_DRAFT.md) están preparados.
No se han enviado, modificado la visibilidad del repositorio ni publicado una
versión nueva. Con la evidencia actual no sería fiel declarar todos los permisos cerrados.
