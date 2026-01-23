#
# Faria Installation Scripts - Common Utilities for PowerShell
# This file is inlined by the build system into the single-file installer.
# Do not execute directly.
#

# ============================================================================
# SYSTEM DETECTION
# ============================================================================

# Get system architecture
function Get-SystemArchitecture {
    return [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
}

# Check if a command exists
function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# ============================================================================
# DOWNLOAD HELPERS
# ============================================================================

# Download a file with progress
# Returns: $true on success, $false on failure
function Invoke-Download {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$Destination,
        [switch]$Silent
    )

    try {
        if ($Silent) {
            $ProgressPreference = 'SilentlyContinue'
        }
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
        $ProgressPreference = 'Continue'
        return $true
    } catch {
        Write-Host "Download failed: $_" -ForegroundColor Red
        return $false
    }
}

# Download a file using BITS transfer (with fallback to Invoke-WebRequest)
function Invoke-SmartDownload {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$Destination
    )

    try {
        Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
        return $true
    } catch {
        # Fallback to Invoke-WebRequest
        return Invoke-Download -Url $Url -Destination $Destination
    }
}

# ============================================================================
# VERSION COMPARISON
# ============================================================================

# Compare two semantic versions
# Returns: $true if $Current >= $Minimum
function Compare-Version {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Current,
        [Parameter(Mandatory=$true)]
        [string]$Minimum
    )

    try {
        return [Version]$Current -ge [Version]$Minimum
    } catch {
        # Fallback: string comparison
        return $Current -ge $Minimum
    }
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Print a section header
function Write-Header {
    param([string]$Text)
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  $Text" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
}

# Print a step header
function Write-Step {
    param(
        [int]$Step,
        [int]$Total,
        [string]$Name
    )
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "  Step ${Step}/${Total}: $Name" -ForegroundColor Blue
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
}

# Create a temporary directory
# Returns: path to temp directory
function New-TempDirectory {
    param([string]$Prefix = "faria")
    $TempPath = Join-Path $env:TEMP "$Prefix-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $TempPath | Out-Null
    return $TempPath
}

# Clean up a directory
function Remove-TempDirectory {
    param([string]$Path)
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check if running in interactive mode
function Test-Interactive {
    return [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
}

# Prompt for yes/no confirmation
# Returns: $true for yes, $false for no
function Confirm-Action {
    param(
        [string]$Prompt,
        [string]$Default = "n"
    )

    if (-not (Test-Interactive)) {
        # Non-interactive mode: use default
        return $Default -eq 'y' -or $Default -eq 'Y'
    }

    $response = Read-Host $Prompt
    return $response -eq 'y' -or $response -eq 'Y'
}

# Print success banner
function Write-SuccessBanner {
    param([string]$Text = "Installation Complete!")
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  $Text" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
}

# Print warning banner
function Write-WarningBanner {
    param([string]$Text)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  $Text" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
}
