#!/bin/bash

set -e

# Define the info function to echo text in lilac color
info() {
    echo -e "\033[1;35m$1\033[0m"
}

# Define the success function to echo text in green color
success() {
    echo -e "\033[1;32m$1\033[0m"
}

# Define the warning function to echo text in yellow color
warning() {
    echo -e "\033[1;33m$1\033[0m"
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
        brew install python
    else
        info "pip3 is already installed."
    fi

    info "Installing Ansible using pip3..."
    pip3 install ansible

    # ansible-role-dotmodules specific setup
    info "Setting up ansible-role-dotmodules dependencies..."
    
    # Install GNU Stow if missing
    if ! command -v stow &>/dev/null; then
        info "Installing GNU Stow..."
        brew install stow
    else
        info "GNU Stow is already installed."
    fi

    # Install required Ansible collections
    info "Installing required Ansible collections..."
    ansible-galaxy collection install geerlingguy.mac

    # Accept Xcode license if needed (for MAS apps)
    if command -v xcodebuild &>/dev/null; then
        if ! xcodebuild -license check &>/dev/null; then
            warning "Xcode license needs to be accepted for Mac App Store apps..."
            info "Accepting Xcode license..."
            sudo xcodebuild -license accept
        else
            info "Xcode license already accepted."
        fi
    fi

    # Set up ARM64 Homebrew path detection
    if [[ $(uname -m) == "arm64" ]] || [[ $(arch) == "arm64" ]]; then
        info "Detected ARM64 architecture - setting up Homebrew paths..."
        export MAS_PATH="/opt/homebrew/bin/mas"
        success "ARM64 Homebrew paths configured."
    fi
}

# Function to check and install dependencies on Debian-based Linux
install_on_debian() {
    info "Updating package list..."
    sudo apt-get update

    info "Installing Python3 and pip3..."
    sudo apt-get install -y python3 python3-pip

    info "Installing Ansible using apt..."
    sudo apt install ansible -y
}

# Function to check and install dependencies on RedHat-based Linux
install_on_redhat() {
    info "Updating package list..."
    sudo yum update -y

    info "Installing Python3 and pip3..."
    sudo yum install -y python3 python3-pip

    info "Installing Ansible using yum..."
    sudo yum install ansible -y
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

# Function to create a sample ansible-role-dotmodules playbook
create_sample_playbook() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        info "Creating sample ansible-role-dotmodules playbook..."
        
        cat > sample-dotfiles.yml << 'EOF'
---
# Sample ansible-role-dotmodules playbook
- name: Deploy dotfiles using ansible-role-dotmodules
  hosts: localhost
  vars:
    dotmodules:
      repo: "file://{{ playbook_dir }}/../modules"
      dest: "{{ ansible_env.HOME }}/.dotmodules"
      install:
        - shell
        - git
        - editor
    # Configure MAS path for ARM64 Macs
    mas_path: "{{ '/opt/homebrew/bin/mas' if ansible_architecture == 'arm64' else '/usr/local/bin/mas' }}"
  roles:
    - ansible-role-dotmodules
EOF

        success "Sample playbook created: sample-dotfiles.yml"
        info "To use: ansible-playbook -i localhost, sample-dotfiles.yml"
    fi
}

# Create sample playbook
create_sample_playbook

success "Ansible installation complete!"
info "Next steps:"
info "1. Install the ansible-role-dotmodules role:"
info "   ansible-galaxy install git+https://github.com/getfatday/ansible-role-dotmodules.git"
info "2. Create your dotfiles modules in a 'modules/' directory"
info "3. Run your playbook: ansible-playbook -i localhost, sample-dotfiles.yml"
