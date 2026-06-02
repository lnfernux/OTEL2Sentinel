param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

az account set --subscription $SubscriptionId | Out-Null

$groupExists = az group exists --name $ResourceGroupName
if ($groupExists -eq 'true') {
    Write-Host "Resource group already exists: $ResourceGroupName"
}
else {
    az group create --name $ResourceGroupName --location $Location | Out-Null
    Write-Host "Resource group created: $ResourceGroupName ($Location)"
}

Write-Host "Resource group ready: $ResourceGroupName ($Location)"
