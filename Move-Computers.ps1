<#
The scripts is to be run every few minutes. Its purpose it to move
computers (non-server) to a more agreeable OU so that GPO's can be applied
without extra effort. Great job!
#>
[cmdletbinding()]
param (
 [Parameter(Mandatory = $True)]
 [string[]]$DomainControllers,
 [Parameter(Mandatory = $True)]
 [System.Management.Automation.PSCredential]$ADCredential,
 [Parameter(Mandatory = $True)]
 [string]$SourceOrgUnitPath,
 [Parameter(Mandatory = $True)]
 [string]$CompOrgUnitPath,
 [Parameter(Mandatory = $True)]
 [string]$ServerOrgUnitPath,
 [Alias('wi')]
 [switch]$WhatIf
)

function Get-Computers ($ou) {
 process {
  Get-ADComputer -Filter * -SearchBase $ou -Properties * -Credential $ADCredential
 }
}

function Move-Object {
 process {
  $msgVars = $MyInvocation.MyCommand.Name, $_.ad.name, $_.ou.split(',')[0]
  Write-Host ('{0},{1},{2}' -f $msgVars ) -Fore Blue
  Move-ADObject -Identity $_.ad.ObjectGUID -TargetPath $_.ou -Credential $ADCredential -WhatIf:$WhatIf
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

function Move-NewObjectsLoop {
 if ( (Get-Date) -ge (Get-Date '11:30pm')) { return }
 Clear-SessionData
 Get-Computers -ou $SourceOrgUnitPath |
  New-Object |
   Set-Ou -defaultOU $CompOrgUnitPath -serverOU $ServerOrgUnitPath |
    Skip-NoOS |
     Move-Object
 if ($WhatIf) { return }
 Write-Verbose "Next run at $((Get-Date).AddSeconds(300))"
 if (!$WhatIf) { Start-Sleep 300 }
 Move-NewObjectsLoop
}

# ================================= main ==================================
Import-Module -Name CommonScriptFunctions -Cmdlet Clear-SessionData, Show-BlockInfo, Show-TestRun
Show-BlockInfo main

if ($WhatIf) { Show-TestRun }
Move-NewObjectsLoop
Get-Module -Name CommonScriptFunctions | Remove-Module -Confirm:$false