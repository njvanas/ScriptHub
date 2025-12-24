<#
.SYNOPSIS
    Generates network topology map for Azure virtual networks.

.DESCRIPTION
    Creates a comprehensive network topology report including:
    - Virtual networks and subnets
    - Network security groups
    - Route tables
    - Peering connections
    - VPN gateways

.PARAMETER SubscriptionId
    Subscription ID to analyze. Uses current context if not specified.

.PARAMETER ResourceGroupName
    Optional resource group filter.

.PARAMETER ExportToCsv
    Path to export results as CSV.

.EXAMPLE
    Get-AzNetworkTopology -ExportToCsv "C:\Reports\NetworkTopology.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
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
    
    Write-Verbose "Retrieving network topology..."
    
    $vnets = Get-AzVirtualNetwork @params
    $topology = @()
    
    foreach ($vnet in $vnets) {
        foreach ($subnet in $vnet.Subnets) {
            $nsg = if ($subnet.NetworkSecurityGroup) {
                Get-AzNetworkSecurityGroup -ResourceId $subnet.NetworkSecurityGroup.Id -ErrorAction SilentlyContinue
            }
            
            $routeTable = if ($subnet.RouteTable) {
                Get-AzRouteTable -ResourceId $subnet.RouteTable.Id -ErrorAction SilentlyContinue
            }
            
            $topology += [PSCustomObject]@{
                VNetName = $vnet.Name
                VNetAddressSpace = ($vnet.AddressSpace.AddressPrefixes -join '; ')
                SubnetName = $subnet.Name
                SubnetAddressPrefix = $subnet.AddressPrefix
                NSGName = $nsg.Name
                NSGResourceGroup = $nsg.ResourceGroupName
                RouteTableName = $routeTable.Name
                RouteTableResourceGroup = $routeTable.ResourceGroupName
                Location = $vnet.Location
                ResourceGroupName = $vnet.ResourceGroupName
                PeeringConnections = (Get-AzVirtualNetworkPeering -VirtualNetworkName $vnet.Name -ResourceGroupName $vnet.ResourceGroupName -ErrorAction SilentlyContinue | Measure-Object).Count
            }
        }
    }
    
    Write-Verbose "Found $($vnets.Count) virtual networks with $($topology.Count) subnets"
    
    if ($ExportToCsv) {
        $topology | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Network topology exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $topology
}
catch {
    Write-Error "Failed to generate network topology: $_"
    throw
}

