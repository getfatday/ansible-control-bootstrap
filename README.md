# Ansible Control Node Bootstrap

This repository contains a script to bootstrap an Ansible control node on macOS and major Linux distributions, with special support for `ansible-role-dotmodules`. The script will install Ansible and all required dependencies for dotfile management.

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
    - Installs Ansible using pip3.
    - **ansible-role-dotmodules specific setup:**
        - Installs GNU Stow for dotfile deployment
        - Installs required Ansible collections (geerlingguy.mac)
        - Accepts Xcode license for Mac App Store apps
        - Configures ARM64 Homebrew paths
        - Creates a sample playbook

2. **Debian-based Linux**:
    - Updates the package list.
    - Installs necessary dependencies.
    - Adds the Ansible PPA (Personal Package Archive).
    - Installs Ansible using `apt-get`.

3. **RedHat-based Linux**:
    - Installs the EPEL (Extra Packages for Enterprise Linux) repository.
    - Installs Ansible using `yum`.

## ansible-role-dotmodules Integration

This script is specifically designed to work with `ansible-role-dotmodules` and handles all the common setup issues:

- ✅ **ARM64 Homebrew path detection** - Automatically configures correct MAS paths
- ✅ **Xcode license acceptance** - Required for Mac App Store app installation
- ✅ **Collection installation** - Installs geerlingguy.mac collection
- ✅ **GNU Stow installation** - Required for dotfile deployment
- ✅ **Sample playbook creation** - Provides a working example

## Quick Start with ansible-role-dotmodules

After running the bootstrap script:

```bash
# Install the ansible-role-dotmodules role
ansible-galaxy install git+https://github.com/getfatday/ansible-role-dotmodules.git

# Create your dotfiles modules
mkdir -p modules/{shell,git,editor}
# Add your config.yml files and dotfiles

# Run the sample playbook
ansible-playbook -i localhost, sample-dotfiles.yml
```

## Contributing

Feel free to submit issues and pull requests if you encounter any problems or have suggestions for improvements.
