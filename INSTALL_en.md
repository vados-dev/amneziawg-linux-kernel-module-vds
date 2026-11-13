# VDS installation and upgrade

[Русский](INSTALL.md) | [English](INSTALL_en.md)

Current VDS version: `3.1.20260812-vds`.

## Requirements

- Kernel headers for the running kernel.
- DKMS.
- Build tools: `make`, `gcc`, `git`.

## Fedora/RHEL/CentOS

Install the kernel headers and rebuild the module:

```shell
sudo dnf install -y kernel-devel-$(uname -r)
sudo dkms install "amneziawg/$(dkms status | grep amneziawg | awk -F'[/, ]+' '{print $2}' | head -1)" -k $(uname -r)
```

To avoid this in the future, install the kernel headers meta-package.

## Upgrade to a new version

```shell
cd amneziawg-linux-kernel-module-vds/src
git pull

# Remove the old DKMS registration:
sudo dkms remove "amneziawg/$(dkms status | grep amneziawg | awk -F'[/, ]+' '{print $2}' | head -1)" --all

# Install the new version:
sudo make dkms-install
sudo dkms install "amneziawg/$(make print-version)"
```

## Verify

```shell
modinfo amneziawg | grep -E 'filename|version'
sudo modprobe amneziawg
```
