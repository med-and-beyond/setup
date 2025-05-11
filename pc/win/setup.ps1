#Requires -Version 5.1
<#
.SYNOPSIS
    A utility to manage development environment setup for Windows.
.DESCRIPTION
    This script helps set up a Windows development environment by checking for
    and installing necessary tools and applications based on user profiles.
    It supports different configurations for 'engineering', 'data', and 'other' users.
.PARAMETER Help
    Show this help message.
.PARAMETER Certification
    Check and notify what tools are missing for the selected profile.
.PARAMETER Install
    Install all required tools for the selected profile.
.PARAMETER Profile
    Specify user profile (engineering, data, or other). Defaults to 'other'.
.PARAMETER AutomoxKey
    Specify the Automox access key for installation.
.PARAMETER SentinelOneToken
    Specify the SentinelOne registration token for installation.
    (Note: SentinelOne installation method for Windows will differ from MacOS).
.EXAMPLE
    .\setup.ps1 -Help
.EXAMPLE
    .\setup.ps1 -Certification -Profile engineering
.EXAMPLE
    .\setup.ps1 -Install -Profile data -SentinelOneToken YOUR_S1_TOKEN
.EXAMPLE
    .\setup.ps1 -Install -Profile engineering -AutomoxKey YOUR_AM_KEY -SentinelOneToken YOUR_S1_TOKEN
#>
param (
    [switch]$Help,
    [switch]$Certification,
    [switch]$Install,
    [ValidateSet("engineering", "data", "other")]
    [string]$Profile = "other", # Default profile
    [string]$AutomoxKey = "",
    [string]$SentinelOneToken = ""
    # SentinelOne Download Link and PKG name are MacOS specific, will need Windows equivalent logic
)

# --- Global Configuration and Definitions ---

# Color Functions (PowerShell doesn't use tput directly like bash)
function Write-HostColorized {
    param (
        [string]$Message,
        [ConsoleColor]$Color
    )
    Write-Host $Message -ForegroundColor $Color
}

$ColorRed = [ConsoleColor]::Red
$ColorGreen = [ConsoleColor]::Green
$ColorYellow = [ConsoleColor]::Yellow
$ColorBlue = [ConsoleColor]::Blue
$ColorWhite = [ConsoleColor]::White # For reset or default

# Application Definitions (Conceptual - Windows methods will differ significantly)
# Structure: ID;DisplayName;Type;Profiles;ChocoPackageName;DownloadUrl;InstallCommand;VerificationPath;VerificationCommand
# Type: choco, manual_download, cli_direct, app_path, service_running, etc.
$AppsDefinitions = @(
    # Core Package Manager (Chocolatey - analogous to Homebrew)
    @{ ID = "chocolatey"; DisplayName = "Chocolatey Package Manager"; Type = "core_packagemanager"; Profiles = "all"; VerificationCommand = "choco --version" }

    # Google Cloud SDK
    @{ ID = "google-cloud-sdk"; DisplayName = "Google Cloud SDK"; Type = "manual_download"; Profiles = "all"; ChocoPackageName = "gcloudsdk"; VerificationCommand = "gcloud --version" } # Choco is an option

    # CLI tools
    @{ ID = "jq"; DisplayName = "jq"; Type = "choco"; Profiles = "all"; ChocoPackageName = "jq"; VerificationCommand = "jq --version" }
    @{ ID = "gh"; DisplayName = "GitHub CLI"; Type = "choco"; Profiles = "engineering"; ChocoPackageName = "gh"; VerificationCommand = "gh --version" }
    @{ ID = "k9s"; DisplayName = "k9s"; Type = "choco"; Profiles = "engineering"; ChocoPackageName = "k9s"; VerificationCommand = "k9s version" }

    # GUI Applications (many available via Chocolatey)
    @{ ID = "docker"; DisplayName = "Docker Desktop"; Type = "choco"; Profiles = "engineering"; ChocoPackageName = "docker-desktop"; VerificationPath = "$($env:ProgramFiles)\Docker\Docker\Docker Desktop.exe" }
    @{ ID = "slack"; DisplayName = "Slack"; Type = "choco"; Profiles = "all"; ChocoPackageName = "slack"; VerificationPath = "$($env:LOCALAPPDATA)\Slack\slack.exe" }
    @{ ID = "twingate"; DisplayName = "Twingate"; Type = "manual_download"; Profiles = "all"; VerificationPath = "$($env:ProgramFiles)\Twingate\Twingate.exe" } # Assuming default path
    @{ ID = "nordpass"; DisplayName = "NordPass"; Type = "choco"; Profiles = "all"; ChocoPackageName = "nordpass"; VerificationPath = "$($env:ProgramFiles)\NordPass\NordPass.exe" }
    @{ ID = "cursor"; DisplayName = "Cursor"; Type = "manual_download"; Profiles = "engineering,data"; VerificationPath = "$($env:LOCALAPPDATA)\Programs\cursor\Cursor.exe" } # Assuming default path
    @{ ID = "dbeaver"; DisplayName = "DBeaver Community"; Type = "choco"; Profiles = "engineering,data"; ChocoPackageName = "dbeaver"; VerificationPath = "$($env:ProgramFiles)\DBeaver\dbeaver.exe" }
    @{ ID = "vscode"; DisplayName = "Visual Studio Code"; Type = "choco"; Profiles = "engineering,data"; ChocoPackageName = "vscode"; VerificationCommand = "code --version" }

    # gkc.sh equivalent for Windows (TBD - likely a PowerShell script or different auth method)
    @{ ID = "gkc-win"; DisplayName = "GKE Cluster Connect Utility (Win)"; Type = "placeholder"; Profiles = "engineering" }

    # Security Tools
    @{ ID = "sentinelone"; DisplayName = "SentinelOne"; Type = "manual_download_token"; Profiles = "all" } # Verification: e.g., check service or agent path
    @{ ID = "automox"; DisplayName = "Automox"; Type = "manual_download_key"; Profiles = "all" } # Verification: e.g., Get-Service AmAgent
)

# --- Function Definitions ---

function Show-Usage {
    Write-HostColorized "This script is under development. Current parameters:" $ColorYellow
    Get-Help $MyInvocation.MyCommand.Definition -Full | Out-String | Write-Host
    exit 1
}

function Test-IsAppForProfile($AppProfiles) {
    if (($AppProfiles -split "," -contains "all") -or ($AppProfiles -split "," -contains $Profile)) {
        return $true
    }
    return $false
}

function Invoke-Certification {
    Write-HostColorized "Performing certification for profile: $($Profile.ToUpper())" $ColorBlue
    Write-HostColorized "Checking required tools..." $ColorYellow

    $missingTools = 0
    $securityWarnings = 0

    Write-HostColorized ("CHECKING TOOLS " + " APPLICATIONS FOR PROFILE: $($Profile.ToUpper())") $ColorBlue

    foreach ($appDef in $AppsDefinitions) {
        if (-not (Test-IsAppForProfile $appDef.Profiles)) {
            continue
        }

        Write-Host -NoNewline "Checking $($appDef.DisplayName)... "
        $installed = $false
        
        if ($appDef.VerificationCommand) {
            try {
                Invoke-Expression $appDef.VerificationCommand -ErrorAction Stop -OutVariable null | Out-Null
                $installed = $true
            } catch {
                $installed = $false
            }
        } elseif ($appDef.VerificationPath) {
            if (Test-Path $appDef.VerificationPath -PathType Leaf) {
                $installed = $true
            }
        } else {
            Write-HostColorized " (No verification method defined for type $($appDef.Type))" $ColorYellow
        }

        if ($installed) {
            Write-HostColorized "[OK]" $ColorGreen
        } else {
            Write-HostColorized "[MISSING]" $ColorRed
            $missingTools++
        }
    }
    
    Write-HostColorized "CHECKING GENERAL SECURITY: (Placeholder)" $ColorBlue

    Write-HostColorized "SUMMARY:" $ColorBlue
    if ($missingTools -eq 0 -and $securityWarnings -eq 0) {
        Write-HostColorized "All required tools for profile '$($Profile.ToUpper())' are installed and no security warnings!" $ColorGreen
        return $true
    } else {
        if ($missingTools -gt 0) {
            Write-HostColorized "[MISSING] Found $missingTools missing tool(s) for profile '$($Profile.ToUpper())" $ColorRed
            Write-HostColorized "Run with -Install -Profile $Profile to install missing tools" $ColorYellow
        }
        return $false
    }
}

function Invoke-Installation {
    Write-HostColorized "Performing installation for profile: $($Profile.ToUpper())" $ColorBlue

    Write-HostColorized ("INSTALLING TOOLS " + " APPLICATIONS FOR PROFILE: $($Profile.ToUpper())") $ColorBlue

    foreach ($appDef in $AppsDefinitions) {
        if (-not (Test-IsAppForProfile $appDef.Profiles)) {
            continue
        }

        Write-HostColorized "Processing $($appDef.DisplayName)..." $ColorGreen
        
        if ($appDef.ID -eq "automox" -and -not [string]::IsNullOrWhiteSpace($AutomoxKey)) {
            Write-HostColorized "   Attempting Automox installation (Windows method TBD)... Access Key: $AutomoxKey" $ColorYellow
        } elseif ($appDef.ID -eq "sentinelone" -and -not [string]::IsNullOrWhiteSpace($SentinelOneToken)) {
            Write-HostColorized "   Attempting SentinelOne installation (Windows method TBD)... Token: $SentinelOneToken" $ColorYellow
        } else {
            Write-HostColorized "   (Placeholder for $($appDef.DisplayName) installation - Type: $($appDef.Type))" $ColorYellow
        }
    }
    
    Write-HostColorized "Installation phase for profile '$($Profile.ToUpper())' complete (placeholders)!" $ColorGreen
    Write-HostColorized "Please restart your terminal or system if prompted by any installers." $ColorYellow
}

# --- Main Script Logic ---

if ($Help) {
    Show-Usage
}

Write-HostColorized "Selected profile: $($Profile.ToUpper())" $ColorBlue

if (-not $Certification -and -not $Install) {
    Write-HostColorized "[ERROR] No action specified (e.g., -Certification or -Install)." $ColorRed
    Show-Usage
}

if ($Certification) {
    Invoke-Certification
}

if ($Install) {
    Invoke-Installation
} 