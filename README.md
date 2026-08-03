# AmneziaWG kernel module (patched fork)

A patched fork of [amneziawg-linux-kernel-module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module) with bug fixes, performance improvements, and kernel compatibility patches for Linux 5.4 through 6.19+.

## Quick start

```shell
# Install prerequisites (Debian/Ubuntu example, see docs/INSTALL.md for other distros)
sudo apt install -y build-essential dkms linux-headers-$(uname -r) linux-headers-generic

# Clone and install
git clone https://github.com/vados-dev/amneziawg-linux-kernel-module.git
cd amneziawg-linux-kernel-module-vds/src
sudo make dkms-install
sudo dkms install "amneziawg/$(make print-version)"

# Load
sudo modprobe amneziawg
```

## Documentation

| Document | Description |
|---|---|
| **[Installation](docs/INSTALL.md)** | Prerequisites and build instructions for all supported distros |
| **[Configuration](docs/CONFIGURATION.md)** | AWG parameter reference (Jc, Jmin, Jmax, S1–S4, H1–H4) |
| **[Troubleshooting](docs/TROUBLESHOOTING.md)** | Debug logging, DKMS rebuild, updating, common issues |
| **[Changelog](docs/CHANGELOG.md)** | All changes from upstream |

## Companion library

## License

GPL-2.0 — see [COPYING](COPYING).
