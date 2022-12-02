#Requires -Version 3.0

Param(
  [string] $Environment = 'sod',
  [switch] $ValidateOnly
)

Write-Output '', 'Start Deploy-Metering'

try {
  [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ', '_'), '3.0.0')
}
catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
  param ($ValidationOutput, [int] $Depth = 0)
  Set-StrictMode -Off
  return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

$ResourceGroupLocation = 'Norway East'
$ResourceGroupName = "rg-mirroring-$($Environment)"
$TemplateFile = 'Mirroring.bicep'
$TemplateParametersFile = "Mirroring.$($Environment).parameters.json"

# Generate random SQL admin password. We use Azure AD and MSI to access the data, so admin password is needed only to run db migration
$SqlAdministratorPassword = "Ph1" + (-join ((35..58) + (65..90) + (97..122) | Get-Random -Count 25 | ForEach-Object {[char]$_}))
$SecureSqlAdministratorPassword = ConvertTo-SecureString $SqlAdministratorPassword -AsPlainText -Force

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

# Create the resource group only when it doesn't already exist
if ($null -eq (Get-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -ErrorAction SilentlyContinue)) {
  New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force -ErrorAction Stop
}

if ($ValidateOnly) {
  $ErrorMessages = Format-ValidationOutput (Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
      -TemplateFile $TemplateFile `
      -TemplateParameterFile $TemplateParametersFile `
      @OptionalParameters)
  if ($ErrorMessages) {
    Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
   [Environment]::Exit(1)
  }
  Write-Output '', 'Template is valid.'
  Exit 0
}

$outputs = New-AzResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
  -ResourceGroupName $ResourceGroupName `
  -TemplateFile $TemplateFile `
  -environment $Environment `
  -TemplateParameterFile $TemplateParametersFile `
  -sqlAdministratorPassword $SecureSqlAdministratorPassword `
  -Force -Verbose `
  -ErrorVariable ErrorMessages
if ($ErrorMessages) {
  Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
  [Environment]::Exit(1)
}

Write-Output '', 'Template is valid.'

$WebAppName = $outputs.Outputs['webAppName'].value
$ConnectionBase = $outputs.Outputs['baseDatabaseConnectionString'].value


# Output from PS
Write-Host
Write-Host "Outputs:"
Write-Host "WebAppName = $WebAppName"
Write-Host "ConnectionBase = $ConnectionBase"
Write-Host "About to set outpus variables"
Write-Host "##vso[task.setvariable variable=WebAppName]$WebAppName"
Write-Host "##vso[task.setvariable variable=ConnectionBase]$ConnectionBase"