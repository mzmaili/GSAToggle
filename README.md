# GSAToggle
The **GSAToggle script** is designed to enhance the user experience for Global Secure Access (GSA) users by seamlessly managing **Global Secure Access Client** based on network connectivity. This script **automates the enabling and disabling of GSA Client** without requiring any user intervention. When a user connects to the corporate network, GSA Client is automatically disabled, ensuring smooth internal resource access. Conversely, upon disconnection from the corporate network, GSA Client is automatically reactivated, maintaining secure remote connectivity.

# What challenge GSAToggle solves
There are rare/corner cases where organizations using Global Secure Access (GSA) require the flexibility to bypass GSA for direct access to the Internet, Microsoft 365, and private applications when users are connected to the corporate network, while ensuring these same applications remain accessible through GSA when users are working remotely. Managing this transition, enabling or disabling the Global Secure Access Client based on the user's network location can be operationally complex. The **GSAToggle script** addresses this challenge by providing an automated solution that seamlessly manages GSA Client, ensuring uninterrupted connectivity regardless of whether users are inside or outside the corporate network.

In certain scenarios, organizations may also require GSA to be fully disabled when users are on the corporate network, allowing Internet traffic to route directly through the corporate firewall. In such cases, GSA is automatically re-enabled once users disconnect from the corporate network, restoring secure remote access.

> [!WARNING]
> Disabling GSA will disable **all** protections and capabilities provided by Global Secure Access, including security policies, Conditional Access integration, and traffic forwarding profiles. Organizations should carefully evaluate this trade-off before deploying this solution.

# How GSAToggle works
The **GSAToggle** script creates a **Task Scheduler** named **GSAToggle** under the **Microsoft\GlobalSecureAccess** folder. This task is responsible for **automatically enabling or disabling Global Secure Access Client** based on the user's location.
It achieves this by starting/stopping **GlobalSecureAccessTunnelingService** and **GlobalSecureAccessEngineService** Windows services, automatically detecting whether the user is inside or outside the corporate network. The **GSAToggle Task Scheduler** is triggered whenever the following event is logged, which occurs each time a device connects to a network, whether via wired or wireless connection: <br>

<b>Event ID:</b> 10000<br>
<b>Source:</b> NetworkProfile<br>
<b>Log Name:</b> Microsoft-Windows-NetworkProfile/Operational

## Script requirements
- Global Secure Access Client should be installed before running the script.
- Intune license, if you need to to push the script using Microsoft Intune.

## How to use the script
- Download the `GSAToggle.ps1` script from [this](https://github.com/mzmaili/GSAToggle) GitHub repo.
- Open the script and modify `<Enter your Corp Network Name Here>` value of **$CorpNetworkName** parameter with your network(s).
   - If you have multiple networks, add a comma (,) between each network name like `"CorpNetwork1,CorpNetwork2,CorpNetwork3"`. Otherwise, add a single network name like `"OneCorpNetwork"`.
- Execute the `GSAToggle.ps1` script as needed, either directly on the device, via Intune, through Group Policy, or using SCCM.

## Running the script using Intune
1.	Sign in to the [Microsoft Intune admin center](https://intune.microsoft.com/) with the appropriate roles
2.	Navigate to **Devices** > **Windows** > **Scripts and remediations**
3. Open **Platform scripts** tab, click on **Add**, to add a new script as the following:
   - In **Basics** tab, Enter a name (e.g., 'GSAToggle Script')
   - In **Script settings** tab, select the script location and set all values to **No**
     
     ![Alt text](/media/Script_settings.png "Script_settings")
     
   - In **Assignments** tab, click on **Add all devices**.
   - In **Review + add** tab, click on **Add** button.

# How to Roll Back the Changes
Remove the **GSAToggle** task scheduler by running the following PowerShell command as an Administrator<br>
```PowerShell
Unregister-ScheduledTask -TaskName "GSAToggle" -TaskPath "\Microsoft\GlobalSecureAccess" -Confirm:$false
```

## Frequently asked questions
#### Does this script change anything?
Yes, it creates a **Task Scheduler** entry named **GSAToggle** under the **Microsoft\GlobalSecureAccess** folder.

#### Does this script require any PowerShell module to be installed?
No, the script does not require any PowerShell module.

<!--
## Manually: Run the script as an administrator
## Using Group Policy:

## User experience

-->
