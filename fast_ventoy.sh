#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Ventoy USB Interactivo
# Autor: systec / ChatGPT
# Objetivo:
#   - Detectar pendrives USB
#   - Descargar la última versión de Ventoy para Linux
#   - Instalar o actualizar Ventoy
#   - Dejar el pendrive listo para copiar ISOs
#
# Probado para Linux.
# ADVERTENCIA:
#   Instalar Ventoy en modo instalación BORRA el dispositivo elegido.
# ============================================================

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
BOLD="\033[1m"
RESET="\033[0m"

WORKDIR=""
VENTOY_DIR=""

cleanup() {
    if [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]]; then
        rm -rf "$WORKDIR"
    fi
}
trap cleanup EXIT

log() {
    echo -e "${GREEN}[OK]${RESET} $*"
}

info() {
    echo -e "${CYAN}[INFO]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${RESET} $*"
}

err() {
    echo -e "${RED}[ERROR]${RESET} $*" >&2
}

pause() {
    echo
    read -rp "Presiona ENTER para continuar..."
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        err "Falta el comando requerido: $1"
        exit 1
    }
}

check_dependencies() {
    need_cmd lsblk
    need_cmd awk
    need_cmd grep
    need_cmd sed
    need_cmd tar
    need_cmd sha256sum

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        err "Necesitas curl o wget instalado."
        echo "Debian/Ubuntu/Kali:"
        echo "  sudo apt update && sudo apt install -y curl wget tar"
        exit 1
    fi
}

download_file() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -L --fail --progress-bar "$url" -o "$output"
    else
        wget --show-progress -O "$output" "$url"
    fi
}

require_root_or_sudo() {
    if [[ "$EUID" -eq 0 ]]; then
        SUDO=""
    else
        if ! command -v sudo >/dev/null 2>&1; then
            err "Este script necesita sudo o ejecutarse como root."
            exit 1
        fi
        SUDO="sudo"
    fi
}

header() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "============================================================"
    echo "        VENTOY USB INTERACTIVO - LINUX"
    echo "============================================================"
    echo -e "${RESET}"
    echo "Este script dejará un pendrive listo para copiar ISOs."
    echo
    echo -e "${RED}${BOLD}IMPORTANTE:${RESET} instalar Ventoy puede borrar el USB completo."
    echo "Nunca selecciones tu disco interno."
    echo
}

show_all_disks() {
    echo -e "${BOLD}Discos detectados:${RESET}"
    echo
    lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN,RM,TYPE
    echo
}

get_usb_devices() {
    # Devuelve dispositivos tipo disk que sean USB o removibles.
    lsblk -dnpo NAME,TRAN,RM,TYPE | awk '$4=="disk" && ($2=="usb" || $3=="1") {print $1}'
}

select_device() {
    local devices=()
    mapfile -t devices < <(get_usb_devices)

    echo -e "${BOLD}Pendrives / discos removibles detectados:${RESET}"
    echo

    if [[ "${#devices[@]}" -eq 0 ]]; then
        warn "No se detectaron dispositivos USB/removibles automáticamente."
        show_all_disks
        echo "Puedes escribir manualmente el dispositivo, por ejemplo: /dev/sdb"
        read -rp "Dispositivo destino: " TARGET_DEV
    else
        local i=1
        for dev in "${devices[@]}"; do
            echo "[$i] $(lsblk -dnpo NAME,SIZE,MODEL,SERIAL,TRAN,RM "$dev")"
            ((i++))
        done

        echo
        echo "[m] Escribir manualmente otro dispositivo"
        echo "[q] Salir"
        echo
        read -rp "Selecciona una opción: " opt

        case "$opt" in
            q|Q)
                exit 0
                ;;
            m|M)
                read -rp "Dispositivo destino, ejemplo /dev/sdb: " TARGET_DEV
                ;;
            *)
                if ! [[ "$opt" =~ ^[0-9]+$ ]]; then
                    err "Opción inválida."
                    exit 1
                fi

                if (( opt < 1 || opt > ${#devices[@]} )); then
                    err "Número fuera de rango."
                    exit 1
                fi

                TARGET_DEV="${devices[$((opt-1))]}"
                ;;
        esac
    fi

    if [[ ! -b "$TARGET_DEV" ]]; then
        err "El dispositivo no existe: $TARGET_DEV"
        exit 1
    fi

    local dev_type
    dev_type="$(lsblk -dnpo TYPE "$TARGET_DEV" | awk '{print $1}')"

    if [[ "$dev_type" != "disk" ]]; then
        err "Debes seleccionar el disco completo, no una partición."
        echo "Ejemplo correcto: /dev/sdb"
        echo "Ejemplo incorrecto: /dev/sdb1"
        exit 1
    fi

    echo
    echo -e "${BOLD}${YELLOW}Dispositivo seleccionado:${RESET}"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS,MODEL,SERIAL,TRAN,RM "$TARGET_DEV"
    echo
}

confirm_device() {
    echo -e "${RED}${BOLD}ADVERTENCIA FINAL:${RESET}"
    echo "El dispositivo seleccionado es:"
    echo
    echo "  $TARGET_DEV"
    echo
    lsblk -dnpo NAME,SIZE,MODEL,SERIAL,TRAN,RM "$TARGET_DEV"
    echo
    echo "Para confirmar, escribe exactamente:"
    echo -e "  ${BOLD}SI BORRAR $TARGET_DEV${RESET}"
    echo
    read -rp "> " confirmation

    if [[ "$confirmation" != "SI BORRAR $TARGET_DEV" ]]; then
        err "Confirmación incorrecta. No se hizo ningún cambio."
        exit 1
    fi
}

unmount_partitions() {
    info "Revisando particiones montadas..."

    local mounted_parts=()
    mapfile -t mounted_parts < <(lsblk -lnpo NAME,MOUNTPOINT "$TARGET_DEV" | awk '$2 != "" {print $1}')

    if [[ "${#mounted_parts[@]}" -eq 0 ]]; then
        log "No hay particiones montadas."
        return
    fi

    warn "Hay particiones montadas. Se intentarán desmontar."
    for part in "${mounted_parts[@]}"; do
        echo "Desmontando $part ..."
        $SUDO umount "$part" || {
            err "No se pudo desmontar $part"
            echo "Cierra ventanas del explorador de archivos o terminales usando el USB."
            exit 1
        }
    done

    sync
    log "Particiones desmontadas."
}

download_ventoy() {
    WORKDIR="$(mktemp -d)"
    cd "$WORKDIR"

    info "Consultando última versión de Ventoy desde GitHub..."

    local api_json
    if command -v curl >/dev/null 2>&1; then
        api_json="$(curl -fsSL https://api.github.com/repos/ventoy/Ventoy/releases/latest)"
    else
        api_json="$(wget -qO- https://api.github.com/repos/ventoy/Ventoy/releases/latest)"
    fi

    local url
    url="$(echo "$api_json" | grep -Eo 'https://[^"]+ventoy-[0-9.]+-linux\.tar\.gz' | head -n 1)"

    if [[ -z "$url" ]]; then
        err "No pude obtener automáticamente el enlace de Ventoy."
        echo "Puedes descargarlo manualmente desde:"
        echo "  https://www.ventoy.net/en/download.html"
        exit 1
    fi

    local file
    file="$(basename "$url")"

    info "Descargando: $file"
    download_file "$url" "$file"

    log "Descarga completada."

    info "Extrayendo Ventoy..."
    tar -xzf "$file"

    VENTOY_DIR="$(find "$WORKDIR" -maxdepth 1 -type d -name 'ventoy-*' | head -n 1)"

    if [[ -z "$VENTOY_DIR" || ! -f "$VENTOY_DIR/Ventoy2Disk.sh" ]]; then
        err "No se encontró Ventoy2Disk.sh después de extraer."
        exit 1
    fi

    chmod +x "$VENTOY_DIR/Ventoy2Disk.sh"

    log "Ventoy preparado en: $VENTOY_DIR"
}

select_mode() {
    echo
    echo -e "${BOLD}Modo de operación:${RESET}"
    echo
    echo "[1] Instalar Ventoy desde cero BORRANDO el USB"
    echo "[2] Forzar instalación limpia BORRANDO el USB"
    echo "[3] Actualizar Ventoy si ya existe en el USB"
    echo "[q] Salir"
    echo
    read -rp "Selecciona una opción: " mode

    case "$mode" in
        1)
            VENTOY_MODE="-i"
            ;;
        2)
            VENTOY_MODE="-I"
            ;;
        3)
            VENTOY_MODE="-u"
            ;;
        q|Q)
            exit 0
            ;;
        *)
            err "Opción inválida."
            exit 1
            ;;
    esac
}

install_ventoy() {
    cd "$VENTOY_DIR"

    echo
    info "Ejecutando Ventoy2Disk.sh $VENTOY_MODE $TARGET_DEV"
    echo

    $SUDO sh ./Ventoy2Disk.sh "$VENTOY_MODE" "$TARGET_DEV"

    sync
    sleep 2

    log "Proceso de Ventoy terminado."
}

show_result() {
    echo
    echo -e "${BOLD}${GREEN}Estado final del dispositivo:${RESET}"
    echo
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS,MODEL "$TARGET_DEV"
    echo

    echo -e "${BOLD}Siguiente paso:${RESET}"
    echo "1. Desconecta y conecta nuevamente el pendrive si tu sistema no lo monta solo."
    echo "2. Copia tus archivos ISO directamente a la partición grande del USB."
    echo "3. Arranca el equipo desde USB y Ventoy mostrará el menú de ISOs."
    echo

    echo "Ejemplo para copiar una ISO:"
    echo
    echo "  cp ~/Descargas/ubuntu.iso /media/\$USER/Ventoy/"
    echo
}

main() {
    header
    check_dependencies
    require_root_or_sudo
    show_all_disks
    select_device
    confirm_device
    unmount_partitions
    select_mode
    download_ventoy
    install_ventoy
    show_result
}

main "$@"
