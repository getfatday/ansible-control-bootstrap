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

# Fix zsh directory permissions that cause brew doctor warnings
fix_zsh_permissions() {
    local zsh_dirs=("/usr/local/share/zsh" "/usr/local/share/zsh/site-functions")
    for dir in "${zsh_dirs[@]}"; do
        if [[ -d "$dir" ]] && [[ ! -w "$dir" ]]; then
            info "Fixing permissions on $dir..."
            sudo chmod g-w "$dir"
            sudo chown "$(whoami)" "$dir"
        fi
    done
}

# Function to check and install dependencies on macOS
install_on_macos() {
    info "Checking for Homebrew..."
    if ! command -v brew &>/dev/null; then
        info "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Homebrew installer prints eval instructions; ensure brew is in PATH
        if [[ -x "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        info "Homebrew is already installed."
    fi

    # Derive paths from the actual Homebrew installation
    local homebrew_prefix=$(brew --prefix)
    local mas_path="$homebrew_prefix/bin/mas"
    info "Homebrew prefix: $homebrew_prefix"

    info "Updating Homebrew..."
    brew update

    # Fix zsh directory permissions that Homebrew operations can leave misconfigured
    fix_zsh_permissions

    info "Installing Ansible..."
    brew install ansible

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
    ansible-galaxy install git+https://github.com/getfatday/ansible-role-dotmodules.git

    # Accept Xcode license if needed (for MAS apps)
    # Only attempt if full Xcode is installed (not just Command Line Tools)
    if [[ -d "/Applications/Xcode.app" ]] && command -v xcodebuild &>/dev/null; then
        if ! xcodebuild -license check &>/dev/null; then
            warning "Xcode license needs to be accepted for Mac App Store apps..."
            info "Accepting Xcode license..."
            sudo xcodebuild -license accept
        else
            info "Xcode license already accepted."
        fi
    else
        info "Xcode not installed (Command Line Tools only) — skipping license check."
        info "Install Xcode from the App Store if you need Mac App Store app management."
    fi

    # Export paths for downstream use
    export MAS_PATH="$mas_path"
    export HOMEBREW_PREFIX="$homebrew_prefix"
    success "Homebrew paths configured: MAS_PATH=$mas_path, HOMEBREW_PREFIX=$homebrew_prefix"
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

        local homebrew_prefix=$(brew --prefix)
        local mas_path="$homebrew_prefix/bin/mas"

        cat > sample-dotfiles.yml << EOF
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
    mas_path: "$mas_path"
  roles:
    - ansible-role-dotmodules
EOF

        success "Sample playbook created: sample-dotfiles.yml"
        info "MAS path configured: $mas_path"
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
