# Raspberry Pi bootstrap example with cloud-init and Ansible

This repository is an example Raspberry Pi bootstrap project for automating first boot and hardening with cloud-init and Ansible.

It is intended for Raspberry Pi 4 and Raspberry Pi 5 systems running Ubuntu 26.04 or Raspberry Pi OS Trixie in a local wired lab network:

- Raspberry Pi 4 and Raspberry Pi 5
- Ubuntu 26.04
- Raspberry Pi OS Trixie
- local wired networking on a private LAN

The example requires local customization before use. Update the SSH keys, IP addresses, and network interface names in the cloud-init and Ansible files to match your environment. The committed values are examples only and are not a universal image template or production-ready configuration.

The project does the following:

- sets the hostname from the Pi serial number
- creates a dedicated `automation` user with passwordless sudo
- enables SSH and loads an SSH key
- disables Wi-Fi and Bluetooth by default
- applies a few Raspberry Pi tuning changes for boot/config stability
- installs common utilities and applies a hardened SSH configuration
- sets a basic firewall with UFW
- runs the same provisioning flow across a small Ansible inventory

---

## Repository layout

```text
.
├── ansible.cfg
├── handlers.yml
├── inventory
├── main.yml
├── README.md
├── cloud-init/
│   ├── apply-user-data-to-sd-card.sh
│   ├── network-config-pi01
│   ├── network-config-pi01-ubuntu
│   ├── network-config-pi02
│   ├── network-config-pi02-ubuntu
│   ├── user-data
│   └── user-data-ubuntu
├── group_vars/
│   ├── all.yml
│   └── vault.yml
└── roles/
    ├── common/
    │   ├── tasks/
    │   │   └── main.yml
    │   └── templates/
    │       ├── custom_aliases.sh.j2
    │       └── fstab.j2
    └── firewall/
        └── tasks/
            └── main.yml
```

---

## What the cloud-init bootstrap does

The files in the `cloud-init/` folder are copied onto the boot partition of the SD card or USB boot media before the Pi is powered on.

The current bootstrap config does these things:

- sets the timezone to `Europe/Berlin`
- configures locale and keyboard layout
- sets the hostname to a value based on the Pi serial number
- creates the `automation` user with an SSH key
- enables SSH in the boot partition
- runs a few setup commands at first boot
- installs a minimal set of packages

The actual boot-time script is:

```bash
cd cloud-init/
./apply-user-data-to-sd-card.sh
```

Leave `NETWORK_FILE` unset to use the default network behavior, or set it to a matching example before running the script to install a static network configuration:

```bash
NETWORK_FILE=network-config-pi01 ./apply-user-data-to-sd-card.sh
```

For Ubuntu, the script automatically selects the `-ubuntu` user-data file and, when `NETWORK_FILE` is set, the corresponding `-ubuntu` network configuration file.

This script detects whether the card is using a Raspberry Pi OS layout (`/Volumes/bootfs`) or an Ubuntu layout (`/Volumes/system-boot`) and copies the matching cloud-init files into place. It also injects `cloud-init=sources:NoCloud` for Raspberry Pi OS when needed.

---

## Flashing and preparing the OS image

### Method 1: direct image write on macOS with dd (recommended)

This is the primary method for this repo. It works well when you want to image the card directly from a local `.img` file on a Mac and then inject the cloud-init seed files afterward.

```bash
diskutil list
sudo diskutil unmountDisk /dev/diskN
sudo dd if=/path/to/your-image.img of=/dev/rdiskN bs=1m
sync
```

Replace `N` with the target disk number, such as `disk4` or `disk6`.

Important: do not eject the card after writing the image. The boot partition must still be mounted so the script can copy the cloud-init files. Re-insert or remount the media if needed, then run:

```bash
cd cloud-init/
./apply-user-data-to-sd-card.sh
```

The script detects the active boot mount, writes `user-data` and the matching network config to the correct partition, and then ejects the full removable disk rather than only the partition. If the volume is not mounted or the script exits early, eject the card manually with the device path instead:

```bash
diskutil eject /dev/diskN
```

Replace `N` with the actual SD card or SSD disk number, such as `disk4` or `disk6`.

### Method 2: Raspberry Pi Imager (secondary option)

If you prefer to use Raspberry Pi Imager, keep the OS installation as stock as possible and do not set the user/password in the imaging wizard. After the image is written, mount the boot partition and run:

```bash
cd cloud-init/
./apply-user-data-to-sd-card.sh
```

This is a good alternative, but the direct `dd` workflow is the first-class method described here.

---

## Booting the Pi

The setup in this repo assumes a consistent lab layout and a matching SSH key. Before booting a node, verify the following values are still correct for your environment:

- the correct static IP in the chosen network config file
- the correct wired interface name for the target OS
- the `automation` user SSH public key in the cloud-init file
- the matching private key path in the inventory

After the prepared card is inserted into the Pi and powered on:

- the Pi will boot with cloud-init enabled
- the hostname is generated from the serial number
- the SSH key is installed for the `automation` user
- the box will be ready for Ansible orchestration over SSH

Example SSH connection:

```bash
ssh automation@192.168.1.11
```

The inventory file currently contains nodes like this:

```ini
[rpi_nodes]
node1 ansible_host=192.168.1.11
node2 ansible_host=192.168.1.12

[all:vars]
ansible_user=automation
ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

---

## Running the Ansible playbook

The project expects a working Ansible connection to the Pi nodes and a valid SSH key. The playbook is started with:

```bash
ansible-playbook -i inventory main.yml --ask-vault-pass
```

This playbook includes the roles:

- `common`
- `firewall`

The `common` role performs system-level hardening and package setup, including:

- firmware and boot configuration adjustments
- fstab template deployment
- journald tuning
- SSH configuration hardening
- package installation
- custom shell aliases

The `firewall` role enables UFW and allows only SSH traffic by default.

> `group_vars/vault.yml` is an example placeholder. Create or edit it with `ansible-vault create group_vars/vault.yml` or `ansible-vault edit group_vars/vault.yml` before storing encrypted values for your environment.

---

## Notes

- The examples are intentionally tuned for a Raspberry Pi 4/5 lab using Ubuntu 26.04 and Raspberry Pi OS Trixie.
- Interface names, static IPs, and SSH keys are examples and must be adjusted for your actual hardware and network.
- If you plan to use a different hostname or network layout, adjust the cloud-init templates and the inventory before booting the hosts.

---

## Typical flow

1. Prepare the OS image and boot partition.
2. Copy the cloud-init bootstrap files with the provided script.
3. Insert the card into the Pi and boot it.
4. Verify SSH access as the `automation` user.
5. Run the Ansible playbook to harden and configure the node.
