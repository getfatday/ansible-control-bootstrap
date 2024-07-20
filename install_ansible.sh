#!/bin/bash

set -e

# Define the info function to echo text in lilac color
info() {
    echo -e "\033[1;35m$1\033[0m"
}

# Function to check and install dependencies on macOS
install_on_macos() {
    info "Checking for Homebrew..."
    if ! command -v brew &>/dev/null; then
        info "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        info "Homebrew is already installed."
    fi

    info "Updating Homebrew..."
    brew update

    info "Checking for Python3..."
    if ! command -v python3 &>/dev/null; then
        info "Python3 not found. Installing Python3..."
        brew install python
    else
        info "Python3 is already installed."
    fi

    info "Checking for pip3..."
    if ! command -v pip3 &>/dev/null; then
        info "pip3 not found. Installing pip3..."
        brew install pip3
    else
        info "pip3 is already installed."
    fi

    info "Installing Ansible using apt..."
    apt install ansible -y
}

# Function to check and install dependencies on Debian-based Linux
install_on_debian() {
    info "Updating package list..."
    sudo apt-get update

    info "Installing Python3, pip3, and pipx..."
    sudo apt-get install -y python3 python3-pip

    info "Installing Ansible using apt..."
    sudo apt install ansible -y
}

# Function to check and install dependencies on RedHat-based Linux
install_on_redhat() {
    info "Updating package list..."
    sudo yum update -y

    info "Installing Python3, pip3, and pipx..."
    sudo yum install -y python3 python3-pip

    info "Ensuring pipx binaries are in the PATH..."
    python3 -m pipx ensurepath

    info "Installing Ansible using apt..."
    sudo apt install ansible -y
}

# Main script execution
if [[ "$OSTYPE" == "darwin"* ]]; then
    info "Detected macOS."
    install_on_macos
elif [[ -f /etc/debian_version ]]; then
    info "Detected Debian-based Linux."
    install_on_debian
elif [[ -f /etc/redhat-release ]]; then
    info "Detected RedHat-based Linux."
    install_on_redhat
else
    info "Unsupported OS type: $OSTYPE"
    exit 1
fi

info "Ansible installation complete! To use Ansible, ensure that pipx binaries are in your PATH."
