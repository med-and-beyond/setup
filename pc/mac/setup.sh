#!/bin/bash

# --- Global Configuration and Definitions ---

# Selected Profile: Stores the chosen profile, defaults to 'other'
SELECTED_PROFILE="other"
AUTOMOX_ACCESS_KEY=""
SENTINELONE_TOKEN=""
# SENTINELONE_DOWNLOAD_LINK is now hardcoded in do_installation
SENTINELONE_PKG_NAME="SentinelOneInstaller.pkg" # Default package name, can still be overridden

# Color Codes
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)

# APP_DEF_FIELDS: ID;DisplayName;Type;Profiles;BrewName;AppNameForPathCheck;CommandNameForCLI
# Type: cli, cask, gcloud_sdk_base, gcloud_util, security_verify_path, security_verify_ps, core_tool (homebrew)
# Profiles: comma-separated list e.g., "all", "engineering", "other,engineering"
APPS_DEFINITIONS=(
    # Core tool - foundational
    "homebrew;Homebrew;core_tool;all;;;brew"

    # Google Cloud SDK - Install this early as other tools might relate to it (kubectl, gkc.sh)
    "google-cloud-sdk;Google Cloud SDK;gcloud_sdk_base;all;;;gcloud"

    # CLI tools
    "jq;jq;cli;all;jq;;jq"
    "gh;GitHub CLI;cli;engineering;gh;;gh"
    # k9s - Logically comes after gcloud/kubectl setup though not a hard dependency for k9s install itself
    "k9s;k9s;cli;engineering;k9s;;k9s"

    # Cask applications
    "docker;Docker;cask;engineering;docker;Docker;"
    "slack;Slack;cask;all;slack;Slack;"
    "twingate;Twingate;cask;all;twingate;Twingate;"
    "nordpass;NordPass;cask;all;nordpass;NordPass;"
    "cursor;Cursor;cask;engineering,data;cursor;Cursor;"
    "dbeaver-community;DBeaver Community;cask;engineering,data;dbeaver-community;DBeaver;"
    "visual-studio-code;Visual Studio Code;cask;engineering,data;visual-studio-code;Visual Studio Code;"

    # gkc.sh - Depends on gcloud SDK (specifically gsutil) being installed
    "gkc;gkc.sh;gcloud_util;engineering;;${HOME}/Applications/google-cloud-sdk/bin/gkc.sh;gkc.sh"

    # Security Verification/Installation
    "sentinelone;SentinelOne;security_verify_path;all;;SentinelOne/SentinelOne Extensions;"
    "automox;Automox;security_verify_ps;all;;;amagent"
)

# --- Function Definitions (usage, check_*, do_certification, do_installation) ---
# NOTE: The actual definitions of these functions are assumed to be present above the main script logic.
# The following is where the main script logic (parsing and execution) begins.
# We are re-inserting this block that was modified in the previous step,
# ensuring color definitions are at the top and new echos use colors.

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

A utility to manage development environment setup for MacOS.

Options:
    -h, --help                      Show this help message
    -c, --certification           Check and notify what tools are missing
    -i, --install                 Install all required tools
    --profile <name>            Specify user profile (engineering, data, or other). Defaults to 'other'.
    --automox-key <key>         Specify the Automox access key for installation.
    --sentinelone-token <token> Specify the SentinelOne registration token for installation.
    --sentinelone-pkg-name <name> (Optional) Specify the SentinelOne PKG filename (defaults to SentinelOneInstaller.pkg).

Examples:
    $0 --help
    $0 --certification --profile engineering
    $0 --certification --profile data
    $0 --install --profile data --sentinelone-token YOUR_S1_TOKEN

This script will manage the installation and verification of tools
based on the selected profile. SentinelOne download URL is fixed.
EOF
    exit 1
}

# Function to check if an application exists in Applications folders
check_application() {
    local app_name="$1"
    local display_name="$2"

    # Check in both system and user Applications folders
    if [ -d "/Applications/${app_name}.app" ] || [ -d "$HOME/Applications/${app_name}.app" ]; then
        echo "✅ $display_name is installed"
        return 0
    else
        echo "❌ $display_name is not installed"
        return 1
    fi
}

# Function to check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $2 is not installed"
        return 1
    else
        echo "✅ $2 is installed"
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
        echo "✅ $display_name is installed (via Homebrew)"
        return 0
    # Then check in Applications folders
    elif [ -d "/Applications/${app_name}.app" ] || [ -d "$HOME/Applications/${app_name}.app" ]; then
        echo "✅ $display_name is installed (via direct installation)"
        return 0
    else
        echo "❌ $display_name is not installed"
        return 1
    fi
}


# Function to check if a Homebrew cask is installed
check_cask() {
    if ! brew list --cask $1 &>/dev/null; then
        echo "❌ $2 is not installed"
        return 1
    else
        echo "✅ $2 is installed"
        return 0
    fi
}

# Function to check brew installation
check_brew() {
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew is not installed"
        return 1
    else
        echo "✅ Homebrew is installed"
        return 0
    fi
}

# Function to check if SentinelOne is properly installed
check_sentinelone() {
    if [ -d "/Applications/SentinelOne/SentinelOne Extensions.app" ]; then
        echo "✅ SentinelOne is installed"
        return 0
    else
        echo "❌ SentinelOne is not installed"
        return 1
    fi
}

# Function to check if Automox is properly installed
check_automox() {
    if ps -ef | grep -v grep | grep -q "amagent"; then
        echo "✅ Automox is installed and running"
        return 0
    else
        echo "❌ Automox is not installed or not running"
        return 1
    fi
}

# Function to check if the current app definition is relevant for the SELECTED_PROFILE
# $1: App's defined profiles (comma-separated string, e.g., "all,engineering")
# Returns 0 if relevant, 1 if not.
is_app_for_profile() {
    local app_profiles="$1"
    if [[ ",${app_profiles}," == *",all,"* || ",${app_profiles}," == *",${SELECTED_PROFILE},"* ]]; then
        return 0 # Relevant
    else
        return 1 # Not relevant
    fi
}

# Function to perform certification
do_certification() {
    echo -e "${BLUE}🚀 Performing certification for profile: ${YELLOW}$SELECTED_PROFILE${RESET}"
    echo -e "${YELLOW}🤔 Checking required tools...${RESET}"

    local missing_tools=0
    local security_warnings=0

    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}❌ [FATAL] This script requires MacOS (). Current OS: $OSTYPE${RESET}"
        exit 1
    else
        echo -e "${GREEN}✅ 💻 Running on MacOS${RESET}"
    fi

    echo -e "\n${BLUE}🔧 CHECKING TOOLS & APPLICATIONS FOR PROFILE: ${YELLOW}$SELECTED_PROFILE${RESET}"

    for app_def in "${APPS_DEFINITIONS[@]}"; do
        IFS=';' read -r id display_name type profiles brew_name app_path_name cmd_name <<< "$app_def"

        if ! is_app_for_profile "$profiles"; then
            continue
        fi

        #echo -e "🤔 Checking $display_name... " # Start the line

        local check_status=1 # Default to fail (1)

        case "$type" in
            core_tool)
                if [[ "$id" == "homebrew" ]]; then
                    if check_brew; then check_status=0; else ((missing_tools++)); fi
                fi
                ;;
            cli)
                if check_command "$cmd_name" "$display_name"; then check_status=0; else ((missing_tools++)); fi
                ;;
            cask)
                if check_app_installation "$brew_name" "$app_path_name" "$display_name"; then check_status=0; else ((missing_tools++)); fi
                ;;
            gcloud_sdk_base)
                if check_command "$cmd_name" "$display_name"; then check_status=0; else ((missing_tools++)); fi
                ;;
            gcloud_util)
                # This one has custom echo, so we handle it differently to append emoji
                if [ ! -f "$app_path_name" ]; then
                    echo -e "${RED}❌ $display_name is not installed at $app_path_name${RESET} ❌"
                    ((missing_tools++))
                    check_status=1 # Explicitly failed
                else
                    echo -e "${GREEN}✅ $display_name is installed${RESET}"
                    check_status=0 # Explicitly passed
                fi
                continue # Already printed emoji, skip common emoji echo
                ;;
            security_verify_path)
                if check_application "$app_path_name" "$display_name"; then check_status=0; else ((missing_tools++)); fi
                ;;
            security_verify_ps)
                # This one also has custom echo
                if ps -ef | grep -v grep | grep -q "$cmd_name"; then
                    echo -e "${GREEN}✅ $display_name is installed and running${RESET}"
                    check_status=0 # Explicitly passed
                else
                    echo -e "${RED}❌ $display_name is not installed or not running${RESET}"
                    ((missing_tools++))
                    check_status=1 # Explicitly failed
                fi
                continue # Already printed emoji, skip common emoji echo
                ;;
            *)
                echo -e "${YELLOW}⚠️ Warning: Unknown app type '$type' for $display_name${RESET}"
                check_status=1 # Consider unknown as a failed check for this item
                ;;
        esac

    done

    echo -e "\n${BLUE}🛡️  CHECKING GENERAL SECURITY:${RESET}"
    if [ -d "/Applications/TeamViewer.app" ] || [ -d "$HOME/Applications/TeamViewer.app" ]; then
        echo -e "${RED}⚠️ WARNING: TeamViewer is installed and should be removed for security reasons${RESET}"
        ((security_warnings++))
    else
        echo -e "${GREEN}✅ TeamViewer is not installed.${RESET}"
    fi

    echo -e "\n${BLUE}📊 SUMMARY:${RESET}"
    if [ $missing_tools -eq 0 ] && [ $security_warnings -eq 0 ]; then
        echo -e "${GREEN}🎉 All required tools for profile '$SELECTED_PROFILE' are installed and no security warnings!${RESET}"
        return 0
    else
        if [ $missing_tools -gt 0 ]; then
            echo -e "${RED}❌ Found $missing_tools missing tool(s) for profile '$SELECTED_PROFILE'${RESET}"
            echo -e "${YELLOW}Run with --install --profile $SELECTED_PROFILE to install missing tools${RESET}"
        fi
        if [ $security_warnings -gt 0 ]; then
            echo -e "${RED}⚠️ Found $security_warnings general security warning(s)${RESET}"
            echo -e "${YELLOW}Please address security warnings manually.${RESET}"
        fi
        return 1
    fi
}

# Function to perform installation
do_installation() {
    echo -e "${BLUE}🚀 Performing installation for profile: ${YELLOW}$SELECTED_PROFILE${RESET}"

    # Removed directory permission checks as per user request
    # Original checks for /usr/local/share/zsh and /usr/local/share/zsh/site-functions deleted.

    if [ "$(id -u)" = "0" ]; then
        echo -e "${RED}❌ ERROR: This script should not be run as root or with sudo directly.${RESET}"
        echo "Individual commands requiring sudo (like Automox install) will prompt if necessary."
        exit 1
    fi

    echo -e "\n${BLUE}🔧 INSTALLING TOOLS & APPLICATIONS FOR PROFILE: ${YELLOW}$SELECTED_PROFILE${RESET}"

    for app_def in "${APPS_DEFINITIONS[@]}"; do
        IFS=';' read -r id display_name type profiles brew_name app_path_name cmd_name <<< "$app_def"

        if ! is_app_for_profile "$profiles"; then
            continue # Skip this app if not for the current profile
        fi

        echo -e "\n➡️  Processing ${GREEN}$display_name${RESET}..."

        case "$type" in
            core_tool)
                if [[ "$id" == "homebrew" ]]; then
                    if ! check_brew &>/dev/null; then # Check silently
                        echo "    Installing Homebrew..."
                        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                        if ! check_brew; then echo -e "    ${RED}❌ Homebrew installation failed.${RESET}"; else echo -e "    ${GREEN}✅ Homebrew installed.${RESET}"; fi
                    else
                        echo -e "    ${GREEN}✅ Homebrew already installed.${RESET}"
                    fi
                fi
                ;;
            cli)
                if ! check_command "$cmd_name" "$display_name" &>/dev/null; then # Check silently
                    echo "    Installing $display_name ($cmd_name)..."
                    brew install "$brew_name"
                    if ! check_command "$cmd_name" "$display_name"; then echo -e "    ${RED}❌ $display_name installation failed.${RESET}"; else echo -e "    ${GREEN}✅ $display_name installed.${RESET}"; fi
                    if [[ "$id" == "gh" ]]; then echo -e "    ${YELLOW}🔔 Please run 'gh auth login' to authenticate with GitHub.${RESET}"; fi
                else
                    echo -e "    ${GREEN}✅ $display_name already installed.${RESET}"
                fi
                ;;
            cask)
                if ! check_app_installation "$brew_name" "$app_path_name" "$display_name" &>/dev/null; then # Check silently
                    echo "    Installing $display_name..."
                    brew install --cask "$brew_name"
                    if ! check_app_installation "$brew_name" "$app_path_name" "$display_name"; then echo -e "    ${RED}❌ $display_name installation failed.${RESET}"; else echo -e "    ${GREEN}✅ $display_name installed.${RESET}"; fi
                    if [[ "$id" == "docker" ]]; then echo -e "    ${YELLOW}🔔 Please open Docker Desktop to complete its setup if needed.${RESET}"; fi
                else
                    echo -e "    ${GREEN}✅ $display_name already installed.${RESET}"
                fi
                ;;
            gcloud_sdk_base)
                GCLOUD_PARENT_DIR="${HOME}/Applications" 
                GCLOUD_INSTALL_DIR="${GCLOUD_PARENT_DIR}/google-cloud-sdk" 
                GCLOUD_INSTALLED_HERE_FLAG="${GCLOUD_INSTALL_DIR}/.installed_by_this_script"
                EXPECTED_GCLOUD_BINARY="${GCLOUD_INSTALL_DIR}/bin/gcloud"

                if ! command -v gcloud &> /dev/null; then
                    echo "    🤔 Google Cloud SDK (gcloud command) not found in PATH. Attempting installation..."
                    mkdir -p "${GCLOUD_PARENT_DIR}" 
                    echo "    ☁️ Downloading and installing Google Cloud SDK to $GCLOUD_INSTALL_DIR (within $GCLOUD_PARENT_DIR)..."
                    
                    INSTALLER_SUCCESS=false
                    if (cd "${GCLOUD_PARENT_DIR}" && curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir="${GCLOUD_PARENT_DIR}"); then
                        echo -e "    ${GREEN}✅ Google Cloud SDK installer script executed successfully. Verifying installation...${RESET}"
                        # Add a small delay to allow filesystem changes to propagate fully
                        sleep 2 
                        if [ -x "$EXPECTED_GCLOUD_BINARY" ]; then
                            # Try a simple command to confirm it's working
                            if "$EXPECTED_GCLOUD_BINARY" --version &>/dev/null; then
                                echo -e "    ${GREEN}✅ gcloud binary confirmed at $EXPECTED_GCLOUD_BINARY and is executable.${RESET}"
                                INSTALLER_SUCCESS=true
                            else
                                echo -e "    ${RED}❌ gcloud binary found at $EXPECTED_GCLOUD_BINARY, but executing it failed. Check permissions or SDK corruption.${RESET}"
                            fi
                        else
                            echo -e "    ${RED}❌ gcloud binary NOT found at expected location: $EXPECTED_GCLOUD_BINARY after installer script execution.${RESET}"
                        fi
                    else
                        echo -e "    ${RED}❌ Google Cloud SDK core installation script execution failed (returned non-zero exit status). Check output above.${RESET}"
                    fi

                    if $INSTALLER_SUCCESS; then
                        touch "$GCLOUD_INSTALLED_HERE_FLAG"
                        echo "    🛠️  Configuring shell for Google Cloud SDK (requires terminal restart or sourcing profile)..."
                        echo "source '${GCLOUD_INSTALL_DIR}/path.bash.inc'" >> "${HOME}/.bash_profile"
                        echo "source '${GCLOUD_INSTALL_DIR}/completion.bash.inc'" >> "${HOME}/.bash_profile"
                        if [ -f "${HOME}/.zshrc" ]; then
                            echo "source '${GCLOUD_INSTALL_DIR}/path.zsh.inc'" >> "${HOME}/.zshrc"
                            echo "source '${GCLOUD_INSTALL_DIR}/completion.zsh.inc'" >> "${HOME}/.zshrc"
                        fi
                        
                        GCLOUD_BIN_TO_USE="$EXPECTED_GCLOUD_BINARY"
                        # User removed gcloud init call
                        
                        echo "    🛠️  Installing gcloud components (kubectl, gke-gcloud-auth-plugin) silently..."
                        "$GCLOUD_BIN_TO_USE" components install kubectl --quiet
                        "$GCLOUD_BIN_TO_USE" components install gke-gcloud-auth-plugin --quiet
                        
                        if [ ! -L /usr/local/bin/kubectl ] && [ ! -e /usr/local/bin/kubectl ]; then
                           echo "    🔗 Creating symlink for kubectl to /usr/local/bin/kubectl..."
                           sudo ln -sf "${GCLOUD_INSTALL_DIR}/bin/kubectl" /usr/local/bin/kubectl
                           echo -e "    ${GREEN}✅ Kubectl symlink created.${RESET}"
                        elif [ -L /usr/local/bin/kubectl ]; then
                           echo -e "    ${GREEN}✅ Kubectl symlink already exists or managed elsewhere.${RESET}"
                        fi
                    else
                        echo -e "    ${RED}❌ Halting further Google Cloud SDK setup due to installation verification failure.${RESET}"
                    fi
                else
                    # ... (logic for when gcloud is already in PATH remains the same)
                    GCLOUD_BIN_TO_USE=$(which gcloud)
                    echo -e "    ${GREEN}✅ Google Cloud SDK (gcloud command found at $GCLOUD_BIN_TO_USE) is already installed or in PATH.${RESET}"
                    
                    if [ -f "$GCLOUD_INSTALLED_HERE_FLAG" ] && [ ! -x "${GCLOUD_INSTALL_DIR}/bin/gcloud" ]; then
                         echo -e "    ${YELLOW}⚠️ SDK was previously installed by this script to $GCLOUD_INSTALL_DIR, but it's not found there now. Using system gcloud at $GCLOUD_BIN_TO_USE.${RESET}"
                    fi

                    echo "    🛠️  Verifying/installing gcloud components (kubectl, gke-gcloud-auth-plugin) silently using $GCLOUD_BIN_TO_USE..."
                    if ! "$GCLOUD_BIN_TO_USE" components install kubectl --quiet; then
                        echo -e "    ${RED}❌ Failed to install/verify kubectl component.${RESET}"
                    else
                        echo -e "    ${GREEN}✅ Kubectl component verified/installed.${RESET}"
                    fi
                    if ! "$GCLOUD_BIN_TO_USE" components install gke-gcloud-auth-plugin --quiet; then
                        echo -e "    ${RED}❌ Failed to install/verify gke-gcloud-auth-plugin component.${RESET}"
                    else
                        echo -e "    ${GREEN}✅ gke-gcloud-_auth-plugin component verified/installed.${RESET}"
                    fi
                    
                    KUBECTL_TARGET_PATH="${GCLOUD_INSTALL_DIR}/bin/kubectl"
                    if command -v "$GCLOUD_BIN_TO_USE" &>/dev/null && [[ "$GCLOUD_BIN_TO_USE" == *"/bin/gcloud" ]]; then 
                        KUBECTL_TARGET_PATH="$(dirname "$GCLOUD_BIN_TO_USE")/kubectl"
                    fi

                    if [ -f "$KUBECTL_TARGET_PATH" ]; then
                        if [ ! -L /usr/local/bin/kubectl ] && [ ! -e /usr/local/bin/kubectl ]; then
                            echo "    🔗 Creating symlink for kubectl to /usr/local/bin/kubectl from $KUBECTL_TARGET_PATH..."
                            sudo ln -sf "$KUBECTL_TARGET_PATH" /usr/local/bin/kubectl
                            echo -e "    ${GREEN}✅ Kubectl symlink created.${RESET}"
                        elif [ -L /usr/local/bin/kubectl ]; then
                             REAL_SYMLINK_TARGET=$(readlink /usr/local/bin/kubectl)
                             if [[ "$REAL_SYMLINK_TARGET" != "$KUBECTL_TARGET_PATH" ]]; then
                                echo -e "    ${YELLOW}🔗 Kubectl symlink at /usr/local/bin/kubectl exists but points to $REAL_SYMLINK_TARGET instead of expected $KUBECTL_TARGET_PATH. Not changing.${RESET}"
                             else
                                echo -e "    ${GREEN}✅ Kubectl symlink already correctly points to $KUBECTL_TARGET_PATH.${RESET}"
                             fi
                        else
                           echo -e "    ${YELLOW}⚠️ /usr/local/bin/kubectl exists and is not a symlink. Not overwriting.${RESET}"
                        fi
                    else
                         echo -e "    ${YELLOW}⚠️ Could not determine kubectl path from $GCLOUD_BIN_TO_USE to create symlink.${RESET}"
                    fi
                fi
                ;;
            gcloud_util)
                # gkc.sh installation, depends on gcloud being installed first
                GCLOUD_SDK_PATH="${HOME}/Applications/google-cloud-sdk"
                GSUTIL_BIN="${GCLOUD_SDK_PATH}/bin/gsutil"
                GKC_SH_TARGET_PATH="$app_path_name" # This is the full path like ~/Applications/google-cloud-sdk/bin/gkc.sh
                GSUTIL_CMD=$(which gsutil || echo "$GSUTIL_BIN")

                if [ -x "$GSUTIL_CMD" ]; then
                    if [ ! -f "$GKC_SH_TARGET_PATH" ]; then 
                        echo "    Installing $display_name..."
                        # Ensure directory exists
                        mkdir -p "${GKC_SH_TARGET_PATH%/*}"
                        "$GSUTIL_CMD" cp "gs://adh-tools/gkc.sh" "${GKC_SH_TARGET_PATH%/*}/"
                        chmod u+x "$GKC_SH_TARGET_PATH"
                        if [ -L /usr/local/bin/gkc.sh ] || [ ! -e /usr/local/bin/gkc.sh ]; then
                            sudo ln -sf "$GKC_SH_TARGET_PATH" /usr/local/bin/gkc.sh
                        fi
                        if [ -f "$GKC_SH_TARGET_PATH" ]; then echo -e "    ${GREEN}✅ $display_name installed.${RESET}"; else echo -e "    ${RED}❌ $display_name installation failed.${RESET}"; fi
                    else
                        echo -e "    ${GREEN}✅ $display_name already installed.${RESET}"
                    fi
                else
                    echo -e "    ${YELLOW}⚠️ Cannot install $display_name because Google Cloud SDK (gsutil) is not found.${RESET}"
                fi
                ;;
            security_verify_ps) # Handles Automox installation
                if [[ "$id" == "automox" ]]; then
                    if ! check_automox &>/dev/null; then 
                        if [ -n "$AUTOMOX_ACCESS_KEY" ]; then
                            echo "    Installing Automox... (This will require sudo password)"
                            curl -sS "https://console.automox.com/downloadInstaller?accesskey=${AUTOMOX_ACCESS_KEY}" | sudo bash
                            if check_automox; then echo -e "    ${GREEN}✅ Automox installed and appears to be running.${RESET}"; else echo -e "    ${RED}❌ Automox installation attempted, but it does not appear to be running. Check logs.${RESET}"; fi
                        else
                            echo -e "    ${YELLOW}⚠️ Automox access key not provided. Skipping installation. Use --automox-key <key>.${RESET}"
                        fi
                    else
                        echo -e "    ${GREEN}✅ Automox already installed and running.${RESET}"
                    fi
                fi
                ;;
            security_verify_path) # Handles SentinelOne installation
                if [[ "$id" == "sentinelone" ]]; then
                    local S1_PKG_URL="https://storage.googleapis.com/antidote-public-assets/sentinelone/Sentinel-Release-macos.pkg"
                    
                    if ! check_sentinelone &>/dev/null; then 
                        echo "    ℹ️ SentinelOne is not detected by current checks."
                        if [ -n "$SENTINELONE_TOKEN" ]; then # Only check for token now
                            echo "    🔑 Token provided. Attempting SentinelOne installation..."
                            echo "    📥 Downloading SentinelOne installer (${SENTINELONE_PKG_NAME} from hardcoded URL)..."
                            
                            if curl -L -o "/tmp/${SENTINELONE_PKG_NAME}" "${S1_PKG_URL}"; then # Use hardcoded URL
                                echo -e "    ${GREEN}✅ Download complete.${RESET}"
                                
                                echo "    📝 Creating token file for SentinelOne..."
                                TMP_TOKEN_FILE="/tmp/com.sentinelone.registration-token-$RANDOM"
                                echo "$SENTINELONE_TOKEN" > "$TMP_TOKEN_FILE"
                                sudo mv "$TMP_TOKEN_FILE" "/tmp/com.sentinelone.registration-token"
                                sudo chmod 644 "/tmp/com.sentinelone.registration-token"
                                sudo chown root "/tmp/com.sentinelone.registration-token"

                                echo "    🚀 Installing SentinelOne agent (this will require sudo password)..."
                                if sudo /usr/sbin/installer -pkg "/tmp/${SENTINELONE_PKG_NAME}" -target /; then
                                    echo -e "    ${GREEN}✅ SentinelOne installation command executed.${RESET}"
                                    echo "    ⏳ Waiting a bit for agent to initialize..."
                                    sleep 15
                                    if check_sentinelone; then 
                                        echo -e "    ${GREEN}🎉 SentinelOne is now installed and detected!${RESET}"
                                    else
                                        echo -e "    ${YELLOW}⚠️ SentinelOne installation command ran, but agent not immediately detected. It might be starting or requires a reboot. Please verify manually.${RESET}"
                                    fi
                                else
                                    echo -e "    ${RED}❌ SentinelOne installation command failed. Check installer output and /var/log/install.log.${RESET}"
                                fi
                                
                                echo "    🧹 Cleaning up temporary SentinelOne files..."
                                sudo rm -f "/tmp/com.sentinelone.registration-token"
                                rm -f "/tmp/${SENTINELONE_PKG_NAME}"
                            else
                                echo -e "    ${RED}❌ Failed to download SentinelOne installer from the hardcoded URL: ${S1_PKG_URL}${RESET}"
                            fi
                        else # No token provided
                            echo -e "    ${YELLOW}⚠️ SentinelOne token not provided. Installation via script skipped.${RESET}"
                            echo -e "    ${YELLOW}   Please install SentinelOne via IT or provide --sentinelone-token.${RESET}"
                        fi
                    else # Already installed
                        echo -e "    ${GREEN}✅ SentinelOne already installed and detected.${RESET}"
                    fi
                else
                    # Fallback for other security_verify_path types
                    echo -n "    " 
                    if ! check_application "$app_path_name" "$display_name"; then 
                        echo -e "    ${YELLOW}ℹ️ Please install $display_name via IT if it is required and missing.${RESET}"
                    fi
                fi
                ;;
            *)
                echo -e "    ${YELLOW}⚠️ Warning: Unknown app type '$type' for $display_name. No installation rule defined.${RESET}"
                ;;
        esac
    done

    # General security warnings post-installation attempts
    echo -e "\n${BLUE}🛡️  POST-INSTALL SECURITY CHECK:${RESET}"
    if [ -d "/Applications/TeamViewer.app" ] || [ -d "$HOME/Applications/TeamViewer.app" ]; then
        echo -e "${RED}⚠️ WARNING: TeamViewer is installed and should be removed for security reasons.${RESET}"
    else
        echo -e "${GREEN}✅ TeamViewer is not installed.${RESET}"
    fi

    echo -e "\n${GREEN}🎉 Installation phase for profile '$SELECTED_PROFILE' complete!${RESET}"
    echo -e "${YELLOW}🔔 Please restart your terminal for all changes (especially PATH updates for gcloud) to take effect.${RESET}"
    echo -e "${YELLOW}Some applications (like Docker) might require manual first-time launch to complete setup.${RESET}"
    echo -e "${YELLOW}If GitHub CLI was installed, run 'gh auth login'.${RESET}"
}

# --- Main Script Logic (Argument Parsing and Execution) ---

# Initial check for no arguments - if so, show usage and exit.
if [ $# -eq 0 ]; then
    usage
    exit 0
fi

# Parse command line options
CERT_FLAG=false
INSTALL_FLAG=false

POSITIONAL_ARGS=()
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -c|--certification)
            CERT_FLAG=true
            shift
            ;;
        -i|--install)
            INSTALL_FLAG=true
            shift
            ;;
        --profile)
            if [[ -n "$2" && "$2" != -* ]]; then
                SELECTED_PROFILE="$2"
                shift 2
            else
                echo -e "${RED}❌ Error: --profile option requires an argument (engineering, data, or other).${RESET}" >&2
                usage
            fi
            ;;
        --automox-key)
            if [[ -n "$2" && "$2" != -* ]]; then
                AUTOMOX_ACCESS_KEY="$2"
                shift 2
            else
                echo -e "${RED}❌ Error: --automox-key option requires an argument.${RESET}" >&2
                usage
            fi
            ;;
        --sentinelone-token)
            if [[ -n "$2" && "$2" != -* ]]; then
                SENTINELONE_TOKEN="$2"
                shift 2
            else
                echo -e "${RED}❌ Error: --sentinelone-token option requires an argument.${RESET}" >&2
                usage
            fi
            ;;
        --sentinelone-pkg-name)
            if [[ -n "$2" && "$2" != -* ]]; then
                SENTINELONE_PKG_NAME="$2"
                shift 2
            else
                echo -e "${RED}❌ Error: --sentinelone-pkg-name option requires an argument.${RESET}" >&2
                usage
            fi
            ;;
        -*)
            echo -e "${RED}❌ Error: Unknown option: $1${RESET}" >&2
            usage
            ;;
        *)
            echo -e "${RED}❌ Error: Unknown argument(s): $1${RESET}" >&2
            usage
            ;;
    esac
done

# Validate SELECTED_PROFILE
echo -e "${BLUE}ℹ️ Selected profile: ${YELLOW}$SELECTED_PROFILE${RESET}"
if [[ "$SELECTED_PROFILE" != "engineering" && "$SELECTED_PROFILE" != "other" && "$SELECTED_PROFILE" != "data" ]]; then
    echo -e "${RED}❌ Error: Invalid profile '$SELECTED_PROFILE'. Choose 'engineering', 'data', or 'other'.${RESET}" >&2
    usage
fi

# Main execution logic based on parsed flags
if ! $CERT_FLAG && ! $INSTALL_FLAG; then
    echo -e "${RED}❌ No action specified (e.g., --certification or --install).${RESET}" >&2
    usage
fi

if $CERT_FLAG; then
    do_certification
fi

if $INSTALL_FLAG; then
    do_installation
fi
