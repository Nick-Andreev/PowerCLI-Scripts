### Description

If you ever had to build a new vCenter when upgrading between vSphere versions, you know that recreating the same alert actions on the new vCenter is a very time-consuming task.

This script helps to automate it, by copying vCenter email actions from source to destination vCenter, preserving the same destination email addresses and action triggers.

### Limitations

Script copies email actions only. Actions of other types (such as SNMP traps) and alert triggers are not supported and have to be copied manually.

Script also expects alert definitions from the source vCenter to exist on the destination vCenter, otherwise email action will not be copied across.

### Prerequisites

* Download and install VMware PowerCLI from: https://my.vmware.com/en/web/vmware/downloads
* Configure mail server settings in vCenter

### Usage Examples

```
PS> .\copy-vcenter-alerts-v1.0.ps1 -SourceVcenter old-vc.acme.com -DestinationVcenter new-vc.acme.com
```

For detailed description see script help:

```
PS> Get-Help .\copy-vcenter-alerts-v1.0.ps1 -full
```

### Environment Configuration

* PowerCLI 6.5.0

### Author

Nick Andreev:

* https://niktips.wordpress.com
* @nick_andreev_au