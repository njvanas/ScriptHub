<#
.SYNOPSIS
    Writes log messages with timestamp and log level.

.DESCRIPTION
    Provides standardized logging functionality for scripts with support for different log levels
    and optional file output.

.PARAMETER Message
    The message to log.

.PARAMETER Level
    The log level: Info, Warning, Error, Verbose, Debug. Default is Info.

.PARAMETER LogFile
    Optional path to log file. If specified, logs will be written to both console and file.

.EXAMPLE
    Write-Log -Message "Starting script execution" -Level Info
    Write-Log -Message "Error occurred" -Level Error -LogFile "C:\Logs\script.log"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Info', 'Warning', 'Error', 'Verbose', 'Debug')]
    [string]$Level = 'Info',
    
    [Parameter(Mandatory = $false)]
    [string]$LogFile
)

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logEntry = "[$timestamp] [$Level] $Message"

switch ($Level) {
    'Error' { Write-Error $logEntry }
    'Warning' { Write-Warning $logEntry }
    'Verbose' { Write-Verbose $logEntry }
    'Debug' { Write-Debug $logEntry }
    default { Write-Host $logEntry -ForegroundColor Cyan }
}

if ($LogFile) {
    try {
        $logDir = Split-Path -Path $LogFile -Parent
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $LogFile -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

