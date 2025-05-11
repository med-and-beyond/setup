# Laptop Setup Scripts

This repository contains scripts to standardize and automate the setup of development laptops for MacOS and Windows.

## MacOS Setup (`pc/mac/setup.sh`)

This script helps set up a MacOS development environment by checking for and installing necessary tools and applications based on user profiles.

### Features:

*   **Certification Mode**: Checks if all required tools for a given profile are installed and reports missing items.
*   **Installation Mode**: Installs missing tools for the selected profile, including Automox if an access key is provided.
*   **Profile-based Setup**: Supports different configurations for 'engineering' and 'other' user profiles. Defaults to 'other' if no profile is specified.

### Requirements:

*   MacOS
*   Internet connection
*   Automox Access Key (if you intend to install Automox via this script).

### Usage:

1.  **Clone the repository (optional, for local execution):**
    ```bash
    git clone https://github.com/YOUR_ORG/YOUR_REPO.git
    cd YOUR_REPO/pc/mac
    ```

2.  **Run the script:**

    *   **Show Help:**
        ```bash
        ./setup.sh --help
        ```

    *   **Check missing tools (Certification) for the default 'other' profile:**
        ```bash
        ./setup.sh --certification
        ```

    *   **Check missing tools (Certification) for the 'engineering' profile:**
        ```bash
        ./setup.sh --certification --profile engineering
        ```

    *   **Install tools for the 'engineering' profile (excluding Automox if key not provided):**
        ```bash
        ./setup.sh --install --profile engineering
        ```

    *   **Install tools for the 'engineering' profile, including Automox:**
        ```bash
        ./setup.sh --install --profile engineering --automox-key YOUR_AUTOMOX_ACCESS_KEY
        ```
        *Using curl to run directly from GitHub (ensure you understand the security implications of passing keys this way):*
        ```bash
        # Note: Be cautious with direct curl execution if script asks for sudo or handles sensitive keys.
        # Consider downloading and reviewing the script first if running with installation or keys.
        curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main/pc/mac/setup.sh | bash -s -- --install --profile engineering --automox-key YOUR_AUTOMOX_ACCESS_KEY
        ```

    *   **Check and Install in one command for a specific profile, including Automox:**
        ```bash
        ./setup.sh -c -i --profile engineering --automox-key YOUR_AUTOMOX_ACCESS_KEY
        ```
        *(Note: `-c` is for `--certification`, `-i` is for `--install`)*

### Managed Tools (Profile Dependent):

*   **All Profiles:** Homebrew, Slack, Twingate, NordPass, Google Cloud SDK, jq.
    *   *Security Verification/Installation:*
        *   SentinelOne (verification only, install via IT)
        *   Automox (verification in cert mode; installation in install mode if `--automox-key` is provided)
*   **Engineering Profile (includes 'All' plus):** k9s, GitHub CLI (gh), Docker, Cursor, DBeaver Community, Visual Studio Code, gkc.sh utility.

### Important Notes:

*   **Automox Installation**: To install Automox using this script, you **must** provide your organization's Automox access key via the `--automox-key YOUR_KEY_HERE` argument during the `--install` phase. Otherwise, Automox installation will be skipped.
*   The script may prompt for your password (`sudo`) for some installations (e.g., Automox, creating symlinks).
*   Some installations, like Docker, might require you to open the application manually to complete the setup.
*   Google Cloud SDK installation will prompt you to log in and choose a project.
*   It's recommended to restart your terminal after the installation is complete.

## Windows Setup (`pc/win/setup.ps1` - *Placeholder*)

(Details for the Windows setup script will be added here once it's developed.)

---

Please replace `YOUR_ORG/YOUR_REPO` in the `curl` commands with the actual path to your repository if you intend to use the direct curl execution method.
Be mindful of security when executing scripts directly from the internet, especially those that handle keys or require elevated privileges.
