# Move-Computers

An automated PowerShell script for managing Active Directory computer object placement. This script continuously monitors a source OU and automatically moves computer and server objects to their appropriate target OUs based on their operating system type.

## Purpose

The script runs in a loop (every 5 minutes) to automatically organize computer objects in Active Directory, enabling proper Group Policy application without manual intervention. It separates servers from workstations and moves them to appropriate organizational units.

## Features

- **Automatic Computer Organization**: Monitors a source OU and moves computers to designated target OUs
- **Server/Workstation Separation**: Automatically identifies servers (based on OS) and routes them to a different OU than regular workstations
- **Safety Delay**: Skips computer objects created within the last 10 minutes to allow for initial setup
- **WhatIf Support**: Test mode to preview changes without actually moving objects
- **Continuous Operation**: Runs in a loop until 11:30 PM daily
- **Remote Domain Controller Support**: Works with multiple domain controllers via PSRemoting

## Requirements

- **PowerShell Module**: `CommonScriptFunctions` (provides `Connect-ADSession`, `Clear-SessionData`, `Show-BlockInfo`, `Show-TestRun`)
- **Active Directory PowerShell Module**: Uses `Get-ADComputer` and `Move-ADObject` cmdlets
- **Permissions**: AD account with rights to query and move computer objects
- **Network Access**: Ability to connect to domain controllers via PowerShell Remoting

## Parameters

| Parameter | Alias | Type | Required | Description |
|-----------|-------|------|----------|-------------|
| `DomainControllers` | `DCs` | string[] | Yes | Array of domain controller names to connect to |
| `ADCredential` | - | PSCredential | Yes | Credentials for Active Directory authentication |
| `SourceOrgUnitPath` | `srcOU` | string | Yes | Distinguished name of the source OU to monitor |
| `CompOrgUnitPath` | `compOU` | string | Yes | Target OU for non-server computer objects |
| `ServerOrgUnitPath` | `serverOU` | string | Yes | Target OU for server objects |
| `WhatIf` | `wi` | switch | No | Run in test mode without making actual changes |

## Usage

### Basic Execution

```powershell
.\Move-Computers.ps1 `
  -DomainControllers "DC01.domain.com","DC02.domain.com" `
  -ADCredential (Get-Credential) `
  -SourceOrgUnitPath "OU=Computers,OU=New,DC=domain,DC=com" `
  -CompOrgUnitPath "OU=Workstations,DC=domain,DC=com" `
  -ServerOrgUnitPath "OU=Servers,DC=domain,DC=com"
```

### Test Mode (WhatIf)

```powershell
.\Move-Computers.ps1 `
  -DCs "DC01.domain.com" `
  -ADCredential $cred `
  -srcOU "OU=Computers,OU=New,DC=domain,DC=com" `
  -compOU "OU=Workstations,DC=domain,DC=com" `
  -serverOU "OU=Servers,DC=domain,DC=com" `
  -WhatIf
```

### With Parameter File

Create a `params.ps1` file (gitignored) with your environment-specific values:

```powershell
$global:params = @{
  DomainControllers = @("DC01.domain.com", "DC02.domain.com")
  ADCredential = (Get-Credential)
  SourceOrgUnitPath = "OU=Computers,OU=New,DC=domain,DC=com"
  CompOrgUnitPath = "OU=Workstations,DC=domain,DC=com"
  ServerOrgUnitPath = "OU=Servers,DC=domain,DC=com"
}
```

Then execute:
```powershell
.\params.ps1 # Creates a hashtable of parameters
.\Move-Computers.ps1 @params
```

## How It Works

1. **Connection**: Establishes PSRemoting session to domain controllers
2. **Discovery**: Queries the source OU for all computer objects
3. **Classification**: Determines if each object is a server (based on `OperatingSystem` property)
4. **Age Filter**: Skips objects created within the last 10 minutes
5. **Movement**: Moves objects to appropriate target OUs
6. **Loop**: Waits 5 minutes and repeats until 11:30 PM

### Processing Pipeline

```
Get-Computers → New-Object → Set-Ou → Skip-NewObjs → Move-Object
```

Each function operates on the pipeline:
- **Get-Computers**: Retrieves all computers from source OU
- **New-Object**: Wraps AD object in custom object with `ad` and `ou` properties
- **Set-Ou**: Assigns target OU based on OS type (server vs workstation)
- **Skip-NewObjs**: Filters out recently created objects (< 10 minutes old)
- **Move-Object**: Performs the actual AD move operation

## Scheduling

While the script contains its own loop mechanism, it's recommended to schedule it via:
- **Task Scheduler**: Run at system startup or specific times
- **Jenkins**: Automated CI/CD pipeline execution
- **Service**: Run as a Windows service for continuous operation

The script will automatically terminate at 11:30 PM each day to allow for maintenance windows.

## Logging

The script outputs colored console messages indicating actions:
- **Blue**: Computer movements
- **Green**: Server movements (legacy, now uses same Move-Object function)

Example output:
```
Move-Object,COMPUTER01,OU=Workstations
Move-Object,SERVER01,OU=Servers
```

## Safety Features

1. **10-Minute Delay**: New objects aren't moved immediately, preventing issues with objects still being configured
2. **WhatIf Mode**: Preview all changes before execution
3. **Daily Cutoff**: Stops at 11:30 PM to avoid conflicts with maintenance windows
4. **Object GUID**: Uses GUID instead of DN for move operations, more reliable during renames

## Troubleshooting

### Objects Not Moving
- Verify source OU path is correct
- Check that objects are older than 10 minutes
- Ensure credential has move permissions
- Run with `-WhatIf` to see what would happen

### Script Stops Prematurely
- Check if it's past 11:30 PM (automatic cutoff)
- Verify PSRemoting is enabled on domain controllers
- Check network connectivity to DCs

### Server Detected as Workstation (or vice versa)
- Verify the `OperatingSystem` property on the AD object
- The script checks if `OperatingSystem -like '*Server*'`

## Contributing

When modifying this script:
1. Test thoroughly with `-WhatIf` first
2. Ensure the pipeline functions maintain the custom object structure (`ad`, `ou` properties)
3. Update this README with any parameter or functionality changes
4. Consider the impact of loop timing changes on system load

## Version History

- **Latest**: Refactored to use functional pipeline approach with improved modularity
- **Previous**: Separate functions for computers and servers with duplicate logic

## License

Internal use for CUSD (Chico Unified School District)