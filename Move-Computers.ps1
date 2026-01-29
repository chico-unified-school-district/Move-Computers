<#
The scripts is to be run every few minutes. Its purpose it to move
computers (non-server) to a more agreeable OU so that GPO's can be applied
without extra effort. Great job!
#>
[cmdletbinding()]
param (
 [Parameter(Mandatory = $True)]
 [Alias('DCs')]
 [string[]]$DomainControllers,
 [Parameter(Mandatory = $True)]
 [System.Management.Automation.PSCredential]$ADCredential,
 [Parameter(Mandatory = $True)]
 [Alias('srcOU')]
 [string]$SourceOrgUnitPath,
 [Parameter(Mandatory = $True)]
 [Alias('compOU')]
 [string]$CompOrgUnitPath,
 [Parameter(Mandatory = $True)]
 [Alias('serverOU')]
 [string]$ServerOrgUnitPath,
 [Alias('wi')]
 [switch]$WhatIf
)

function Get-Computers ($ou) {
 process {
  Get-ADComputer -Filter * -SearchBase $ou -Properties *
 }
}

function Move-Object {
 process {
  $msgVars = $MyInvocation.MyCommand.Name, $_.ad.name, $_.ou.split(',')[0]
  Write-Host ('{0},{1},{2}' -f $msgVars ) -Fore Blue
  Move-ADObject -Identity $_.ad.ObjectGUID -TargetPath $_.ou -WhatIf:$WhatIf
 }
}

function New-Object {
 process {
  $obj = '' | Select-Object ad, ou
  $obj.ad = $_
  $obj.ou = $null
  $obj
 }
}

function Set-Ou ($defaultOU, $serverOU) {
 process {
  $_.ou = if (($_.ad.OperatingSystem -like '*Windows*') -and ($_.ad.OperatingSystem -notlike '*Server*')) {
   $defaultOU
  }
  else { $serverOU }
  $_
 }
}

function Skip-NoOS {
 process {
  if (!$_.ad.OperatingSystem) {
   Write-Host ('Skipping {0} due to missing OS' -f $_.ad.name) -Fore Red
   return
  }
  $_
 }
}

function Move-NewObjectsLoop ($dcs, $cred) {
 if ( (Get-Date) -ge (Get-Date '11:30pm')) { return }
 Clear-SessionData
 Connect-ADSession -DomainControllers $dcs -Credential $cred -Cmdlets 'Get-ADComputer', 'Move-ADObject'
 Get-Computers $SourceOrgUnitPath |
  New-Object |
   Set-Ou $CompOrgUnitPath $ServerOrgUnitPath |
    Skip-NoOS |
     Move-Object
 if ($WhatIf) { return }
 Write-Verbose "Next run at $((Get-Date).AddSeconds(300))"
 if (!$WhatIf) { Start-Sleep 300 }
 Move-NewObjectsLoop $dcs $cred
}

# ================================= main ==================================
Import-Module -Name CommonScriptFunctions -Cmdlet Connect-ADSession, Clear-SessionData, Show-BlockInfo, Show-TestRun
Show-BlockInfo main

if ($WhatIf) { Show-TestRun }
Move-NewObjectsLoop -dcs $DomainControllers -cred $ADCredential
Get-Module -Name CommonScriptFunctions | Remove-Module -Confirm:$false