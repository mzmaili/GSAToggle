<#

.SYNOPSIS
    GSAToggle V2.0 PowerShell script.

.DESCRIPTION
    There are rare/corner cases where organizations using Global Secure Access (GSA) require the flexibility to bypass GSA for direct access to the Internet, Microsoft 365, and private applications when users are connected to the corporate network, while ensuring these same applications remain accessible through GSA when users are working remotely. 
    Managing this transition, enabling or disabling the Global Secure Access Client based on the user's network location can be operationally complex. The GSAToggle script addresses this challenge by providing an automated solution that seamlessly manages GSA Client, ensuring uninterrupted connectivity regardless of whether users are inside or outside the corporate network.
    [!WARNING]
    Disabling GSA will disable all protections and capabilities provided by Global Secure Access, including security policies, Conditional Access integration, and traffic forwarding profiles. Organizations should carefully evaluate this trade-off before deploying this solution.
    For more info, visit: https://github.com/mzmaili/GSAToggle

.NOTES
    Before running the script, configure at least one of the following detection methods:
    1. $CorpNetworkName - Set to your corporate network name(s). Use a comma (,) to separate multiple names, e.g. "CorpNetwork1,CorpNetwork2,CorpNetwork3".
    2. $CorpPublicIP - Set to your corporate public IP address(es). Use a comma (,) to separate multiple IPs, e.g. "203.0.113.1,198.51.100.1".
    You can use either method or both together.

.PARAMETER CorpNetworkName
    The name(s) of the corporate network(s) to match against. Use a comma to separate multiple names, e.g. "CorpNetwork1,CorpNetwork2,CorpNetwork3".

.PARAMETER CorpPublicIP
    The public IP address(es) of the corporate network to match against. Use a comma to separate multiple IPs, e.g. "203.0.113.1,198.51.100.1".
    Note: This method requires outbound access to https://ifconfig.me/ip to resolve the machine's public IP.

.AUTHOR:
    Mohammad Zmaili

.EXAMPLE
    .\GSAToggle.ps1

#>


Function CreateGSAToggleTask($CorpNetworkName, $CorpPublicIP){

    # PowerShell script
    $PSScript = @"
`$AppName = "GSAToggle"
`$IsCorpNetwork = `$false
`$PublicIP = `$null
`$NetworkName = `$null
if(!([System.Diagnostics.EventLog]::SourceExists(`$AppName))) {
        [System.Diagnostics.EventLog]::CreateEventSource(`$AppName, 'Application')
}
if ('$CorpNetworkName' -ne '') {
    `$CorpNetworks = '$CorpNetworkName' -split ','
    `$NetworkName = if ((Get-WinEvent -FilterHashtable @{Logname='Microsoft-Windows-NetworkProfile/Operational';Id=10000} -MaxEvents 1).message -match 'Name:\s*(.+)') { `$matches[1].Trim() } else { `$null }
    foreach (`$CorpNetwork in `$CorpNetworks) {
        if (`$NetworkName -eq `$CorpNetwork) {
            `$IsCorpNetwork = `$true
            break
        }
    }
}
if (-not `$IsCorpNetwork -and '$CorpPublicIP' -ne '') {
    `$CorpIPs = '$CorpPublicIP' -split ','
    try {
        `$PublicIP = (Invoke-RestMethod -Uri 'https://ifconfig.me/ip' -TimeoutSec 10).Trim()
    } catch {
        Write-EventLog -LogName "Application" -Source `$AppName -EntryType "Error" -EventId 1001 -Message `$(`$_.Exception.Message)
        `$PublicIP = `$null
    }
    if (`$PublicIP -and `$CorpIPs -contains `$PublicIP) {
        `$IsCorpNetwork = `$true
    }
}
Write-EventLog -LogName "Application" -Source `$AppName -EntryType "Information" -EventId 1000 -Message "NetworkName: `$(`$NetworkName)`nPublicIP: `$(`$PublicIP)`nIsCorpNetwork: `$(`$IsCorpNetwork)"
`$timeout = [TimeSpan]::FromSeconds(15)
if (`$IsCorpNetwork) {
    foreach (`$svcName in @('GlobalSecureAccessTunnelingService','GlobalSecureAccessEngineService')) {
        try {
            Stop-Service `$svcName -Force -ErrorAction Stop
            `$svc = Get-Service -Name `$svcName
            `$svc.WaitForStatus('Stopped', `$timeout)
            `$final = Get-Service -Name `$svcName
            Write-EventLog -LogName "Application" -Source `$AppName -EntryType "Information" -EventId 1200 -Message "`$svcName `$(`$final.Status)"
        } catch {
            `$final = Get-Service -Name `$svcName
            Write-EventLog -LogName "Application" -Source `$AppName -EntryType "Error" -EventId 1201 -Message "`$svcName `$(`$final.Status)"
        }
    }
    exit
}
foreach (`$svcName in @('GlobalSecureAccessEngineService','GlobalSecureAccessTunnelingService')) {
    try {
        Start-Service -Name `$svcName -ErrorAction Stop
        `$svc = Get-Service -Name `$svcName
        `$svc.WaitForStatus('Running', `$timeout)
        `$final = Get-Service -Name `$svcName
        Write-EventLog -LogName "Application" -Source `$AppName -EntryType "Information" -EventId 1100 -Message "`$svcName `$(`$final.Status)"
    } catch {
        `$final = Get-Service -Name `$svcName
        Write-EventLog -LogName "Application" -Source `$AppName -EntryType "Error" -EventId 1101 -Message "`$svcName `$(`$final.Status)"
    }
}
"@

    # Define the task action
    $EncodedScript = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($PSScript))
    $arg = '-NoProfile -ExecutionPolicy Bypass -EncodedCommand ' + $EncodedScript
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arg

    #Trigger on event id 10000
    $CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
    $Trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
    $Trigger.Subscription = @"
    <QueryList><Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"><Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000]]</Select></Query></QueryList>
"@
    $Trigger.Enabled = $True
    $Trigger.Delay = "PT5S"

    #Set task principal
    $Prin = New-ScheduledTaskPrincipal -GroupId "SYSTEM"

    #Stop task if runs more than one minute
    $Timeout = (New-TimeSpan -Seconds 60)

    #Set name of task
    $TaskName = "GSAToggle"

    #Other settings on the task:
    $settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -StartWhenAvailable -DontStopIfGoingOnBatteries -ExecutionTimeLimit $Timeout

    #Create the task
    $task = New-ScheduledTask -Action $action -principal $Prin -Trigger $Trigger -Settings $settings

    #Register the task
    try {
        Register-ScheduledTask -TaskName $TaskName -InputObject $task -TaskPath "\Microsoft\GlobalSecureAccess\" -Force -ErrorAction Stop
        Write-Host "GSAToggle scheduled task registered successfully."
    } catch {
        Write-Error "Failed to register GSAToggle scheduled task: $_"
    }

}

# Before running the script, configure at least one of the following detection methods:
$CorpNetworkName = "" # Example "OneCorpNetwork" OR "CorpNetwork1,CorpNetwork2,CorpNetwork3"
$CorpPublicIP = "" # Example "203.0.113.1" OR "203.0.113.1,198.51.100.1"

CreateGSAToggleTask $CorpNetworkName $CorpPublicIP