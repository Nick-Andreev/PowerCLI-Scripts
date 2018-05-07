### Description

This script attaches a Nimble storage array to a VMware cluster by doing the following:

* Creating a Nimble iSCSI initiator group with Software iSCSI Adaptor IQNs from all cluster hosts
* Adding Nimble discovery IPs to VMware hosts' Software iSCSI Adaptor

### Prerequisites

* Download Nimble PowerShell ToolKit from Nimble InfoSight > Software Downloads > Integration Kits: https://infosight.nimblestorage.com/InfoSight/#software/Integration+Kits/Nimble+PowerShell+Toolkit+%28NPT%29
* Extract contents of the .zip file into C:\Windows\system32\WindowsPowerShell\v1.0\Modules\NimblePowerShellToolKit
* Download and install VMware PowerCLI from: https://my.vmware.com/en/web/vmware/downloads

### Usage Examples

```
PS> .\attach-nimble-1.0.ps1 -VIServerName vc01.acme.com -ClusterName Production -ArrayIP 192.168.1.111 -iGroupname VMware-ESX -Targets 192.168.2.100, 192.168.3.200
```

You will be requested for vCenter server credentials, followed by Nimble storage array credentials.

For detailed description of input parameters see script help:

```
PS> Get-Help .\attach-nimble-1.0.ps1 -full
```

### Environment Configuration

* PowerShell 3.0
* PowerCLI 6.5.0
* Nimble PowerShell ToolKit 1.0.0

## Author

Nick Andreev:

* https://niktips.wordpress.com
* @nick_andreev_au