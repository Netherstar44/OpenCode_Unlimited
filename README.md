# ⚡ OpenCode Unlimited
> **High-Performance Multi-Network Quota & VPN Auto-Reset Engine for OpenCode (Desktop & CLI)**  
> **Author:** Jose David Correa — [GitHub: @Netherstar44](https://github.com/Netherstar44)  
> **Repository:** [https://github.com/Netherstar44/OpenCode_Unlimited](https://github.com/Netherstar44/OpenCode_Unlimited)

---

## 📌 Visión General

**OpenCode Unlimited** es una herramienta de ingeniería de red y automatización de procesos diseñada para resolver de raíz los bloqueos de conexión, sockets huérfanos, agotamiento de caché DNS y límites de cuota que experimentan los desarrolladores al utilizar **OpenCode Desktop y OpenCode CLI** junto con conexiones VPN (como UrbanVPN, NordVPN, ProtonVPN, etc.) o redes dinámicas.

Se distribuye como un ejecutable políglota autónomo de un solo archivo: **`OpenCodeUnlimited.bat`**, combinando la inmediatez de la consola de Windows con un motor interno de PowerShell 5.1/7+ ejecutado en memoria con soporte UTF-8 nativo.

---

## 🔬 Análisis Técnico: ¿Por qué falla OpenCode al cambiar de VPN?

Cuando se utiliza un cliente de inteligencia artificial como OpenCode sobre una VPN y se conmuta de servidor o ubicación:

```
[Cliente OpenCode] ─── (TCP Keep-Alive / WSS) ───> [Interfaz Virtual VPN (ej. 10.7.0.26)] ───> [Túnel Cifrado]
                                                               │ (Cambio de país / reconexión)
                                                               ▼
                                                      [Socket Huérfano]
                                                    (ETIMEDOUT / ECONNRESET)
```

1. **Persistencia de Sockets TCP (Socket Pinning):**
   Los entornos Electron y Node.js emplean agentes HTTP con `keepAlive: true` y WebSockets continuos. Al cambiar de nodo en la VPN, los sockets abiertos quedan asociados al descriptor de archivo de la interfaz virtual previa. El sistema operativo no envía un paquete `RST` o `FIN` inmediato, dejando a OpenCode en un bloqueo silencioso por tiempo de espera indefinido.

2. **Desincronización de IP WAN vs. Adaptador Virtual Local:**
   VPNs populares (como **UrbanVPN**) asignan una IP estática local al adaptador TAP virtual (por ejemplo, `10.7.0.26`) que **no cambia** aunque el usuario alterne entre servidores de Estados Unidos, Alemania o Japón. Los scripts convencionales que solo monitorizan adaptadores locales de Windows (`Get-NetIPAddress`) son ciegos a este cambio. `OpenCodeUnlimited` implementa una verificación de doble capa: monitoriza la firma NDIS local y sondea la IP pública externa (WAN) mediante endpoints distribuidos ultrarrápidos.

3. **Caché de Resolución DNS Obsoleta:**
   El servicio de caché de DNS del sistema (`DnsCache`) conserva los registros `A`/`AAAA` asociados a los servidores DNS del túnel anterior, que dejan de responder en la nueva ruta.

4. **Huella de Sesión y Cookies en Electron:**
   OpenCode Desktop persiste datos temporales de sesión en `%APPDATA%\ai.opencode.desktop` (`Session Storage`, `Cache`, `Network\Cookies`). Si se desea refrescar el entorno o renovar la asignación de cuota libre, no basta con reiniciar el proceso: es necesario purgar los almacenes temporales preservando íntegramente la configuración (`opencode.settings`).

---

## ✨ Características Principales

* 🚀 **Un Solo Archivo Autónomo (`OpenCodeUnlimited.bat`):** Cero dependencias externas. Se ejecuta con doble clic o desde terminal.
* 🌐 **Detección WAN de Doble Capa:** Detecta cambios reales de IP pública exterior en menos de 2 segundos, incluso con adaptadores TAP estáticos.
* 🔔 **Notificaciones Windows Runtime (WinRT) No Invasivas:** Utiliza la API nativa de notificaciones Toast de Windows (`ToastText02`) para alertar al usuario sin interrumpir su flujo de trabajo.
* 🧹 **Purga Profunda de Pila de Red:** Vacía la caché DNS (`Clear-DnsClientCache`), reconstruye la tabla NetBIOS (`nbtstat -R`) y elimina la caché ARP (`netsh interface ip delete arpcache`).
* ⚡ **Destrucción y Reinicio Elegante:** Localiza dinámicamente la ruta de ejecución de OpenCode Desktop y CLI, finaliza sockets colgados y restablece la aplicación de forma transparente.
* 🧼 **Limpieza Selectiva de Caché:** Purga cookies de red y almacenamiento volátil sin alterar configuraciones personalizadas ni temas.
* 🖥️ **Menú Interactivo con Dashboard ASCII:** Interfaz de consola visual para elegir la acción deseada en segundos.

---

## 🛠️ Modos de Uso de `OpenCodeUnlimited.bat`

### 1. Modo Interactivo (Recomendado para uso diario)
Haz doble clic en **`OpenCodeUnlimited.bat`**. Aparecerá el panel de control:

```
===============================================================================
   ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗ ██████╗ ██████╗ ███████╗
  ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝
  ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║   ██║██║  ██║█████╗  
  ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║   ██║██║  ██║██╔══╝  
  ╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗╚██████╔╝██████╔╝███████╗
   ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
                          U N L I M I T E D                            
  Auto-Reset de Red, Enrutamiento de VPN y Gestión de Cuota para OpenCode
  Made By Jose David Correa ~ github: Netherstar44
===============================================================================

  IP Pública Actual: 152.204.226.171
-------------------------------------------------------------------------------
  [1] 🔄 Iniciar Monitor en Segundo Plano (Auto-Detecta cambio de VPN/IP y resetea)
  [2] ⚡ Renovar Cuota Ahora (Te avisa para cambiar de país y resetea al detectar nueva IP)
  [3] 🧹 Reseteo Rápido Inmediato (Cierra sockets, limpia DNS/ARP y reinicia OpenCode)
  [4] 🧼 Limpieza Profunda (Caché DNS + Limpieza de sesión y cookies de OpenCode)
  [5] ❌ Salir
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
