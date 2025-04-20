#!/bin/bash

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

A utility to manage development environment setup for Windows WSL (Ubuntu/Debian).

Options:
    -h, --help          Show this help message
    -c, --certification Check and notify what tools are missing
    -i, --install       Install all required tools

Examples:
    $0 --help           # Show this help message
    $0 --certification  # Check what tools are missing
    $0 --install       # Install all required tools
    $0 -c -i           # Check and install in one command

This script will manage the installation and verification of:
    - apt packages
    - k9s
    - jq
    - Docker
    - Google Cloud SDK
    - gkc.sh utility
    - Windows apps via Windows package managers (through PowerShell)
      - Slack
      - Twingate
      - NordPass
      - Cursor
      - DBeaver Community
      - Visual Studio Code
    - Automox (verification only)
    - SentinelOne (verification only)

Note: This script is intended for Windows with WSL (Ubuntu/Debian) only.
EOF
    exit 1
}

# Function to check if a Windows app is installed (using PowerShell)
check_windows_app() {
    local app_name="$1"
    local display_name="$2"
    
    # Use PowerShell to check if app is installed
    if powershell.exe -Command "Get-AppxPackage -Name *$app_name* 2>null" | grep -q "PackageFullName"; then
        echo "[OK] $display_name is installed (Microsoft Store)"
        return 0
    elif powershell.exe -Command "Get-ItemProperty HKLM:\\Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\* | Where-Object DisplayName -like '*$app_name*' 2>null" | grep -q "DisplayName"; then
        echo "[OK] $display_name is installed (Windows)"
        return 0 
    else
        echo "[MISSING] $display_name is not installed"
        return 1
    fi
}

# Function to check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "[MISSING] $2 is not installed"
        return 1
    else
        echo "[OK] $2 is installed"
        return 0
    fi
}

# Function to check if apt package is installed
check_apt_package() {
    if ! dpkg -l $1 &>/dev/null; then
        echo "[MISSING] $2 is not installed"
        return 1
    else
        echo "[OK] $2 is installed"
        return 0
    fi
}

# Function to check if SentinelOne is properly installed (on Windows)
check_sentinelone() {
    if powershell.exe -Command "Get-Service -Name 'SentinelAgent' 2>null" | grep -q "Running"; then
        echo "[OK] SentinelOne is installed and running"
        return 0
    else
        echo "[MISSING] SentinelOne is not installed or not running"
        return 1
    fi
}

# Function to check if Automox is properly installed (on Windows)
check_automox() {
    # First check for the service
    if powershell.exe -Command "Get-Service -Name 'Automox' 2>null" | grep -q "Running"; then
        echo "[OK] Automox is installed and running (service)"
        return 0
    # Then check for the process
    elif powershell.exe -Command "Get-Process -Name 'Automox*' 2>null" | grep -q "Handles"; then
        echo "[OK] Automox is installed and running (process)"
        return 0
    else
        echo "[MISSING] Automox is not installed or not running"
        return 1
    fi
}

# Function to perform certification
do_certification() {
    echo "Checking required tools..."

    local missing_tools=0
    local security_warnings=0

    # Check OS
    if ! grep -q "Microsoft" /proc/version; then
        echo "[MISSING] This script requires WSL (Windows Subsystem for Linux). Current OS does not appear to be WSL."
        exit 1
    else
        echo "[OK] Running on WSL"
    fi

    echo -e "\nCHECKING DEVELOPMENT TOOLS:"
    # Check apt update status
    if [ "$(find /var/lib/apt/lists -maxdepth 0 -type d -mtime +7)" != "" ]; then
        echo "[WARNING] apt package lists may be outdated. Consider running 'sudo apt update'"
    fi

    # Check command line tools
    check_command "k9s" "k9s" || ((missing_tools++))
    check_command "jq" "jq" || ((missing_tools++))
    check_command "gcloud" "Google Cloud SDK" || ((missing_tools++))
    check_command "gh" "GitHub CLI" || ((missing_tools++))
    check_command "docker" "Docker CLI" || ((missing_tools++))

    echo -e "\nCHECKING WINDOWS APPLICATIONS:"
    # Check Windows applications
    check_windows_app "Slack" "Slack" || ((missing_tools++))
    check_windows_app "Twingate" "Twingate" || ((missing_tools++))
    check_windows_app "Cursor" "Cursor" || ((missing_tools++))
    check_windows_app "DBeaver" "DBeaver Community" || ((missing_tools++))
    check_windows_app "Microsoft Visual Studio Code" "Visual Studio Code" || ((missing_tools++))

    echo -e "\nCHECKING SECURITY TOOLS:"
    # Check security applications
    check_sentinelone || ((missing_tools++))
    check_automox || ((missing_tools++))
    check_windows_app "NordPass" "NordPass" || ((missing_tools++))

    # Check for TeamViewer (should not be installed)
    if powershell.exe -Command "Get-ItemProperty HKLM:\\Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\* | Where-Object DisplayName -like '*TeamViewer*' 2>null" | grep -q "DisplayName"; then
        echo "${RED}WARNING: TeamViewer is installed and should be removed for security reasons${RESET}"
        ((security_warnings++))
    fi

    # Check gkc.sh
    echo -e "\nCHECKING UTILITIES:"
    if [ ! -f ${HOME}/google-cloud-sdk/bin/gkc.sh ]; then
        echo "[MISSING] gkc.sh is not installed"
        ((missing_tools++))
    else
        echo "[OK] gkc.sh is installed"
    fi

    echo -e "\nSUMMARY:"
    if [ $missing_tools -eq 0 ] && [ $security_warnings -eq 0 ]; then
        echo "[OK] All tools are installed and no security warnings!"
        return 0
    else
        if [ $missing_tools -gt 0 ]; then
            echo "[MISSING] Found $missing_tools missing tool(s)"
            echo "Run with --install to install missing tools"
        fi
        if [ $security_warnings -gt 0 ]; then
            echo "${RED}WARNING: Found $security_warnings security warning(s)${RESET}"
            echo "Please address security warnings before proceeding"
        fi
        return 1
    fi
}

# Function to install a Windows application using winget
install_windows_app() {
    local app_name="$1"
    local display_name="$2"
    local winget_id="$3"
    
    echo "Installing $display_name via Windows package manager..."
    powershell.exe -Command "winget install -e --id $winget_id"
}

# Function to perform installation
do_installation() {
    echo "Starting WSL laptop setup..."

    # Check if running as root or via sudo
    if [ "$(id -u)" = "0" ]; then
        echo "[ERROR] This script should not be run as root or with sudo"
        echo "Please run it as a regular user."
        exit 1
    fi

    # Update repositories
    echo "Updating package repositories..."
    sudo apt update

    # Install command line tools
    if ! command -v k9s &> /dev/null; then
        echo "Installing k9s..."
        # Using direct installation as it's not in default repositories
        curl -sL https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz | tar xz -C /tmp
        sudo mv /tmp/k9s /usr/local/bin/
    fi

    if ! command -v jq &> /dev/null; then
        echo "Installing jq..."
        sudo apt install -y jq
    fi

    if ! command -v gh &> /dev/null; then
        echo "Installing GitHub CLI..."
        sudo apt install -y gh
        echo "Please run 'gh auth login' to authenticate with GitHub"
    fi

    # Install Docker CLI if not present
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        # For WSL 2, we install Docker CLI and use the Windows Docker Desktop
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt update
        sudo apt install -y docker-ce-cli
        
        echo "NOTE: Docker Desktop must be installed on Windows and configured for WSL integration"
        echo "You can install Docker Desktop on Windows with:"
        echo "powershell.exe -Command \"winget install -e --id Docker.DockerDesktop\""
    fi
    
    # Install Windows applications if not present
    echo "Checking and installing Windows applications..."
    echo "NOTE: These installations will happen in Windows, not WSL"
    
    # Slack
    if ! check_windows_app "Slack" "Slack" &>/dev/null; then
        install_windows_app "Slack" "Slack" "SlackTechnologies.Slack"
    fi
    
    # Twingate
    if ! check_windows_app "Twingate" "Twingate" &>/dev/null; then
        install_windows_app "Twingate" "Twingate" "Twingate.Twingate"
    fi
    
    # NordPass
    if ! check_windows_app "NordPass" "NordPass" &>/dev/null; then
        install_windows_app "NordPass" "NordPass" "NordSecurity.NordPass"
    fi
    
    # Cursor
    if ! check_windows_app "Cursor" "Cursor" &>/dev/null; then
        install_windows_app "Cursor" "Cursor" "AnthonyKong.Cursor"
    fi
    
    # DBeaver Community
    if ! check_windows_app "DBeaver" "DBeaver Community" &>/dev/null; then
        install_windows_app "DBeaver" "DBeaver Community" "dbeaver.dbeaver"
    fi

    # Visual Studio Code
    if ! check_windows_app "Microsoft Visual Studio Code" "Visual Studio Code" &>/dev/null; then
        install_windows_app "Microsoft Visual Studio Code" "Visual Studio Code" "Microsoft.VisualStudioCode"
    fi

    # Install Google Cloud SDK
    if ! command -v gcloud &> /dev/null; then
        echo "Installing Google Cloud SDK..."

        # Create home directory
        cd "${HOME}"

        # Use the official installer script (most reliable method)
        echo "Downloading and installing Google Cloud SDK using official installer..."
        curl -fsSL https://sdk.cloud.google.com | bash -x -- --disable-prompts

        # Check if installation was successful
        if [ -d "${HOME}/google-cloud-sdk" ]; then
            echo "Google Cloud SDK installation successful"
            
            # Configure shell
            echo "Configuring shell for Google Cloud SDK..."
            echo "source '${HOME}/google-cloud-sdk/path.bash.inc'" >> "${HOME}/.bashrc"
            echo "source '${HOME}/google-cloud-sdk/completion.bash.inc'" >> "${HOME}/.bashrc"
            
            # Initialize gcloud
            echo "Initializing Google Cloud SDK..."
            "${HOME}/google-cloud-sdk/bin/gcloud" init
        else
            echo "ERROR: Google Cloud SDK installation failed. Please try again or install manually."
            echo "Manual installation instructions: https://cloud.google.com/sdk/docs/install"
        fi
    fi
    
    # Install kubectl and GKE auth plugin components
    cd "${HOME}"
    
    echo "Installing kubectl via gcloud components..."
    "${HOME}/google-cloud-sdk/bin/gcloud" components install kubectl --quiet

    echo "Installing gke-gcloud-auth-plugin for kubectl authentication with GKE..."
    "${HOME}/google-cloud-sdk/bin/gcloud" components install gke-gcloud-auth-plugin --quiet

    # Verify installations
    if command -v "${HOME}/google-cloud-sdk/bin/kubectl" &> /dev/null; then
        echo "[OK] kubectl installed successfully"
    else
        echo "[WARNING] kubectl installation may have failed"
    fi

    if [ -f "${HOME}/google-cloud-sdk/bin/gke-gcloud-auth-plugin" ]; then
        echo "[OK] gke-gcloud-auth-plugin installed successfully"
    else
        echo "[WARNING] gke-gcloud-auth-plugin installation may have failed"
    fi

    # Create kubectl symlink in /usr/local/bin for convenience
    sudo ln -sf "${HOME}/google-cloud-sdk/bin/kubectl" /usr/local/bin/kubectl

    # Install gkc.sh
    if [ ! -f "${HOME}/google-cloud-sdk/bin/gkc.sh" ]; then
        echo "Installing gkc.sh..."
        "${HOME}/google-cloud-sdk/bin/gsutil" cp gs://adh-tools/gkc.sh "${HOME}/google-cloud-sdk/bin/"
        chmod u+x "${HOME}/google-cloud-sdk/bin/gkc.sh"
        sudo ln -sf "${HOME}/google-cloud-sdk/bin/gkc.sh" /usr/local/bin/gkc.sh
    fi

    # Check for TeamViewer and warn if present
    if powershell.exe -Command "Get-ItemProperty HKLM:\\Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\* | Where-Object DisplayName -like '*TeamViewer*' 2>null" | grep -q "DisplayName"; then
        echo -e "\nWARNING: TeamViewer is installed and should be removed for security reasons"
        echo "Please uninstall TeamViewer manually from Windows using:"
        echo "1. Open Windows Settings"
        echo "2. Go to Apps > Apps & features"
        echo "3. Find TeamViewer and click Uninstall"
    fi

    echo -e "\n[OK] WSL setup complete!"
    echo "Please restart your terminal to ensure all changes take effect"
    echo "You can now connect using: gkc.sh adh-development develop"

    # Additional manual steps needed
    echo -e "\nNOTE: Manual steps needed:"
    echo "1. Run 'gh auth login' to authenticate with GitHub if you installed GitHub CLI"
    
    # Verify security tools
    if ! check_sentinelone &>/dev/null; then
        echo "2. Install SentinelOne from your IT department (Windows installation)"
    fi
    
    if ! check_automox &>/dev/null; then
        echo "3. Install Automox from your IT department (Windows installation)"
    fi
    
    if ! check_windows_app "NordPass" "NordPass" &>/dev/null; then
        echo "4. Install NordPass from your IT department or using winget: 'winget install -e --id NordSecurity.NordPass'"
    fi

    # Check for TeamViewer and warn if present
    if powershell.exe -Command "Get-ItemProperty HKLM:\\Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\* | Where-Object DisplayName -like '*TeamViewer*' 2>null" | grep -q "DisplayName"; then
        echo -e "\n${RED}WARNING: TeamViewer is installed and should be removed for security reasons"
        echo "Please uninstall TeamViewer manually from Windows using:"
        echo "1. Open Windows Settings"
        echo "2. Go to Apps > Apps & features"
        echo "3. Find TeamViewer and click Uninstall${RESET}"
    fi
}

# Add color codes using tput
RED=$(tput setaf 1)
RESET=$(tput sgr0)

# Check if no arguments were provided
if [ $# -eq 0 ]; then
    usage
    exit 0
fi

# Parse command line options
while getopts "hci-:" opt; do
    case "${opt}" in
        h)
            usage
            ;;
        c)
            do_certification
            ;;
        i)
            do_installation
            ;;
        -)
            case "${OPTARG}" in
                help)
                    usage
                    ;;
                certification)
                    do_certification
                    ;;
                install)
                    do_installation
                    ;;
                *)
                    echo "Invalid option: --${OPTARG}" >&2
                    usage
                    ;;
            esac
            ;;
        ?)
            usage
            ;;
    esac
done

# Remove processed options
shift $((OPTIND-1))

# If there are remaining arguments, show usage
if [ $# -gt 0 ]; then
    echo "Error: Unknown argument(s): $@"
    usage
fi
