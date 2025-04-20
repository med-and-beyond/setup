#!/bin/bash

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

A utility to manage development environment setup for MacOS.

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
    - Homebrew
    - k9s
    - jq
    - Docker
    - Slack
    - Twingate
    - Google Cloud SDK
    - gkc.sh utility
    - NordPass
    - Cursor
    - DBeaver Community
    - Visual Studio Code
    - Automox (verification only)
    - SentinelOne (verification only)

Note: This script is intended for MacOS only.
EOF
    exit 1
}

# Function to check if an application exists in Applications folders
check_application() {
    local app_name="$1"
    local display_name="$2"

    # Check in both system and user Applications folders
    if [ -d "/Applications/${app_name}.app" ] || [ -d "$HOME/Applications/${app_name}.app" ]; then
        echo "[OK] $display_name is installed"
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

# Function to check if application is installed (either via brew or directly)
check_app_installation() {
    local brew_name="$1"
    local app_name="$2"
    local display_name="$3"

    # First check if installed via brew
    if brew list --cask $brew_name &>/dev/null; then
        echo "[OK] $display_name is installed (via Homebrew)"
        return 0
    # Then check in Applications folders
    elif [ -d "/Applications/${app_name}.app" ] || [ -d "$HOME/Applications/${app_name}.app" ]; then
        echo "[OK] $display_name is installed (via direct installation)"
        return 0
    else
        echo "[MISSING] $display_name is not installed"
        return 1
    fi
}


# Function to check if a Homebrew cask is installed
check_cask() {
    if ! brew list --cask $1 &>/dev/null; then
        echo "[MISSING] $2 is not installed"
        return 1
    else
        echo "[OK] $2 is installed"
        return 0
    fi
}

# Function to check brew installation
check_brew() {
    if ! command -v brew &> /dev/null; then
        echo "[MISSING] Homebrew is not installed"
        return 1
    else
        echo "[OK] Homebrew is installed"
        return 0
    fi
}

# Function to check if SentinelOne is properly installed
check_sentinelone() {
    if [ -d "/Applications/SentinelOne/SentinelOne Extensions.app" ]; then
        echo "[OK] SentinelOne is installed"
        return 0
    else
        echo "[MISSING] SentinelOne is not installed"
        return 1
    fi
}

# Function to check if Automox is properly installed
check_automox() {
    if ps -ef | grep -v grep | grep -q "amagent"; then
        echo "[OK] Automox is installed and running"
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
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "[MISSING] This script requires MacOS. Current OS: $OSTYPE"
        exit 1
    else
        echo "[OK] Running on MacOS"
    fi

    echo -e "\nCHECKING DEVELOPMENT TOOLS:"
    # Check Homebrew
    check_brew || ((missing_tools++))

    # Check command line tools
    check_command "k9s" "k9s" || ((missing_tools++))
    check_command "jq" "jq" || ((missing_tools++))
    check_command "gcloud" "Google Cloud SDK" || ((missing_tools++))
    check_command "gh" "GitHub CLI" || ((missing_tools++))

    echo -e "\nCHECKING APPLICATIONS:"
    # Check applications with both brew and direct installation
    check_app_installation "docker" "Docker" "Docker" || ((missing_tools++))
    check_app_installation "slack" "Slack" "Slack" || ((missing_tools++))
    check_app_installation "twingate" "Twingate" "Twingate" || ((missing_tools++))
    check_app_installation "cursor" "Cursor" "Cursor" || ((missing_tools++))
    check_app_installation "dbeaver-community" "DBeaver" "DBeaver Community" || ((missing_tools++))
    check_app_installation "visual-studio-code" "Visual Studio Code" "Visual Studio Code" || ((missing_tools++))

    echo -e "\nCHECKING SECURITY TOOLS:"
    # Check security applications
    check_sentinelone || ((missing_tools++))
    check_automox || ((missing_tools++))
    check_app_installation "nordpass" "NordPass" "NordPass" || ((missing_tools++))

    # Check for TeamViewer (should not be installed)
    if [ -d "/Applications/TeamViewer.app" ] || [ -d "$HOME/Applications/TeamViewer.app" ]; then
        echo "${RED}WARNING: TeamViewer is installed and should be removed for security reasons${RESET}"
        ((security_warnings++))
    fi

    # Check gkc.sh
    echo -e "\nCHECKING UTILITIES:"
    if [ ! -f ${HOME}/Applications/google-cloud-sdk/bin/gkc.sh ]; then
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

# Function to perform installation
do_installation() {
    echo "Starting MacOS laptop setup..."

    # Check directory permissions first
    local permission_issues=false
    if [ ! -w "/usr/local/share/zsh" ] || [ ! -w "/usr/local/share/zsh/site-functions" ]; then
        echo "WARNING: The following directories are not writable by your user:"
        [ ! -w "/usr/local/share/zsh" ] && echo "/usr/local/share/zsh"
        [ ! -w "/usr/local/share/zsh/site-functions" ] && echo "/usr/local/share/zsh/site-functions"
        echo ""
        echo "Please run the following command to fix permissions and then run this script again:"
        echo "  sudo chown -R $(whoami) /usr/local/share/zsh /usr/local/share/zsh/site-functions"
        echo "  chmod u+w /usr/local/share/zsh /usr/local/share/zsh/site-functions"
        permission_issues=true
    fi

    # Check if running as root or via sudo
    if [ "$(id -u)" = "0" ]; then
        echo "[ERROR] This script should not be run as root or with sudo"
        echo "Please run it as a regular user. If you need to fix permissions, see instructions above."
        exit 1
    fi

    # If there are permission issues, exit with instructions
    if [ "$permission_issues" = true ]; then
        exit 1
    fi

    # Install Homebrew if not present
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Install command line tools
    if ! command -v k9s &> /dev/null; then
        echo "Installing k9s..."
        brew install k9s
    fi

    if ! command -v jq &> /dev/null; then
        echo "Installing jq..."
        brew install jq
    fi

    if ! command -v gh &> /dev/null; then
        echo "Installing GitHub CLI..."
        brew install gh
        echo "Please run 'gh auth login' to authenticate with GitHub"
    fi

    # Install Docker if not present
    if ! check_app_installation "docker" "Docker" "Docker" &>/dev/null; then
        echo "Installing Docker..."
        brew install --cask docker
        echo "Please open Docker Desktop to complete the installation"
    fi

    # Install Slack if not present
    if ! check_app_installation "slack" "Slack" "Slack" &>/dev/null; then
        echo "Installing Slack..."
        brew install --cask slack
    fi

    # Install Twingate if not present
    if ! check_app_installation "twingate" "Twingate" "Twingate" &>/dev/null; then
        echo "Installing Twingate..."
        brew install --cask twingate
    fi

    # Install NordPass if not present
    if ! check_app_installation "nordpass" "NordPass" "NordPass" &>/dev/null; then
        echo "Installing NordPass..."
        brew install --cask nordpass
    fi
    
    # Install Cursor if not present
    if ! check_app_installation "cursor" "Cursor" "Cursor" &>/dev/null; then
        echo "Installing Cursor..."
        brew install --cask cursor
    fi
    
    # Install DBeaver Community if not present
    if ! check_app_installation "dbeaver-community" "DBeaver" "DBeaver Community" &>/dev/null; then
        echo "Installing DBeaver Community..."
        brew install --cask dbeaver-community
    fi

    # Install Visual Studio Code if not present
    if ! check_app_installation "visual-studio-code" "Visual Studio Code" "Visual Studio Code" &>/dev/null; then
        echo "Installing Visual Studio Code..."
        brew install --cask visual-studio-code
    fi

    # Install Google Cloud SDK
    if ! command -v gcloud &> /dev/null; then
        echo "Installing Google Cloud SDK..."

        # Create Applications directory if it doesn't exist
        mkdir -p "${HOME}/Applications"
        cd "${HOME}/Applications"

        # Use the official installer script (most reliable method)
        echo "Downloading and installing Google Cloud SDK using official installer..."
        bash -c "$(curl -fsSL https://sdk.cloud.google.com)" -- --disable-prompts --install-dir="${HOME}/Applications"
        
        # Check if installation was successful
        if [ -d "google-cloud-sdk" ]; then
            echo "Google Cloud SDK installation successful"
            
            # Configure shell
            echo "Configuring shell for Google Cloud SDK..."
            echo "source '${HOME}/Applications/google-cloud-sdk/path.bash.inc'" >> "${HOME}/.bash_profile"
            echo "source '${HOME}/Applications/google-cloud-sdk/completion.bash.inc'" >> "${HOME}/.bash_profile"
            
            if [ -f "${HOME}/.zshrc" ]; then
                echo "source '${HOME}/Applications/google-cloud-sdk/path.zsh.inc'" >> "${HOME}/.zshrc"
                echo "source '${HOME}/Applications/google-cloud-sdk/completion.zsh.inc'" >> "${HOME}/.zshrc"
            fi
            
            # Initialize gcloud
            echo "Initializing Google Cloud SDK..."
            "${HOME}/Applications/google-cloud-sdk/bin/gcloud" init --quiet
        else
            echo "ERROR: Google Cloud SDK installation failed. Please try again or install manually."
            echo "Manual installation instructions: https://cloud.google.com/sdk/docs/install"
        fi
    fi

    # Install gkc.sh
    if [ ! -f "${HOME}/Applications/google-cloud-sdk/bin/gkc.sh" ]; then
        echo "Installing gkc.sh..."
        "${HOME}/Applications/google-cloud-sdk/bin/gsutil" cp gs://adh-tools/gkc.sh "${HOME}/Applications/google-cloud-sdk/bin/"
        chmod u+x "${HOME}/Applications/google-cloud-sdk/bin/gkc.sh"
        sudo ln -sf "${HOME}/Applications/google-cloud-sdk/bin/gkc.sh" /usr/local/bin/gkc.sh
    fi

    # Check for TeamViewer and warn if present
    if [ -d "/Applications/TeamViewer.app" ] || [ -d "${HOME}/Applications/TeamViewer.app" ]; then
        echo -e "\nWARNING: TeamViewer is installed and should be removed for security reasons"
        echo "Please uninstall TeamViewer manually using the following steps:"
        echo "1. Quit TeamViewer if it's running"
        echo "2. Open Finder"
        echo "3. Go to Applications"
        echo "4. Drag TeamViewer to the Trash"
        echo "5. Empty the Trash"
    fi

    echo -e "\n[OK] MacOS setup complete!"
    echo "Please restart your terminal to ensure all changes take effect"
    echo "You can now connect using: gkc.sh adh-development develop"

    # Additional manual steps needed
    echo -e "\nNOTE: Manual steps needed:"
    echo "1. Run 'gh auth login' to authenticate with GitHub if you installed GitHub CLI"
    
    # Verify security tools
    if ! check_sentinelone &>/dev/null; then
        echo "2. Install SentinelOne from your IT department"
    fi
    
    if ! check_automox &>/dev/null; then
        echo "3. Install Automox from your IT department"
    fi
    
    if ! check_app_installation "nordpass" "NordPass" "NordPass" &>/dev/null; then
        echo "4. Install NordPass from your IT department or run 'brew install --cask nordpass'"
    fi

    # Check for TeamViewer and warn if present
    if [ -d "/Applications/TeamViewer.app" ] || [ -d "${HOME}/Applications/TeamViewer.app" ]; then
        echo -e "\n${RED}WARNING: TeamViewer is installed and should be removed for security reasons"
        echo "Please uninstall TeamViewer manually using the following steps:"
        echo "1. Quit TeamViewer if it's running"
        echo "2. Open Finder"
        echo "3. Go to Applications"
        echo "4. Drag TeamViewer to the Trash"
        echo "5. Empty the Trash${RESET}"
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
