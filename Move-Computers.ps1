<#
The scripts is to be run every few minutes. Its purpose it to move
computers (non-server) to a more agreeable OU so that GPO's can be applied
without extra effort. Great job!
#>
[cmdletbinding()]
param (
 [Parameter(Mandatory = $True)]
 [System.Management.Automation.PSCredential]$ADCredential,
 [Parameter(Mandatory = $True)]
 [Alias('srcOU')]
 [string]$SourceOrgUnitPath,
 [Parameter(Mandatory = $True)]
 [Alias('compOU')]
 [string]$CompOrgUnitPath,
 [Alias('serverOU')]
 [string]$ServerOrgUnitPath,
 [Alias('wi')]
 [switch]$WhatIf
)

function Get-NewADComputers {
 Get-ADcomputer -Filter * -SearchBase $SourceOrgUnitPath -Properties * |
 Where-Object { $_.OperatingSystem -notlike "*Server*" -and { $_.Description -notlike "*Server*" } }
}
function Get-NewADServers {
 Get-ADcomputer -Filter * -SearchBase $SourceOrgUnitPath -Properties * |
 Where-Object { $_.OperatingSystem -like "*Server*" }
}

function Move-NewADComputers {
 process {
  $msgVars = $MyInvocation.MyCommand.Name, $_.name, $CompOrgUnitPath.split(",")[0]
  Write-Host ('{0},{1},{2}' -f $msgVars ) -Fore Blue
  Move-ADObject -Identity $_.ObjectGUID -TargetPath $CompOrgUnitPath -Whatif:$WhatIf
 }
}

function Move-NewADServers {
 process {
  $msgVars = $MyInvocation.MyCommand.Name, $_.name, $ServerOrgUnitPath.split(",")[0]
  Write-Host ('{0},{1},{2}' -f $msgVars ) -Fore Green
  Move-ADObject -Identity $_.ObjectGUID -TargetPath $ServerOrgUnitPath -Whatif:$WhatIf
 }
}

function New-ADSession ([string[]]$cmdlets, $dc) {
 $adSession = New-PSSession -ComputerName $dc -Credential $ADCredential
 Import-PSSession -Session $adSession -Module ActiveDirectory -CommandName $cmdlets -AllowClobber | Out-Null
}


function Move-NewObjectsLoop {
 if ( (Get-Date) -ge (Get-Date '11:30pm')) { return }
 Clear-SessionData
 $dc = Select-DomainController
 New-ADSession -cmdlets 'Get-ADComputer', 'Move-ADObject', 'Get-ADDomainController' -dc $dc
 Get-NewADComputers | Move-NewADComputers
 Get-NewADServers | Move-NewADServers
 if ($WhatIf) { return }
 Write-Verbose "Next run at $((Get-Date).AddSeconds(180))"
 Start-Sleep -Seconds 180
 Move-NewObjectsLoop
}

# main
. .\lib\Clear-SessionData.ps1
. .\lib\Select-DomainController.ps1
. .\lib\Show-TestRun.ps1

Show-TestRun
Move-NewObjectsLoop