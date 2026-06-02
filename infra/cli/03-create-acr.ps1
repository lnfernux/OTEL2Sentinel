param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AcrName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Basic', 'Standard', 'Premium')]
    [string]$Sku = 'Basic'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$acrExists = $null
try {
    $acrExists = az acr show --resource-group $ResourceGroupName --name $AcrName --query id -o tsv 2>$null
}
catch {
    $acrExists = $null
}

if ([string]::IsNullOrWhiteSpace($acrExists)) {
    Write-Host "ACR not found. Creating: $AcrName"
    az acr create --resource-group $ResourceGroupName --name $AcrName --sku $Sku --admin-enabled true | Out-Null

    Write-Host "ACR created: $AcrName"
}
else {
    Write-Host "ACR already exists: $AcrName"
}

$acrLoginServer = az acr show --resource-group $ResourceGroupName --name $AcrName --query loginServer -o tsv
Write-Host "ACR ready: $AcrName"
Write-Host "ACR login server: $acrLoginServer"
