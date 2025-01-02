function Select-DomainController {
 begin {
  # $myDCs = Get-ADDomain | Select-Object -ExpandProperty ReplicaDirectoryServers
  $myDCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty Name
 }
 process {
  $dc = Get-Random $myDCs
  if ( Test-Connection -ComputerName $dc -Count 1 -ErrorAction SilentlyContinue ) { return $dc }
  else {
   $msg = $MyInvocation.MyCommand.Name, $dc
   Write-Host ('{0},{1} Not responding. Trying random Domain Controller in 30 seconds...' -f $msg)
   Start-Sleep 30
   Select-DomainController2 $myDCs
  }
 }
}
