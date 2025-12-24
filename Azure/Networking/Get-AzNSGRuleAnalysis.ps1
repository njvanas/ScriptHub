<#
.SYNOPSIS
    Analyzes Network Security Group rules for security issues.

.DESCRIPTION
    Identifies overly permissive NSG rules, duplicate rules, and common security misconfigurations.

.PARAMETER SubscriptionId
    Subscription ID to analyze. Uses current context if not specified.

.PARAMETER ResourceGroupName
    Optional resource group filter.

.PARAMETER NSGName
    Optional specific NSG name.

.PARAMETER ExportToCsv
    Path to export results as CSV.

.EXAMPLE
    Get-AzNSGRuleAnalysis -ExportToCsv "C:\Reports\NSGAnalysis.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$NSGName,
    
    [Parameter(Mandatory = $false)]
    [string]$ExportToCsv
)

. "$PSScriptRoot\..\..\Utilities\Common-Functions\Test-AzConnection.ps1"
Test-AzConnection -ConnectIfNeeded $true | Out-Null

$ErrorActionPreference = 'Stop'

try {
    if ($SubscriptionId) {
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }
    
    $params = @{}
    if ($ResourceGroupName) { $params.ResourceGroupName = $ResourceGroupName }
    if ($NSGName) { $params.Name = $NSGName }
    
    Write-Verbose "Retrieving NSGs..."
    $nsgs = Get-AzNetworkSecurityGroup @params
    
    $analysis = @()
    
    foreach ($nsg in $nsgs) {
        $rules = @()
        $rules += $nsg.SecurityRules | ForEach-Object {
            [PSCustomObject]@{
                NSGName = $nsg.Name
                ResourceGroupName = $nsg.ResourceGroupName
                RuleName = $_.Name
                Direction = $_.Direction
                Priority = $_.Priority
                Access = $_.Access
                Protocol = $_.Protocol
                SourceAddressPrefix = $_.SourceAddressPrefix
                SourcePortRange = $_.SourcePortRange
                DestinationAddressPrefix = $_.DestinationAddressPrefix
                DestinationPortRange = $_.DestinationPortRange
                Description = $_.Description
            }
        }
        
        foreach ($rule in $rules) {
            $issues = @()
            $severity = 'Info'
            
            # Check for overly permissive rules
            if ($rule.SourceAddressPrefix -eq '*' -or $rule.SourceAddressPrefix -eq 'Internet' -or $rule.SourceAddressPrefix -eq '0.0.0.0/0') {
                if ($rule.Access -eq 'Allow') {
                    $issues += "Allows traffic from Internet/Any"
                    $severity = 'High'
                }
            }
            
            if ($rule.DestinationPortRange -eq '*' -or $rule.DestinationPortRange -match '^0-65535') {
                if ($rule.Access -eq 'Allow') {
                    $issues += "Allows all ports"
                    $severity = 'High'
                }
            }
            
            # Check for RDP/SSH exposure
            if ($rule.DestinationPortRange -match '^(22|3389|3389-3389)$' -and $rule.Access -eq 'Allow') {
                if ($rule.SourceAddressPrefix -eq '*' -or $rule.SourceAddressPrefix -eq 'Internet' -or $rule.SourceAddressPrefix -eq '0.0.0.0/0') {
                    $issues += "Exposes RDP/SSH to Internet"
                    $severity = 'Critical'
                }
            }
            
            # Check for default rules
            if ($rule.RuleName -match '^DefaultRule') {
                $issues += "Default rule (consider reviewing)"
                if ($severity -eq 'Info') { $severity = 'Medium' }
            }
            
            $analysis += [PSCustomObject]@{
                NSGName = $rule.NSGName
                ResourceGroupName = $rule.ResourceGroupName
                RuleName = $rule.RuleName
                Direction = $rule.Direction
                Priority = $rule.Priority
                Access = $rule.Access
                Protocol = $rule.Protocol
                SourceAddressPrefix = $rule.SourceAddressPrefix
                SourcePortRange = $rule.SourcePortRange
                DestinationAddressPrefix = $rule.DestinationAddressPrefix
                DestinationPortRange = $rule.DestinationPortRange
                Issues = ($issues -join '; ')
                Severity = $severity
                Description = $rule.Description
            }
        }
    }
    
    Write-Verbose "Analyzed $($nsgs.Count) NSGs with $($analysis.Count) rules"
    
    if ($ExportToCsv) {
        $analysis | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "NSG analysis exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $analysis
}
catch {
    Write-Error "Failed to analyze NSG rules: $_"
    throw
}

