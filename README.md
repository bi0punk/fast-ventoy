# Fast Ventoy

Script Bash interactivo para crear un USB booteable con Ventoy en Linux. Detecta automáticamente dispositivos USB, descarga la última versión de Ventoy, verifica su integridad con SHA256 y la instala.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![ShellCheck](https://github.com/bi0punk/fast-ventoy/actions/workflows/ci.yml/badge.svg)](https://github.com/bi0punk/fast-ventoy/actions/workflows/ci.yml)
[![GitHub last commit](https://img.shields.io/github/last-commit/bi0punk/fast-ventoy)](https://github.com/bi0punk/fast-ventoy/commits/main)

## Tabla de Contenidos

- [Características](#características)
- [Stack](#stack)
- [Estructura](#estructura)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Uso](#uso)
- [Flujo interactivo](#flujo-interactivo)
- [Tests](#tests)
- [Configuración](#configuración)
- [CI](#ci)
- [Seguridad](#seguridad)
- [Limitaciones / Roadmap](#limitaciones--roadmap)
- [Licencia](#licencia)

## Características

- Detección automática de dispositivos USB removibles vía `lsblk`
- Menú interactivo para seleccionar el dispositivo destino con timeout de 120s
- Validación de permisos: verifica que `sudo` funciona antes de continuar
- Descarga de la última versión de Ventoy desde GitHub Releases usando `jq`
- **Verificación SHA256** de la descarga contra el release de GitHub
- Desmontaje automático de particiones montadas en el dispositivo
- Confirmación explícita antes de escribir en el dispositivo (`SI BORRAR /dev/sdb`)
- Manejo de señales: `SIGINT` y `SIGTERM` limpian el entorno temporal y salen
- Colores ANSI solo cuando la salida es un TTY (no corrompe logs ni pipes)
- Tres modos de operación: instalar (`-i`), forzar instalación limpia (`-I`), actualizar (`-u`)
- Control de errojo: verifica el código de salida de `Ventoy2Disk.sh`

## Stack

- **Bash** (shell script, >= 4.0)
- Dependencias del sistema: `lsblk`, `awk`, `grep`, `sed`, `tar`, `sha256sum`, `jq`, `curl` o `wget`
- CI: [ShellCheck](https://www.shellcheck.cybercraft.io/)
- Sin librerías externas

## Estructura

```
fast-ventoy/
├── fast_ventoy.sh       # Script principal
├── tests/
│   └── .gitkeep         # Placeholder para tests futuros
├── .env.example          # Placeholder de configuración
├── .github/
│   └── workflows/
│       └── ci.yml        # CI: ShellCheck
├── .gitignore
├── LICENSE
└── README.md
```

## Requisitos

- Linux (probado en Debian/Ubuntu/Kali y derivados)
- Bash >= 4.0
- `sudo` o ejecución como root
- `curl` o `wget` instalados
- `jq` instalado (para parseo seguro del JSON de GitHub API)

Instalación de dependencias en Debian/Ubuntu:

```bash
sudo apt update && sudo apt install -y curl wget tar jq
```

## Instalación

```bash
git clone https://github.com/bi0punk/fast-ventoy.git
cd fast-ventoy
chmod +x fast_ventoy.sh
```

## Uso

```bash
sudo ./fast_ventoy.sh
```

### Flujo interactivo

1. El script lista todos los discos y detecta USBs automáticamente:

```
Discos detectados:
NAME    SIZE MODEL            TRAN  RM TYPE
sda   238.5G WDC             sata   0 disk
sdb    14.9G USB Flash Drive  usb   1 disk
```

2. Selecciona un dispositivo (o escríbelo manualmente)
3. Si no se detecta ningún USB, se permite escribir la ruta manualmente
4. Confirma escribiendo exactamente `SI BORRAR /dev/sdb`
5. Elige modo de instalación:
   - `[1]` Instalar Ventoy desde cero
   - `[2]` Forzar instalación limpia
   - `[3]` Actualizar Ventoy si ya existe
6. El script descarga Ventoy, verifica el checksum SHA256, lo extrae y ejecuta `Ventoy2Disk.sh`
7. Al terminar, muestra instrucciones para copiar ISOs:

```
Siguiente paso:
1. Desconecta y conecta nuevamente el pendrive si tu sistema no lo monta solo.
2. Copia tus archivos ISO directamente a la partición grande del USB.
3. Arranca el equipo desde USB y Ventoy mostrará el menú de ISOs.

Ejemplo para copiar una ISO:
  cp ~/Descargas/ubuntu.iso /media/$USER/Ventoy/
```

### Comportamiento ante timeout

Si el usuario no responde un prompt en **120 segundos**, el script muestra un aviso de timeout y sale limpiamente, eliminando el directorio temporal creado.

### Manejo de señales

Presionar `Ctrl+C` o recibir `SIGTERM` detiene el script de forma segura, ejecuta la limpieza del directorio temporal y muestra un mensaje de advertencia.

## Tests

El CI ejecuta ShellCheck para verificar la sintaxis del script:

```bash
# Localmente
shellcheck fast_ventoy.sh

# Con verbose output para más detalle
shellcheck -x -s bash fast_ventoy.sh
```

## Configuración

No requiere variables de entorno. El archivo `.env.example` es un placeholder.

## CI

GitHub Actions ejecuta ShellCheck en cada push y pull request:

```yaml
name: CI
on: [push, pull_request]
jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: ShellCheck
        run: shellcheck *.sh
```

## Seguridad

- **Descarga verificada:** se descarga el archivo `.sha256` del release de GitHub y se valida contra el tarball descargado con `sha256sum -c`
- **Parseo seguro:** el JSON de la API de GitHub se procesa con `jq` en lugar de `grep`, evitando falsos positivos por formato inesperado
- **Confirmación explícita:** se requiere escribir el texto exacto `SI BORRAR /dev/sdX` para proceder, previniendo escrituras accidentales
- **Validación de sudo:** antes de cualquier operación con privilegios se verifica que `sudo` esté funcionando correctamente
- **Directorio temporal limpio:** el directorio de descarga se crea con `mktemp -d` y se elimina en el `trap cleanup EXIT`, incluso ante interrupciones

## Limitaciones / Roadmap

- Solo Linux (no soporta macOS ni Windows)
- No soporte para descarga manual de versiones específicas
- Sin test automatizados más allá de ShellCheck
- Futuro: selección de versión específica, modo no-interactivo, soporte para múltiples USBs en paralelo

## Licencia

MIT
