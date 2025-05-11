# Laptop Setup Scripts

This repository contains scripts to standardize and automate the setup of development laptops for MacOS and Windows.

## MacOS Setup (`pc/mac/setup.sh`)

This script helps set up a MacOS development environment by checking for and installing necessary tools and applications based on user profiles.

### Features:

*   **Certification Mode**: Checks if all required tools for a given profile are installed and reports missing items.
*   **Installation Mode**: Installs missing tools for the selected profile. This includes Automox (if an access key is provided) and SentinelOne (if a token is provided; download URL is fixed).
*   **Profile-based Setup**: Supports different configurations for 'engineering' and 'other' user profiles. Defaults to 'other' if no profile is specified.

### Requirements:

*   MacOS
*   Internet connection
*   Automox Access Key (if you intend to install Automox via this script).
*   SentinelOne Token (if you intend to install SentinelOne via this script; the download URL is hardcoded in the script).

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

    *   **Check missing tools (Certification) for the 'engineering' profile:**
        ```bash
        ./setup.sh --certification --profile engineering
        ```

    *   **Install tools for the 'engineering' profile, including Automox and SentinelOne:**
        ```bash
        ./setup.sh --install --profile engineering \
                   --automox-key YOUR_AM_KEY \
                   --sentinelone-token YOUR_S1_TOKEN \
                   # --sentinelone-pkg-name "OptionalSentinelOneInstaller.pkg" # SentinelOne download URL is fixed
        ```
        *Using curl to run directly from GitHub (ensure you understand the security implications of passing keys/tokens this way):*
        ```bash
        # Note: Be cautious with direct curl execution if script asks for sudo or handles sensitive keys/tokens.
        # Consider downloading and reviewing the script first if running with installation or keys/tokens.
        curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main/pc/mac/setup.sh | bash -s -- \
           --install --profile engineering \
           --automox-key YOUR_AM_KEY \
           --sentinelone-token YOUR_S1_TOKEN
        ```

    *   **Check and Install in one command, including Automox and SentinelOne:**
        ```bash
        ./setup.sh -c -i --profile engineering \
                   --automox-key YOUR_AM_KEY \
                   --sentinelone-token YOUR_S1_TOKEN
        ```
        *(Note: `-c` is for `--certification`, `-i` is for `--install`)*

### Managed Tools (Profile Dependent):

*   **All Profiles:** Homebrew, Slack, Twingate, NordPass, Google Cloud SDK, jq.
    *   *Security Verification/Installation:*
        *   Automox (verification in cert mode; installation in install mode if `--automox-key` is provided)
        *   SentinelOne (verification in cert mode; installation in install mode if `--sentinelone-token` is provided; download URL is fixed in the script)
*   **Engineering Profile (includes 'All' plus):** k9s, GitHub CLI (gh), Docker, Cursor, DBeaver Community, Visual Studio Code, gkc.sh utility.

### Important Notes:

*   **Automox Installation**: Requires `--automox-key YOUR_KEY_HERE` during `--install`.
*   **SentinelOne Installation**: Requires `--sentinelone-token YOUR_TOKEN` during `--install`. The download URL for the SentinelOne package is hardcoded in the script to `https://storage.googleapis.com/antidote-public-assets/sentinelone/Sentinel-Release-macos.pkg`. You can optionally specify `--sentinelone-pkg-name "filename.pkg"` if the actual installer filename differs from the default `SentinelOneInstaller.pkg` (though the hardcoded URL implies a specific file).
*   The script may prompt for your password (`sudo`) for some installations (e.g., Automox, SentinelOne, creating symlinks).
*   Restart your terminal after installation for all changes to take effect.

## Windows Setup (`pc/win/setup.ps1` - *Placeholder*)

(Details for the Windows setup script will be added here once it's developed.)

---

Please replace `YOUR_ORG/YOUR_REPO` in the `curl` commands with the actual path to your repository if you intend to use the direct curl execution method.
Be mindful of security when executing scripts directly from the internet, especially those that handle keys or require elevated privileges.
