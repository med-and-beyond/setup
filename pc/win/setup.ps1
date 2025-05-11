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
#>
param (
    [switch]$Help,
    [switch]$Certification,
    [switch]$Install,
    [ValidateSet("engineering", "data", "other")]
    [string]$Profile = "other" # Default profile
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
    @{ ID = "google-cloud-sdk"; DisplayName = "Google Cloud SDK"; Type = "direct_download"; Profiles = "all"; DownloadUrl = "https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe"; VerificationPath = "$($env:ProgramFiles)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd" }

    # CLI tools
    @{ ID = "jq"; DisplayName = "jq"; Type = "choco"; Profiles = "all"; ChocoPackageName = "jq"; VerificationCommand = "jq --version" }
    @{ ID = "gh"; DisplayName = "GitHub CLI"; Type = "choco"; Profiles = "engineering"; ChocoPackageName = "gh"; VerificationCommand = "gh --version" }
    @{ ID = "k9s"; DisplayName = "k9s"; Type = "choco"; Profiles = "engineering"; ChocoPackageName = "k9s"; VerificationCommand = "k9s version" }

    # GUI Applications (many available via Chocolatey)
    @{ ID = "docker"; DisplayName = "Docker Desktop"; Type = "choco"; Profiles = "engineering"; ChocoPackageName = "docker-desktop"; VerificationPath = "$($env:ProgramFiles)\Docker\Docker\Docker Desktop.exe" }
    @{ ID = "slack"; DisplayName = "Slack"; Type = "choco"; Profiles = "all"; ChocoPackageName = "slack"; VerificationPath = "$($env:LOCALAPPDATA)\Slack\slack.exe" }
    @{ ID = "twingate"; DisplayName = "Twingate"; Type = "manual_download"; Profiles = "all"; VerificationPath = "$($env:ProgramFiles)\Twingate\Twingate.exe" }
    @{ ID = "nordpass"; DisplayName = "NordPass"; Type = "direct_download"; Profiles = "all"; DownloadUrl = "https://downloads.npass.app/windows/NordPassSetup.exe"; VerificationPath = "$($env:LOCALAPPDATA)\Programs\NordPass\NordPass.exe" }
    @{ ID = "cursor"; DisplayName = "Cursor"; Type = "direct_download"; Profiles = "engineering,data"; DownloadUrl = "https://download.cursor.sh/windows/Cursor-Setup.exe"; VerificationPath = "$($env:LOCALAPPDATA)\Programs\cursor\Cursor.exe" }
    @{ ID = "dbeaver"; DisplayName = "DBeaver Community"; Type = "choco"; Profiles = "engineering,data"; ChocoPackageName = "dbeaver"; VerificationPath = "$($env:ProgramFiles)\DBeaver\dbeaver.exe" }
    @{ ID = "vscode"; DisplayName = "Visual Studio Code"; Type = "choco"; Profiles = "engineering,data"; ChocoPackageName = "vscode"; VerificationCommand = "code --version" }

    # gkc.sh equivalent for Windows (TBD - likely a PowerShell script or different auth method)
    @{ ID = "gkc-win"; DisplayName = "GKE Cluster Connect Utility (Win)"; Type = "placeholder"; Profiles = "engineering" }
)

# --- Function Definitions ---

function Show-Usage {
    Write-HostColorized "This script is under development. Current parameters:" $ColorYellow
    
    # Replace problematic Get-Help call with direct help text
    Write-HostColorized "Usage: .\setup.ps1 [options]" $ColorYellow
    Write-HostColorized "Options:" $ColorYellow
    Write-HostColorized "  -Help                Show this help message" $ColorYellow
    Write-HostColorized "  -Certification       Check what tools are missing for selected profile" $ColorYellow
    Write-HostColorized "  -Install             Install all required tools for selected profile" $ColorYellow
    Write-HostColorized "  -Profile <string>    User profile (engineering, data, or other). Default: other" $ColorYellow
    
    Write-HostColorized "Examples:" $ColorYellow
    Write-HostColorized "  .\setup.ps1 -Help" $ColorYellow
    Write-HostColorized "  .\setup.ps1 -Certification -Profile engineering" $ColorYellow
    Write-HostColorized "  .\setup.ps1 -Install -Profile data" $ColorYellow
    Write-HostColorized "  .\setup.ps1 -Install -Profile engineering" $ColorYellow
    
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

    Write-HostColorized ("CHECKING TOOLS AND APPLICATIONS FOR PROFILE: $($Profile.ToUpper())") $ColorBlue

    foreach ($appDef in $AppsDefinitions) {
        if (-not (Test-IsAppForProfile $appDef.Profiles)) {
            continue
        }

        Write-Host -NoNewline "Checking $($appDef.DisplayName)... "
        $installed = $false
        
        # Special case for Google Cloud SDK
        if ($appDef.ID -eq "google-cloud-sdk") {
            # Try multiple possible installation paths for gcloud
            $gcloudPaths = @(
                "$($env:ProgramFiles)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
                "$($env:ProgramFiles)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.exe",
                "$($env:ProgramFiles)\Google\Cloud SDK\bin\gcloud.cmd",
                "$($env:ProgramFiles)\Google\Cloud SDK\bin\gcloud.exe",
                "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
                "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.exe",
                "$HOME\google-cloud-sdk\bin\gcloud.cmd",
                "$HOME\google-cloud-sdk\bin\gcloud.exe",
                "$env:APPDATA\gcloud\bin\gcloud.cmd",
                "$env:APPDATA\gcloud\bin\gcloud.exe"
            )
            
            $gcloudPath = $null
            foreach ($path in $gcloudPaths) {
                if (Test-Path $path -PathType Leaf) {
                    $gcloudPath = $path
                    $installed = $true
                    break
                }
            }
            
            if ($installed) {
                Write-HostColorized "[OK]" $ColorGreen
                $binPath = Split-Path -Parent $gcloudPath
                Write-HostColorized "  Found at: $gcloudPath" $ColorGreen
                
                # Update PATH if gcloud directory is not in PATH
                $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
                if (-not $currentPath.Contains($binPath)) {
                    Write-HostColorized "  Adding Google Cloud SDK to your PATH..." $ColorYellow
                    [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$binPath", "User")
                    Write-HostColorized "  Added to PATH. You'll need to restart your terminal to use it." $ColorYellow
                }
            } else {
                Write-HostColorized "[MISSING]" $ColorRed
                $missingTools++
            }
            continue  # Skip the rest of the loop for Google Cloud SDK
        }
        
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
    Write-HostColorized "Note: Security tools Automox and SentinelOne are managed by Intune." $ColorBlue

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

    Write-HostColorized ("INSTALLING TOOLS AND APPLICATIONS FOR PROFILE: $($Profile.ToUpper())") $ColorBlue
    
    # First check if we're running as admin - many installations require this
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-HostColorized "WARNING: Not running as Administrator. Some installations may fail." $ColorYellow
        Write-HostColorized "Consider restarting this script as Administrator." $ColorYellow
    }
    
    # Install Chocolatey first if it's not already installed
    $chocoInstalled = $false
    try {
        $chocoVersion = choco --version
        Write-HostColorized "Chocolatey is already installed: $chocoVersion" $ColorGreen
        $chocoInstalled = $true
    } catch {
        Write-HostColorized "Installing Chocolatey package manager..." $ColorYellow
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            $chocoInstalled = $true
            Write-HostColorized "Chocolatey installed successfully!" $ColorGreen
        } catch {
            Write-HostColorized "Failed to install Chocolatey. Error: $_" $ColorRed
        }
    }
    
    if (-not $chocoInstalled) {
        Write-HostColorized "Chocolatey installation failed. Cannot proceed with package installations." $ColorRed
        return
    }

    foreach ($appDef in $AppsDefinitions) {
        if (-not (Test-IsAppForProfile $appDef.Profiles)) {
            continue
        }

        Write-HostColorized "Processing $($appDef.DisplayName)..." $ColorGreen
        
        # Check if already installed
        $alreadyInstalled = $false
        if ($appDef.VerificationCommand) {
            try {
                Invoke-Expression $appDef.VerificationCommand -ErrorAction Stop -OutVariable null | Out-Null
                $alreadyInstalled = $true
                Write-HostColorized "  Already installed." $ColorGreen
            } catch {
                $alreadyInstalled = $false
            }
        } elseif ($appDef.VerificationPath) {
            if (Test-Path $appDef.VerificationPath -PathType Leaf) {
                $alreadyInstalled = $true
                Write-HostColorized "  Already installed." $ColorGreen
            }
        }
        
        if ($alreadyInstalled) {
            continue
        }
        
        # Install based on type
        switch ($appDef.Type) {
            "choco" {
                try {
                    Write-HostColorized "  Installing $($appDef.DisplayName) via Chocolatey..." $ColorYellow
                    choco install $appDef.ChocoPackageName -y
                    Write-HostColorized "  Installation successful!" $ColorGreen
                } catch {
                    Write-HostColorized "  Failed to install $($appDef.DisplayName). Error: $_" $ColorRed
                }
            }
            
            "direct_download" {
                try {
                    Write-HostColorized "  Installing $($appDef.DisplayName) via direct download..." $ColorYellow
                    
                    # Create temp directory if it doesn't exist
                    $tempDir = "$env:TEMP\direct_install"
                    if (-not (Test-Path $tempDir)) {
                        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                    }
                    
                    # Download the installer
                    $installerFileName = [System.IO.Path]::GetFileName($appDef.DownloadUrl)
                    if (-not $installerFileName -or $installerFileName -eq "") {
                        $installerFileName = "$($appDef.ID)_installer.exe"
                    }
                    $installerPath = "$tempDir\$installerFileName"
                    Write-HostColorized "  Downloading from $($appDef.DownloadUrl)..." $ColorYellow
                    
                    # Use more robust download method
                    $webClient = New-Object System.Net.WebClient
                    $webClient.Headers.Add("User-Agent", "PowerShell/Setup-Script")
                    try {
                        $webClient.DownloadFile($appDef.DownloadUrl, $installerPath)
                    } catch {
                        Write-HostColorized "  Standard download failed. Trying with Invoke-WebRequest..." $ColorYellow
                        try {
                            Invoke-WebRequest -Uri $appDef.DownloadUrl -OutFile $installerPath -UseBasicParsing
                        } catch {
                            throw $_  # Re-throw to outer catch block
                        }
                    }
                    
                    # Run the installer with appropriate arguments based on file type
                    Write-HostColorized "  Running installer..." $ColorYellow
                    $fileExtension = [System.IO.Path]::GetExtension($installerPath).ToLower()
                    
                    if ($fileExtension -eq ".msi") {
                        # MSI installer
                        Start-Process "msiexec.exe" -ArgumentList "/i `"$installerPath`" /quiet /norestart" -Wait
                    } elseif ($appDef.ID -eq "google-cloud-sdk") {
                        # Special case for Google Cloud SDK - needs interactive installer
                        Write-HostColorized "  Google Cloud SDK requires interactive installation. Launching installer..." $ColorYellow
                        Write-HostColorized "  NOTE: After installation completes, you may need to restart your terminal to use gcloud commands." $ColorYellow
                        Start-Process -FilePath $installerPath -Wait
                    } else {
                        # EXE installer - assume silent install flags
                        Start-Process -FilePath $installerPath -ArgumentList "/S", "/quiet", "/norestart" -Wait
                    }
                    
                    Write-HostColorized "  Installation completed. Cleaning up..." $ColorGreen
                    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                    
                    # Special handling for Google Cloud SDK
                    if ($appDef.ID -eq "google-cloud-sdk") {
                        Write-HostColorized "  Looking for installed Google Cloud SDK..." $ColorYellow
                        
                        # Try multiple possible installation paths for gcloud
                        $gcloudPaths = @(
                            "$($env:ProgramFiles)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
                            "$($env:ProgramFiles)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.exe",
                            "$($env:ProgramFiles)\Google\Cloud SDK\bin\gcloud.cmd",
                            "$($env:ProgramFiles)\Google\Cloud SDK\bin\gcloud.exe",
                            "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
                            "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.exe",
                            "$HOME\google-cloud-sdk\bin\gcloud.cmd",
                            "$HOME\google-cloud-sdk\bin\gcloud.exe",
                            "$env:APPDATA\gcloud\bin\gcloud.cmd",
                            "$env:APPDATA\gcloud\bin\gcloud.exe"
                        )
                        
                        $gcloudPath = $null
                        foreach ($path in $gcloudPaths) {
                            if (Test-Path $path -PathType Leaf) {
                                $gcloudPath = $path
                                break
                            }
                        }
                        
                        if ($gcloudPath) {
                            $binPath = Split-Path -Parent $gcloudPath
                            Write-HostColorized "  Found Google Cloud SDK at: $gcloudPath" $ColorGreen
                            
                            # Update PATH if gcloud directory is not in PATH
                            $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
                            if (-not $currentPath.Contains($binPath)) {
                                Write-HostColorized "  Adding Google Cloud SDK to your PATH..." $ColorYellow
                                [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$binPath", "User")
                                Write-HostColorized "  PATH updated. You'll need to restart your terminal to use gcloud commands." $ColorYellow
                            } else {
                                Write-HostColorized "  Google Cloud SDK is already in your PATH." $ColorGreen
                            }
                        } else {
                            Write-HostColorized "  Could not find Google Cloud SDK installation. Check if installation was successful." $ColorRed
                        }
                    }
                } catch {
                    Write-HostColorized "  Failed to install $($appDef.DisplayName). Error: $_" $ColorRed
                }
            }
            
            "core_packagemanager" {
                # Already handled Chocolatey above
                Write-HostColorized "  Core package manager already checked." $ColorYellow
            }
            
            "manual_download" {
                Write-HostColorized "  $($appDef.DisplayName) requires manual download and installation." $ColorYellow
                Write-HostColorized "  Please visit the official website to download and install." $ColorYellow
                
                # For specific known applications, provide more detailed instructions
                switch ($appDef.ID) {
                    "twingate" {
                        Write-HostColorized "  Twingate: Please download from https://www.twingate.com/download/" $ColorYellow
                        Write-HostColorized "  Or use this direct link: https://www.twingate.com/download/Twingate-windows-x86_64.msi" $ColorYellow
                    }
                    "google-cloud-sdk" {
                        Write-HostColorized "  Google Cloud SDK: https://cloud.google.com/sdk/docs/install" $ColorYellow
                    }
                    "cursor" {
                        Write-HostColorized "  Cursor: https://cursor.sh/download" $ColorYellow
                    }
                }
            }
            
            default {
                Write-HostColorized "  Unknown installation type: $($appDef.Type)" $ColorYellow
                Write-HostColorized "  Please install $($appDef.DisplayName) manually." $ColorYellow
            }
        }
    }
    
    Write-HostColorized "Installation phase for profile '$($Profile.ToUpper())' complete!" $ColorGreen
    Write-HostColorized "Note: Security tools (Automox and SentinelOne) are managed by Intune." $ColorBlue
    Write-HostColorized "⚠️ IMPORTANT: You may need to restart your terminal or PowerShell session to use newly installed tools." $ColorYellow
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