<#
The scripts is to be run every few minutes. Its purpose it to move
computers (non-server) to a more agreeable OU so that GPO's can be applied
without extra effort.
#>
[cmdletbinding()]
param (
 [Parameter(Mandatory = $True)]
 [Alias('DCs')]
 [string[]]$DomainControllers,
 [Parameter(Mandatory = $True)]
 [System.Management.Automation.PSCredential]$ADCredential,
 [Parameter(Mandatory = $True)]
 [Alias('SrcOU')]
 [string]$SourceOrgUnitPath,
 [Parameter(Mandatory = $True)]
 [Alias('TargOU')]
 [string]$TargetOrgUnitPath,
 [Alias('wi')]
 [switch]$WhatIf
)

function Get-NewADComputers {
 Get-ADcomputer -Filter * -SearchBase $SourceOrgUnitPath -Properties * |
 Where-Object { $_.OperatingSystem -notlike "*Server*" -and { $_.Description -notlike "*Server*" } }
}

function Move-NewADComputers {
 process {
  $msgVars = $MyInvocation.MyCommand.Name, $_.name, $TargetOrgUnitPath.split(",")[0]
  Write-Host ('{0},{1},{2}' -f $msgVars )
  Move-ADObject -Identity $_.ObjectGUID -TargetPath $TargetOrgUnitPath -Whatif:$WhatIf
 }
}

function New-ADSession ([string[]]$cmdlets, $dc) {
 $adSession = New-PSSession -ComputerName $dc -Credential $ADCredential
 Import-PSSession -Session $adSession -Module ActiveDirectory -CommandName $cmdlets -AllowClobber
}


function Move-NewObjectsLoop {
 if ( (Get-Date) -ge (Get-Date '11:30pm')) { return }
 Clear-SessionData
 $dc = Select-DomainController $DomainControllers
 New-ADSession -cmdlets 'Get-ADcomputer', 'Move-ADObject' -dc $dc
 Get-NewADComputers | Move-NewADComputers
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