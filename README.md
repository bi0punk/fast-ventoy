# fast-ventoy

Interactive bash script to quickly create a bootable USB drive with Ventoy on Linux. Automates USB device detection, downloading the latest Ventoy release, and installation.

## Stack

Bash

## Usage

```bash
chmod +x fast-ventoy.sh
sudo ./fast-ventoy.sh
```

The script will:
1. Detect connected USB devices via `lsblk`
2. Prompt for device selection
3. Download the latest Ventoy release from GitHub
4. Install/update Ventoy on the selected device

## License

MIT
