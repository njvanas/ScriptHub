<#
.SYNOPSIS
    Tests Azure PowerShell connection and module availability.

.DESCRIPTION
    Verifies that required Az PowerShell modules are installed and the user is authenticated
    to Azure. Optionally connects if not authenticated.

.PARAMETER ConnectIfNeeded
    If true, attempts to connect to Azure if not already authenticated.

.PARAMETER RequiredModules
    Array of required Az modules. Default: Az.Accounts, Az.Resources

.EXAMPLE
    Test-AzConnection -ConnectIfNeeded $true
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ConnectIfNeeded,
    
    [Parameter(Mandatory = $false)]
    [string[]]$RequiredModules = @('Az.Accounts', 'Az.Resources')
)

$ErrorActionPreference = 'Stop'

# Check module availability
foreach ($module in $RequiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        throw "Required module $module is not installed. Install with: Install-Module -Name $module -Force -AllowClobber"
    }
    
    if (-not (Get-Module -Name $module)) {
        Import-Module -Name $module -ErrorAction Stop
    }
}

# Check authentication
try {
    $context = Get-AzContext -ErrorAction Stop
    Write-Verbose "Authenticated as: $($context.Account.Id) in subscription: $($context.Subscription.Name)"
    return $true
}
catch {
    if ($ConnectIfNeeded) {
        Write-Verbose "Not authenticated. Attempting to connect..."
        try {
            Connect-AzAccount -ErrorAction Stop
            Write-Verbose "Successfully connected to Azure"
            return $true
        }
        catch {
            throw "Failed to connect to Azure: $_"
        }
    }
    else {
        throw "Not authenticated to Azure. Run Connect-AzAccount or use -ConnectIfNeeded"
    }
}

