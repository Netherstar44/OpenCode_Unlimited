# ⚡ OpenCode Unlimited
> **High-Performance Multi-Network Quota & VPN Auto-Reset Engine for OpenCode (Desktop & CLI)**  
> **Author:** Jose David Correa — [GitHub: @Netherstar44](https://github.com/Netherstar44)  
> **Repository:** [https://github.com/Netherstar44/OpenCode_Unlimited](https://github.com/Netherstar44/OpenCode_Unlimited)

---

## 📌 Visión General

**OpenCode Unlimited** es una herramienta de ingeniería de red y automatización de procesos diseñada para resolver de raíz los bloqueos de conexión, sockets huérfanos, agotamiento de caché DNS y límites de cuota que experimentan los desarrolladores al utilizar **OpenCode Desktop y OpenCode CLI** junto con conexiones VPN (como UrbanVPN, NordVPN, ProtonVPN, etc.) o redes dinámicas.

Se distribuye como un ejecutable políglota autónomo de un solo archivo: **`OpenCodeUnlimited.bat`**, combinando la inmediatez de la consola de Windows con un motor interno de PowerShell 5.1/7+ ejecutado en memoria con soporte UTF-8 nativo.

---

## 🔬 Análisis Técnico: ¿Por qué los tokens solo rendían 5 a 12 comandos?

Cuando los desarrolladores conmutan de VPN esperando una nueva cuota diaria, frecuentemente experimentan que **los tokens se agotan en apenas 5 a 12 comandos en shell**. La investigación técnica reveló cuatro causas críticas interconectadas:

```
[Problema 1: Daemon en Memoria] ──> opencode-cli.exe (puerto 28894) no moría al cambiar de VPN.
[Problema 2: Device ID Fijo]    ──> .updaterId (UUID estático) asociaba la nueva IP a la misma máquina agotada.
[Problema 3: Contexto Inflado]   ──> opencode.db arrastraba cientos de miles de tokens de comandos previos.
[Problema 4: Reasoning 'max']   ──> El modelo generaba hasta 30,000 tokens de pensamiento oculto por comando simple.
                                                       │
                                                       ▼
                       [Agotamiento fulminante de cuota en 5 - 12 comandos]
```

1. **Persistencia del Daemon de Fondo (`opencode-cli.exe`):**
   OpenCode no es solo una ventana de Electron; ejecuta en segundo plano un daemon Node/Go (`opencode-cli.exe`) escuchando en `http://127.0.0.1:28894`. Los scripts convencionales solo cerraban la ventana gráfica pero dejaban vivo el daemon, el cual conservaba en memoria las credenciales, sockets y cuota consumida.

2. **Identificador Fijo de Instalación (`.updaterId` y `service.json`):**
   El servidor de OpenCode rastrea el consumo no solo por IP, sino por el UUID de dispositivo guardado en `%APPDATA%\ai.opencode.desktop\.updaterId` y `%USERPROFILE%\.local\state\opencode\service.json`. Al cambiar de VPN con el mismo ID, el backend detectaba la misma máquina y mantenía el límite impuesto.

3. **Inflación del Contexto de Historial (Context Bloat):**
   Al ejecutar comandos en la shell, OpenCode acumula los comandos, salidas, diffs y archivos en la sesión activa dentro de `opencode.db`. Al llegar al comando 10, **cada nueva petición re-enviaba más de 100,000 tokens de contexto acumulado**. El usuario cree enviar una sola línea de texto, pero el modelo ingiere 100,000 tokens de golpe, quemando la cuota en minutos.

4. **Variante de Razonamiento Extremo (`variant: "max"`):**
   En modelos de razonamiento (como `deepseek-v4.1-flash-free` o `nemotron`), la variante `max` obliga al modelo a generar entre 20,000 y 32,000 tokens de "pensamiento interno" para cualquier tarea, incluso comandos triviales de shell.

---

## ⚡ Solución: Motor de Tokens Ampliados (v2.0)

`OpenCodeUnlimited` implementa una arquitectura de renovación integral en cada ciclo:

* 🛡️ **Purga Integral de Daemons:** Finaliza OpenCode Desktop, detiene formalmente `opencode service` y liquida cualquier proceso huérfano (`opencode-cli`, `opencode-service*`).
* 🎭 **Rotación Dinámica de Identidad (Device Spoofing):** Genera un nuevo GUID para `.updaterId`, elimina `service.json` y purga almacenes de tokens en LevelDB/Cookies, haciendo que OpenCode se presente como una instalación completamente virgen ante el backend.
* 📦 **Archivado de Sesiones Infladas:** Detecta sesiones pesadas en `opencode.db` y las archiva limpiamente. El próximo comando inicia con **0 tokens de contexto residual** (~800 tokens en lugar de 100,000 tokens).
* 🧠 **Reasoning Equilibrado:** Optimiza la variante de razonamiento a modo balanceado (`high` / `default`), evitando que el modelo queme 30k tokens de pensamiento en un simple comando de terminal.
* 📈 **Rendimiento Real:** El consumo por comando pasa de ~125,000 tokens a ~2,000 tokens. **La cuota rinde para 100+ a 200+ comandos por IP/VPN**, equivalentes a una cuota diaria completa.

---

## ✨ Características Principales

* 🚀 **Un Solo Archivo Autónomo (`OpenCodeUnlimited.bat`):** Cero dependencias externas. Se ejecuta con doble clic o desde terminal.
* ⚡ **Tokens Ampliados Diarios:** Rotación de hardware virtual y purga de contexto para cuota 100% limpia.
* 🌐 **Detección WAN de Doble Capa:** Detecta cambios reales de IP pública exterior en menos de 2 segundos, incluso con adaptadores TAP estáticos.
* 🔔 **Notificaciones Windows Runtime (WinRT) No Invasivas:** Utiliza la API nativa de notificaciones Toast de Windows (`ToastText02`) para alertar al usuario sin interrumpir su flujo de trabajo.
* 🧹 **Purga Profunda de Pila de Red:** Vacía la caché DNS (`Clear-DnsClientCache`), reconstruye la tabla NetBIOS (`nbtstat -R`) y elimina la caché ARP (`netsh interface ip delete arpcache`).
* 🖥️ **Menú Interactivo con Dashboard ASCII:** Interfaz de consola visual para elegir la acción deseada en segundos.

---

## 🛠️ Modos de Uso de `OpenCodeUnlimited.bat`

### 1. Menú Interactivo
Haz doble clic en **`OpenCodeUnlimited.bat`**:

```
===============================================================================
   ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗ ██████╗ ██████╗ ███████╗
  ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝
  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║   ██║██║  ██║█████╗  
  ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║   ██║██║  ██║██╔══╝  
  ╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗╚██████╔╝██████╔╝███████╗
   ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
                   U N L I M I T E D  ·  E D I T I O N                         
   Auto-Reset de Red, Rotación de Identidad y Tokens Ampliados Diarios
   Made By Jose David Correa ~ github: Netherstar44
===============================================================================

  IP Pública Actual: 152.204.226.171
-------------------------------------------------------------------------------
  [1] 🔄 Iniciar Monitor Automático (Detecta VPN/IP y resetea tokens 24/7)
  [2] ⚡ Renovar Cuota / Tokens Ampliados (Espera nueva IP + Rota ID de Dispositivo)
  [3] 🚀 Modo Tokens Ampliados (Archiva contexto inflado + Optimiza reasoning)
  [4] 🧹 Reseteo Rápido Inmediato (Cierra sockets, daemons y limpia DNS/ARP)
  [5] 🧼 Limpieza Profunda Total (Caché + Cookies + Device ID + Sesiones)
  [6] 📊 Ver Estadísticas de Cuota y Tokens (opencode stats)
  [7] ❌ Salir
-------------------------------------------------------------------------------
```

---

### 2. Flujo: Renovar Cuota Diaria / Cambiar de VPN
Si OpenCode indica que se ha agotado la cuota de peticiones:

1. Ejecuta la opción **`[2]`** en el menú (o lanza `OpenCodeUnlimited.bat --renew`).
2. El script emitirá una notificación no invasiva en Windows:
   > ⚡ **OpenCode Unlimited: Cuota / VPN**  
   > *Límite detectado. Cambia de país/servidor en tu VPN para continuar. Esperando nueva IP...*
3. Abre tu cliente de VPN (por ejemplo, **UrbanVPN**) y selecciona otra ubicación o desconecta/reconecta.
4. El script detectará automáticamente la nueva IP pública WAN, estabilizará las rutas de red, limpiará las cachés y reiniciará OpenCode con la sesión renovada.
5. Recibirás la confirmación final:
   > 🔄 **OpenCode Unlimited Actualizado**  
   > *Conexión restablecida con éxito. Nueva IP: [X.X.X.X]*

---

### 3. Flujo: Monitor Continuo en Segundo Plano (Watch Mode)
Si cambias frecuentemente de VPN mientras programas:

Ejecuta la opción **`[1]`** (o lanza `OpenCodeUnlimited.bat --watch`).
* El monitor quedará en segundo plano vigilando tanto los adaptadores físicos como la IP pública exterior.
* Cada vez que conmutes de país o servidor VPN, se activará el ciclo de reseteo automático de forma transparente, notificándote por Toast sin interrumpir tu trabajo.

---

### 4. Ejecución por Línea de Comandos (CLI / Automatización)

Puedes invocar `OpenCodeUnlimited.bat` pasando argumentos directos:

| Comando | Acción |
| :--- | :--- |
| `OpenCodeUnlimited.bat` | Abre el menú interactivo con diagnóstico en tiempo real. |
| `OpenCodeUnlimited.bat --watch` | Inicia directamente el monitor continuo en segundo plano. |
| `OpenCodeUnlimited.bat --renew` | Lanza el asistente de renovación de cuota asistido por VPN. |
| `OpenCodeUnlimited.bat --reset` | Ejecuta un reseteo forzado inmediato de sockets y cachés DNS. |
| `OpenCodeUnlimited.bat --clean` | Reseteo completo con purga profunda de sesión y cookies de OpenCode. |
| `OpenCodeUnlimited.bat --watch -Silent` | Modo monitor 100% silencioso (sin ventana de consola). |

---

## 📂 Estructura del Repositorio

| Archivo | Descripción |
| :--- | :--- |
| **`OpenCodeUnlimited.bat`** | **Núcleo principal.** Script políglota todo en uno con monitor WAN, reseteador y notificador Toast. |
| **`Start-Watcher-Hidden.vbs`** | Lanzador en segundo plano sin ventana de consola (ideal para inicio automático). |
| **`Instalar-AutoInicio.bat`** | Instala el monitor para arrancar silenciosamente al iniciar Windows. |
| **`Desinstalar-AutoInicio.bat`** | Remueve la tarea o acceso de inicio automático. |
| **`Reset-Network-Quick.bat`** | Acceso rápido de un solo clic para reseteo inmediato. |
| **`README.md`** | Documentación técnica detallada de arquitectura y uso. |

---

## 🔒 Consideraciones Importantes sobre Cuotas de IA

* **Modelos Gratuitos (Free Tier de OpenCode):** Al operar con el pool gratuito de OpenCode, la asignación suele evaluarse por dirección IP de origen y sesión de cliente. Al cambiar a una IP de VPN no congestionada y purgar la sesión con la opción `[2]`, se restablece el acceso.
* **Proveedores con API Key:** Si configuras un proveedor externo o relay mediante API Key privada (OpenAI, Anthropic, OpenRouter, etc.), recuerda que el consumo se factura a la clave misma, independientemente de la IP o VPN utilizada.

---

## 👤 Créditos y Autoría

Desarrollado y mantenido por:

**Jose David Correa**  
GitHub: [@Netherstar44](https://github.com/Netherstar44)  
Proyecto: [https://github.com/Netherstar44/OpenCode_Unlimited](https://github.com/Netherstar44/OpenCode_Unlimited)

---

## 📄 Licencia

Distribuido bajo la Licencia **MIT**. Eres libre de utilizar, modificar y distribuir esta herramienta en tus propios flujos de trabajo.
