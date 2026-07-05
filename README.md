# Fast Ventoy

Script Bash interactivo para crear un USB booteable con Ventoy en Linux. Detecta automáticamente dispositivos USB, descarga la última versión de Ventoy y la instala.

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Tabla de Contenidos

- [Características](#características)
- [Stack](#stack)
- [Estructura](#estructura)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Uso](#uso)
- [Tests](#tests)
- [Configuración](#configuración)
- [CI](#ci)
- [Limitaciones / Roadmap](#limitaciones--roadmap)
- [Licencia](#licencia)

## Características

- Detección automática de dispositivos USB removibles vía `lsblk`
- Menú interactivo para seleccionar el dispositivo destino
- Descarga de la última versión de Ventoy desde GitHub Releases
- Tres modos de operación: instalar (`-i`), forzar instalación limpia (`-I`), actualizar (`-u`)
- Verificación SHA256 de la descarga de Ventoy
- Desmontaje automático de particiones montadas en el dispositivo
- Confirmación explícita antes de escribir en el dispositivo (previene errores)

## Stack

- **Bash** (shell script)
- Dependencias del sistema: `lsblk`, `awk`, `grep`, `sed`, `tar`, `sha256sum`, `curl` o `wget`
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

Instalación de dependencias en Debian/Ubuntu:

```bash
sudo apt update && sudo apt install -y curl wget tar
```

## Instalación

```bash
git clone https://github.com/tu-usuario/fast-ventoy.git
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
3. Confirma escribiendo `SI BORRAR /dev/sdb`
4. Elige modo de instalación:
   - `[1]` Instalar Ventoy desde cero
   - `[2]` Forzar instalación limpia
   - `[3]` Actualizar Ventoy si ya existe
5. El script descarga Ventoy automáticamente, lo extrae y ejecuta `Ventoy2Disk.sh`
6. Al terminar, muestra instrucciones para copiar ISOs:

```
Siguiente paso:
1. Desconecta y conecta nuevamente el pendrive si tu sistema no lo monta solo.
2. Copia tus archivos ISO directamente a la partición grande del USB.
3. Arranca el equipo desde USB y Ventoy mostrará el menú de ISOs.

Ejemplo para copiar una ISO:
  cp ~/Descargas/ubuntu.iso /media/$USER/Ventoy/
```

## Tests

El CI ejecuta ShellCheck para verificar la sintaxis del script:

```bash
# Localmente
shellcheck fast_ventoy.sh
```

## Configuración

No requiere variables de entorno. El archivo `.env.example` es un placeholder.

## CI

GitHub Actions ejecuta ShellCheck en cada push y pull request:

```yaml
- name: ShellCheck
  run: shellcheck *.sh
```

## Limitaciones / Roadmap

- Solo Linux (no soporta macOS ni Windows)
- No verifica checksum SHA256 automáticamente contra el release de GitHub (actualmente comentado)
- No soporte para descarga manual de versiones específicas
- Sin test automatizados más allá de ShellCheck
- Futuro: verificación SHA256, selección de versión específica, modo no-interactivo, soporte para múltiples USBs en paralelo

## Licencia

MIT
