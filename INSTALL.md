
https://github.com/Advanced-WG/amneziawg-linux-kernel-module-awg/blob/main/docs/TROUBLESHOOTING.md

# Fedora/RHEL:
sudo dnf install -y kernel-devel-$(uname -r)
Then rebuild:

sudo dkms install "amneziawg/$(dkms status | grep amneziawg | awk -F'[/, ]+' '{print $2}' | head -1)" -k $(uname -r)
To prevent this in the future, install the headers meta-package . see Installation.

Updating to a new version
cd amneziawg-linux-kernel-module-vds/src
git pull

# Remove old DKMS registration:
sudo dkms remove "amneziawg/$(dkms status | grep amneziawg | awk -F'[/, ]+' '{print $2}' | head -1)" --all

# Install new version:
sudo make dkms-install
sudo dkms install "amneziawg/$(make print-version)"

