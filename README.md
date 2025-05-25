# Laptop Setup Scripts

This repository contains scripts to standardize and automate the setup of development laptops for MacOS and Windows.

## MacOS Setup (`pc/mac/setup.sh`)

This script helps set up a MacOS development environment by checking for and installing necessary tools and applications based on user profiles.

### Features:

*   **Certification Mode**: Checks if all required tools for a given profile are installed and reports missing items.
*   **Installation Mode**: Installs missing tools for the selected profile. This includes Automox (if an access key is provided) and SentinelOne (if a token is provided; download URL is fixed).
*   **Profile-based Setup**: Supports different configurations for 'engineering', 'data', and 'other' user profiles. Defaults to 'other' if no profile is specified.

### Requirements (MacOS):

*   MacOS
*   Internet connection
*   Automox Access Key (if you intend to install Automox via this script).
*   SentinelOne Token (if you intend to install SentinelOne via this script; the download URL is hardcoded in the script).

### Usage (MacOS):

#### options with cURL

1. open terminan in your laptop or any other system and run:
```bash
curl -fsSL https://raw.githubusercontent.com/med-and-beyond/setup/refs/heads/main/pc/mac/setup.sh | bash -s -- \
  --install --profile engineering \
  --automox-key YOUR_AM_KEY \
  --sentinelone-token YOUR_S1_TOKEN 
```

#### for Intune use !!!
```bash
curl -fsSL https://raw.githubusercontent.com/med-and-beyond/setup/refs/heads/main/pc/mac/install.sh | bash -s -- \
  --install --profile engineering \
  --automox-key YOUR_AM_KEY \
  --sentinelone-token YOUR_S1_TOKEN 
```

#### option with git clone

1.  **Clone the repository (optional, for local execution):**
    ```bash
    git clone https://github.com/YOUR_ORG/YOUR_REPO.git
    cd YOUR_REPO/pc/mac
    ```

2.  **Run the script:**
    *   Show Help: `./setup.sh --help`
    *   Certification (Engineering): `./setup.sh --certification --profile engineering`
    *   Install (Engineering, with keys): `./setup.sh --install --profile engineering --automox-key YOUR_AM_KEY --sentinelone-token YOUR_S1_TOKEN`
    *(See script's `--help` for all options and detailed examples)*

### Managed Tools (MacOS - Profile Dependent):

*   **All Profiles (Baseline):** Homebrew, Slack, Twingate, NordPass, Google Cloud SDK, jq.
    *   *Security:* Automox (install with key), SentinelOne (install with token, fixed URL).
*   **Data Profile (includes 'All' plus):** Cursor, DBeaver Community, Visual Studio Code.
*   **Engineering Profile (includes 'All' and 'Data' tools plus):** k9s, GitHub CLI (gh), Docker, gkc.sh utility.

### Important Notes (MacOS):

*   Automox/SentinelOne installation requires respective keys/tokens.
*   The script may prompt for `sudo` password.
*   Restart terminal after installation.

## Windows Setup (`pc/win/setup.ps1`)

This script provides a foundational framework for setting up a Windows development environment with profile-based tool management. **It is currently in an initial development phase with placeholder logic for most checks and installations.**

### Features (Windows - Planned):

*   **Certification Mode**: Checks for tool presence (current implementation is basic).
*   **Installation Mode**: Installs tools (current implementation is basic, targeting Chocolatey for many tools).
*   **Profile-based Setup**: Supports 'engineering', 'data', and 'other' user profiles.
*   Parameter handling for Automox key and SentinelOne token (specific Windows installation methods for these are TBD).

### Requirements (Windows):

*   Windows 10/11 (PowerShell 5.1+ recommended).
*   Internet connection.
*   **Administrator Privileges**: Highly recommended, and likely required for many installations (e.g., Chocolatey installation, system-wide tools, services).
*   **PowerShell Execution Policy**: May need to be adjusted to run scripts. A common setting is `RemoteSigned` for the current user.

### How to Run (Windows):

1.  **Ensure Execution Policy Allows Scripts:**
    Windows PowerShell has an execution policy to prevent accidental running of malicious scripts. You have a few options:

    *   **Option A: Set Policy for Current User (Recommended for ongoing use):**
        *   Open PowerShell **as Administrator**.
        *   Run: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`
        *   This allows local scripts (like this one, once saved to your machine) and remote scripts that are digitally signed to run.

    *   **Option B: Bypass Policy for a Single Execution (If Option A is not desired/possible):**
        *   Open PowerShell (normal or Administrator, depending on what the script itself will do).
        *   You can bypass the policy for a single command execution directly:
            ```powershell
            powershell.exe -ExecutionPolicy Bypass -File .\setup.ps1 -Help
            ```
        *   Or, from within an existing PowerShell session, for that session only (process scope):
            ```powershell
            Set-ExecutionPolicy Bypass -Scope Process -Force
            .\setup.ps1 -Help 
            # Optionally, revert after: Set-ExecutionPolicy Undefined -Scope Process -Force 
            # (or simply close the PowerShell window, as -Scope Process is temporary)
            ```
        *   **Caution**: Using `-ExecutionPolicy Bypass` disables an important security feature. Only use it if you fully trust the script.

    *   **Check Current Policy:** `Get-ExecutionPolicy -List` (to see all scopes) or `Get-ExecutionPolicy` (for the most effective one).

2.  **Navigate to the Script Directory:**
    *   Open PowerShell.
    *   Example: `cd C:\path\to\antidote\setup\pc\win`

3.  **Run the Script (after handling execution policy):**
    *   **Show Help:**
        ```powershell
        .\setup.ps1 -Help
        ```
    *   **Run Certification (Engineering Profile - current checks are basic):**
        ```powershell
        .\setup.ps1 -Certification -Profile engineering
        ```
    *   **Run Installation (Data Profile, with SentinelOne token - current installs are basic placeholders):**
        ```powershell
        .\setup.ps1 -Install -Profile data -SentinelOneToken YOUR_S1_TOKEN
        ```

### Managed Tools (Windows - Conceptual List, Installation Methods TBD/Placeholder):

*   **All Profiles:** Chocolatey (as package manager), Google Cloud SDK, jq, Slack, Twingate, NordPass.
    *   *Security:* Automox, SentinelOne (Windows installation methods need specific, token/key-based silent installer commands).
*   **Data Profile (includes 'All' plus):** Cursor, DBeaver Community, Visual Studio Code.
*   **Engineering Profile (includes 'All' plus):** k9s, GitHub CLI (gh), Docker Desktop.
    *(Note: The specific methods for checking and installing these on Windows, especially silently/automated, need to be implemented. Chocolatey is a primary candidate where possible.)*

### Important Notes (Windows):

*   **Under Development**: This script is a starting point. Most application check and installation commands are **placeholders** and need to be implemented with Windows-specific methods (e.g., Chocolatey package names, direct installer silent switches, PowerShell modules for configuration).
*   **Chocolatey**: Installation of Chocolatey itself should be added as a foundational step if it's to be used as the main package manager.
*   **Admin Rights**: Running PowerShell as Administrator is strongly recommended for the `-Install` functionality.
*   **Tool-Specific Installers**: For tools not in Chocolatey or requiring complex setups (like Google Cloud SDK, Automox, SentinelOne on Windows), their specific silent installer commands and configuration methods need to be researched and integrated.

---

Replace `YOUR_ORG/YOUR_REPO` in `curl` commands (MacOS section) if using direct execution. Be mindful of security when executing scripts directly from the internet, especially those that handle keys or require elevated privileges.
