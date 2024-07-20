# Ansible Control Node Bootstrap

This repository contains a script to bootstrap an Ansible control node on macOS and major Linux distributions. The script will install Ansible in a manner similar to Homebrew.

## Installation

To install Ansible using this script, execute the following command in your terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/getfatday/ansible-control-bootstrap/main/install_ansible.sh)"
```

## Supported Operating Systems

- **macOS**
- **Debian-based Linux distributions** (e.g., Ubuntu, Debian)
- **RedHat-based Linux distributions** (e.g., CentOS, Fedora, RHEL)

## Script Details

The script performs the following steps:

1. **macOS**:
    - Checks for Homebrew and installs it if not present.
    - Updates Homebrew.
    - Installs Ansible using Homebrew.

2. **Debian-based Linux**:
    - Updates the package list.
    - Installs necessary dependencies.
    - Adds the Ansible PPA (Personal Package Archive).
    - Installs Ansible using `apt-get`.

3. **RedHat-based Linux**:
    - Installs the EPEL (Extra Packages for Enterprise Linux) repository.
    - Installs Ansible using `yum`.

## Contributing

Feel free to submit issues and pull requests if you encounter any problems or have suggestions for improvements.
