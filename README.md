# GSAToggle

The **GSAToggle** script automates the management of the **Global Secure Access (GSA) Client** based on network location. When a device connects to the corporate network, GSA Client is automatically disabled to allow direct access to resources. When the device disconnects from the corporate network, GSA Client is automatically re-enabled to maintain secure remote connectivity — all without user intervention.

## What challenge GSAToggle solves

There are scenarios where organizations using Global Secure Access require the flexibility to bypass GSA for direct access to the Internet, Microsoft 365, and private applications when users are on the corporate network, while ensuring traffic is routed through GSA when users are working remotely. Managing this transition manually is operationally complex and error-prone. The **GSAToggle** script addresses this challenge by providing an automated, event-driven solution that toggles GSA Client based on network connectivity.

> [!WARNING]
> Disabling GSA will disable **all** protections and capabilities provided by Global Secure Access, including security policies, Conditional Access integration, and traffic forwarding profiles. Organizations should carefully evaluate this trade-off before deploying this solution.

## How GSAToggle works

The script creates a **Scheduled Task** named **GSAToggle** under the **Microsoft\GlobalSecureAccess** folder in Task Scheduler. The task is triggered whenever the following event is logged, which occurs each time a device establishes a network connection (wired or wireless):

| Property | Value |
| --- | --- |
| **Event ID** | 10000 |
| **Source** | Microsoft-Windows-NetworkProfile |
| **Log** | Microsoft-Windows-NetworkProfile/Operational |

Upon triggering, the task waits 5 seconds to allow the event to fully propagate, then determines whether the device is on the corporate network using one of two detection methods:

### Detection methods

| Method | Parameter | Description |
| --- | --- | --- |
| **Network name** | `$CorpNetworkName` | Matches the connected network name from the Event 10000 log entry against a configured list of corporate network names. |
| **Public IP** | `$CorpPublicIP` | Resolves the device's public IP via `https://ifconfig.me/ip` and compares it against a configured list of corporate public IP addresses. |

Configure at least one method. Both can be used together — the network name is checked first, and the public IP check runs only if the name does not match.

### Toggle behavior

| Location | Action |
| --- | --- |
| **On corporate network** | Stops `GlobalSecureAccessTunnelingService` first, then `GlobalSecureAccessEngineService` (disables GSA). |
| **Off corporate network** | Starts `GlobalSecureAccessEngineService` first, then `GlobalSecureAccessTunnelingService` (enables GSA). |

Each service operation has a **15-second timeout** to wait for the expected status. The scheduled task itself has a **60-second execution time limit**.

### Event logging

The script logs all activity to the **Windows Application Event Log** under a custom source named **GSAToggle**.

| Event ID | Type | Description |
| --- | --- | --- |
| 1000 | Information | Logs detected network name, public IP, and corporate network status on each trigger. |
| 1001 | Error | Public IP resolution failed (e.g., `https://ifconfig.me/ip` unreachable). |
| 1100 | Information | GSA service started successfully. |
| 1101 | Error | GSA service failed to start. |
| 1200 | Information | GSA service stopped successfully. |
| 1201 | Error | GSA service failed to stop. |

## Prerequisites

- Global Secure Access Client must be installed on the device.
- The script must be executed with **Administrator** privileges (the scheduled task runs as SYSTEM).
- If using the public IP detection method, outbound HTTPS access to `https://ifconfig.me/ip` must be allowed.
- Intune license, if deploying the script via Microsoft Intune.

## How to use the script

1. Download the `GSAToggle.ps1` script from [this repository](https://github.com/mzmaili/GSAToggle).
2. Open the script and configure at least one detection method:
   - **Network name:** Set `$CorpNetworkName` to your corporate network name(s).
     - Single network: `"CorpNetwork1"`
     - Multiple networks: `"CorpNetwork1,CorpNetwork2,CorpNetwork3"`
   - **Public IP:** Set `$CorpPublicIP` to your corporate public IP address(es).
     - Single IP: `"203.0.113.1"`
     - Multiple IPs: `"203.0.113.1,198.51.100.1"`
3. Execute `GSAToggle.ps1` as an Administrator — either directly on the device, via Intune, through Group Policy, or using SCCM.

## Deploying the script via Intune

1. Sign in to the [Microsoft Intune admin center](https://intune.microsoft.com/) with the appropriate roles.
2. Navigate to **Devices** > **Windows** > **Scripts and remediations**.
3. Open the **Platform scripts** tab and click **Add** to create a new script:
   - **Basics:** Enter a name (e.g., `GSAToggle Script`).
   - **Script settings:** Select the script file and set all options to **No**.

     ![Script settings](/media/Script_settings.png "Script_settings")

   - **Assignments:** Click **Add all devices**.
   - **Review + add:** Click **Add**.

## How to roll back

Remove the **GSAToggle** scheduled task by running the following PowerShell command as an Administrator:

```PowerShell
Unregister-ScheduledTask -TaskName "GSAToggle" -TaskPath "\Microsoft\GlobalSecureAccess" -Confirm:$false
```

## FAQ

### Does this script modify the system?

Yes, it creates a Scheduled Task named **GSAToggle** under the **Microsoft\GlobalSecureAccess** folder.

### Does this script require any PowerShell modules?

No. The script uses only built-in Windows cmdlets.

### Which detection method should I use?

- Use **network name** if your corporate network has a consistent, identifiable name across all locations.
- Use **public IP** if your organization routes all traffic through a known set of public IP addresses (e.g., a corporate proxy or firewall).
