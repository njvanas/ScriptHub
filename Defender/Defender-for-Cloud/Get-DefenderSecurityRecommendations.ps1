<#
.SYNOPSIS
    Gets security recommendations from Microsoft Defender for Cloud.

.DESCRIPTION
    Retrieves security recommendations and their remediation status using Azure Security Center API.

.PARAMETER SubscriptionId
    Subscription ID to query. Uses current context if not specified.

.PARAMETER Severity
    Filter by severity: Low, Medium, High, Critical.

.PARAMETER State
    Filter by state: New, Active, Resolved, Dismissed.

.PARAMETER ExportToCsv
    Path to export results as CSV.

.EXAMPLE
    Get-DefenderSecurityRecommendations -Severity Critical -ExportToCsv "C:\Reports\SecurityRecommendations.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Low', 'Medium', 'High', 'Critical')]
    [string]$Severity,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('New', 'Active', 'Resolved', 'Dismissed')]
    [string]$State,
    
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
    
    $context = Get-AzContext
    $subscriptionId = $context.Subscription.Id
    
    Write-Verbose "Retrieving security recommendations for subscription: $subscriptionId"
    
    # Get security assessments
    $assessments = Get-AzSecurityAssessment -ErrorAction SilentlyContinue
    
    if (-not $assessments) {
        Write-Warning "No security assessments found. Ensure Defender for Cloud is enabled."
        return @()
    }
    
    $recommendations = foreach ($assessment in $assessments) {
        $status = $assessment.Status
        $severityLevel = $assessment.AdditionalData.Severity
        
        # Apply filters
        if ($Severity -and $severityLevel -ne $Severity) { continue }
        if ($State -and $status.Code -ne $State) { continue }
        
        [PSCustomObject]@{
            AssessmentId = $assessment.Id
            DisplayName = $assessment.DisplayName
            Description = $assessment.Description
            Severity = $severityLevel
            Status = $status.Code
            StatusDescription = $status.Description
            ResourceId = $assessment.ResourceDetails.Id
            ResourceType = $assessment.ResourceDetails.Source
            RemediationDescription = $assessment.RemediationDescription
            AssessmentType = $assessment.AssessmentType
        }
    }
    
    Write-Verbose "Found $($recommendations.Count) recommendations"
    
    if ($ExportToCsv) {
        $recommendations | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Security recommendations exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $recommendations
}
catch {
    Write-Error "Failed to retrieve security recommendations: $_"
    throw
}

