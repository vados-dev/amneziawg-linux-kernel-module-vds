# AmneziaWG kernel module (VDS)

[Русский](README.md) | [English](README_en.md)

VDS fork of [amneziawg-linux-kernel-module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module).
Current VDS version: `3.1.20260812-vds`.

## Table of contents

- [Installation](#installation)
  - [Ubuntu](#ubuntu)
  - [Debian](#debian)
  - [Linux Mint](#linux-mint)
  - [RHEL/CentOS/SUSE/Fedora Core](#rhelcentossusefedora-core)
- [Manual build](#manual-build)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Installation

### Ubuntu

Open `Terminal` and proceed with the following instructions:

1. (Optionally) Upgrade your system to the latest packages, including the latest available kernel, by running `apt-get full-upgrade`.
   A reboot is required after the kernel upgrade.
2. Ensure that source repositories are configured for APT — run `vi /etc/apt/sources.list` and make sure that at least one line
   starting with `deb-src` is present and uncommented.
3. Install pre-requisites — run `sudo apt install -y software-properties-common python3-launchpadlib gnupg2 linux-headers-$(uname -r)`.
4. Run `sudo add-apt-repository ppa:amnezia/ppa`.
5. Finally, execute `sudo apt-get install -y amneziawg`.

### Debian

Open `Terminal` and do the next steps:

1. (Optionally) Upgrade your system to the latest packages, including the latest available kernel, by running `apt-get full-upgrade`.
   A reboot is required after the kernel upgrade.
2. Ensure that source repositories are configured for APT — run `vi /etc/apt/sources.list` and make sure that at least one line
   starting with `deb-src` is present and uncommented.
3. Execute the following commands:
```shell
sudo apt install -y software-properties-common python3-launchpadlib gnupg2 linux-headers-$(uname -r)
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 57290828
echo "deb https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | sudo tee -a /etc/apt/sources.list
echo "deb-src https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get install -y amneziawg
```

### Linux Mint

Open `Software Sources` and make sure that `Source code repositories` (under `Optional Sources`) are enabled.

Proceed to the `PPAs` section and add the `ppa:amnezia/ppa` PPA repository, then save the configuration and rebuild the `apt` cache.

After that, open `Terminal` and run:

```shell
sudo apt-get install -y amneziawg
```

### RHEL/CentOS/SUSE/Fedora Core

*If you use a release that does not have DKMS support out of the box, you may need to install [EPEL](https://docs.fedoraproject.org/en-US/epel/#_quickstart) first.*

Open `Terminal` and run:

```shell
sudo dnf copr enable tigro/amneziawg
sudo dnf install amneziawg-dkms amneziawg-tools
```

Before installation, it is strictly recommended to upgrade your system kernel to the latest available version and perform
the reboot afterwards.

## Manual build

You may need to install kernel headers and/or build essentials packages before running the following steps.

1. In Terminal:
    ```shell
    git clone https://github.com/vados-dev/amneziawg-linux-kernel-module-vds.git
    cd amneziawg-linux-kernel-module-vds/src
    ```

2. Now, if you run modern Linux with kernel version 5.6+, you need to download your kernel's source from anywhere possible
   and link the resulting tree to the `kernel` symlink:

    ```shell
    ln -s /path/to/kernel/source kernel
    ```

   Please note that you need to find and provide the full kernel source tree, not only headers.
   **If you run on a legacy kernel (<5.6), you do not need to perform this step.**

3. Now perform build and installation:
    ```shell
    make
    sudo make install
    ```

   Or, on a capable system, you may want to use DKMS for this:
    ```shell
    sudo make dkms-install
    ```

   and
    ```shell
    sudo dkms add -m amneziawg -v $(make print-version)
    sudo dkms build -m amneziawg -v $(make print-version)
    sudo dkms install -m amneziawg -v $(make print-version)
    ```
   or
    ```shell
    sudo dkms install "amneziawg/$(make print-version)"
    ```
   check:
    ```shell
    sudo modprobe amneziawg
    ```

## Configuration

> [!IMPORTANT]
> All parameters must be the same between Client and Server, except for Jc, Jmin, and Jmax — these may vary.

- Jc — 1 ≤ Jc ≤ 128; recommended range is from 4 to 12 inclusive
- Jmin — Jmax > Jmin < 1280*; recommended value is 8
- Jmax — Jmin < Jmax ≤ 1280*; recommended value is 80
- S1 — S1 ≤ 1132* (1280* - 148 = 1132); S1 + 56 ≠ S2; recommended range is from 15 to 150 inclusive
- S2 — S2 ≤ 1188* (1280* - 92 = 1188); recommended range is from 15 to 150 inclusive
- H1/H2/H3/H4 — must be unique among each other; recommended range is from 5 to 2147483647 inclusive

`* Assuming a basic internet connection with an MTU value of 1280.`

## Troubleshooting

> [!TIP]
> Please check the [Ubuntu Server documentation](https://documentation.ubuntu.com/server/how-to/wireguard-vpn/troubleshooting) for more troubleshooting steps.

### Enable debug logging

To get more details, you can enable the dynamic debug feature for the module:

```shell
echo "module amneziawg +p" | sudo tee /sys/kernel/debug/dynamic_debug/control
```

This will log messages to dmesg, which can be watched live with:
```shell
dmesg -wT
```

### Low space on `/tmp` filesystem

Most installation instructions above assume that you have enough space in the system's `/tmp` partition (as the setup script needs
to manipulate the kernel's source tree, which is pretty huge).

If you cannot afford enough space in your `/tmp`, you may override the temporary directory by setting the `AWG_TEMP_DIR` environment variable
before the installation:

```shell
export AWG_TEMP_DIR="/home/ubuntu/tmp"
```

This setting should persist for the future and will not require repeating.

### Kernel source tree could not be found automatically

In some rare cases, the setup script may not find your kernel's source tree automatically. You may find the appropriate sources yourself
and then link them to the DKMS module sources, e.g.

```shell
ln -s /path/to/your/kernel/sources /usr/src/amneziawg-3.1.20260812-vds/kernel
```

Reinstall the package thereafter and you should get everything working.

Should you upgrade your kernel in the future, please remember that you may also need to refresh the source tree and update symlinks.

## License

This project is released under the [GPLv2](COPYING).
