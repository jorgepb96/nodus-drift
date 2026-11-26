# Soundscape Studio: viabilidad

Inicio: 6 de noviembre de 2026, Europe/Madrid.

## Procedencia de la evidencia

Se inspeccionaron Drift y Reader main (`224d56a`), además del worktree de Reader
`feature/nodus-soundscapes-poc-7ae487` (`ab01cb3`). Stable Audio está en esa rama;
la referencia es su `docs/SOUNDSCAPES_FEASIBILITY.md`.

El usuario indicó expresamente que **no se repitan pruebas en su iPhone** y se use
la viabilidad ya comprobada en Reader. Se canceló la prueba detenida por Xcode al
encontrar la pantalla bloqueada. Se eliminó la aplicación de laboratorio aislada;
la instalación habitual de Drift no se sustituyó. **No se presentan las mediciones
de Reader como mediciones nuevas de Drift.** La validación posterior es mediante
compilación y simulador.

## Mediciones previas de Reader

iPhone 16 Pro Max, A18 Pro, 8 GB, iOS 27.0.1, Release, residencia escalonada:

| Modelo | Audio | Inferencia | Pico del proceso |
| --- | ---: | ---: | ---: |
| Small-Music | 30 s | 6,23 s | 1,20 GB |
| Small-Music | 60 s | 9,56 s | 1,27 GB |
| Small-SFX | 30 s | 5,47 s | 1,21 GB |
| Small-SFX | 60 s | 9,53 s | 1,35 GB |

Reader documenta paridad numérica, pruebas sostenidas y limitación térmica. Su
prueba de batería solo aporta una cota inferior a cinco puntos porcentuales en
una sesión de reposo más generación: **no mide consumo preciso por generación**.
No se extrapola esa cota a Drift. La continuación e inpainting del paquete tienen
paridad comprobada en Mac; su calidad y rendimiento en Drift/iPhone no se han
validado en esta tarea.

Drift reutiliza `SA3Engine(residency: .staged)`, serializa peticiones y libera las
redes tras generar o fallar. Bloquea generación con memoria libre insuficiente,
dispositivos de menos de 6 GB, Low Power Mode o temperatura grave/crítica. Cancela
ante segundo plano, presión de memoria o aviso térmico. La pantalla muestra
tiempo, pico de memoria y estado térmico de la última generación real.

En simulador **no se ejecuta MLX**: Reader documentó un SIGABRT de Metal, que no
puede recuperarse como error Swift. El editor y el catálogo funcionan sin MLX.

## Modelos y descargas

- Runtime MIT de `Modules/StableAudioMLX`, arquitectura T5Gemma → DiT → SAME-S;
  MLX Swift 0.33.0 exacta y Swift Numerics 1.1.1 con resolución fijada.
- Pesos `stabilityai/stable-audio-3-optimized`, revisión
  `30cb2644da54bfa63275d1bc7f1fa67fc718680f`; tamaño y SHA-256 verificados.
- Incluye encoder para continuación: unos **1,9 GB** para un modelo y **2,84 GB**
  para ambos, en unidades decimales, antes de diferencias menores de conversión.
  Los 2,63 GB de algunas mediciones antiguas de Reader no incluían ese encoder.
- Conversión NPZ → safetensors por streaming en el dispositivo; sin Python,
  servidores propios ni pesos incluidos en la app.
- Cuenta del usuario mediante token de lectura de Hugging Face en Keychain. No
  se reutiliza el cliente OAuth de Reader, cuya URI pertenece a otra aplicación.
- El segundo modelo reutiliza los componentes compartidos. Se comprueba espacio
  temporal; las descargas se excluyen del backup y se pueden cancelar/limpiar.
  Eliminar el último modelo elimina los pesos comunes, conservando grabaciones.

## Licencias

Se incluyen los textos fijados de Stability AI Community License y Gemma Terms,
NOTICE, MIT del runtime y MLX, y Apache 2.0 de Swift Numerics. Generación muestra
«Powered by Stable Audio 3 · Stability AI»; Modelos y licencias muestra también
**Powered by Stability AI**, exigido por la licencia, y enlaces a modelos,
restricciones, AUP y registro.

La licencia Community exige registro para usos comerciales y establece un
umbral de ingresos. La entidad distribuidora debe comprobar su elegibilidad y
registro antes de publicar. Descargar pesos no sustituye esas obligaciones ni
los relicencia bajo MIT.

Fuentes oficiales consultadas:

- [Stable Audio 3](https://github.com/Stability-AI/stable-audio-3).
- [Licencias y registro](https://stability.ai/license).
- [Pesos fijados](https://huggingface.co/stabilityai/stable-audio-3-optimized/tree/30cb2644da54bfa63275d1bc7f1fa67fc718680f).
- [AVAudioEnvironmentNode](https://developer.apple.com/documentation/avfaudio/avaudioenvironmentnode).
- [Foundation Models](https://developer.apple.com/documentation/foundationmodels).
- [Privacidad y motivos de API](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

## Spatial Audio y dirección

AVAudioEnvironmentNode recibe mixers mono por fuente espacial; música y
binaurales conservan estéreo. Las automatizaciones actualizan posición y ganancia;
`.auto` permite al sistema elegir el algoritmo de la ruta, con salida estéreo en
altavoces. No se afirma haber validado seguimiento de cabeza ni auriculares
físicos en esta tarea.

Foundation Models utiliza solo `SystemLanguageModel.default`, sesiones locales y
estructuras `@Generable`, con comprobación de disponibilidad en iOS 26+. Los IDs,
rangos y límites se validan antes de aplicar. Actúa como director, sin sintetizar
audio. Puede proponer prompts breves en inglés para sonidos no cubiertos por el
catálogo. Si están instalados los modelos correspondientes, esos encargos se
procesan de uno en uno; si faltan, la escena conserva fuentes del catálogo y
permite revisar las grabaciones pendientes. No hay alternativa de nube.

En el simulador iOS 26.5 de esta tarea, el modelo del sistema informa `.available`
pero la inferencia falla con `promptTemplateNotFound` del recurso de seguridad de
Foundation Models. La prueba de inferencia se registra como omitida por esa
limitación, conservando el diagnóstico en el xcresult. El Studio captura el fallo
y permite continuar manualmente; no se afirma validación de generación de escenas
con Foundation Models en ese entorno.

## Límites

- Música como pieza de una sola reproducción, con continuación hasta 120 s. No
  se promete composición infinita ni preservación PCM exacta fuera de máscaras.
- Hay fundidos de pistas y reproducción continua de ambientes. Cambiar entre
  documentos usa pausa/carga, sin crossfade de dos escenas completas simultáneas.
- La exportación portable contiene composición y grabaciones; no renderiza un
  WAV de la mezcla final.
- Los eventos varían intervalos y punto inicial de las grabaciones, sin variación
  semántica infinita. Los prompts solicitan música instrumental/sin voces; un
  clasificador local de SoundAnalysis rechaza resultados con suficiente presencia
  de habla o canto. El filtro es probabilístico y no garantiza ausencia absoluta.
- Calidad artística, consumo de Drift y experiencia en auriculares físicos no
  se han reevaluado en el dispositivo por instrucción expresa del usuario.

Resultados de compilación y pruebas: [VALIDATION.md](VALIDATION.md).
