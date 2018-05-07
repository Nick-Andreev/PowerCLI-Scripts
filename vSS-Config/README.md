### Description

When using virtual standard switches, switch configuration changes have to be manually applied to every host in a vSphere cluster. This script helps to automate this process by replicating the configuration across all hosts.

### Prerequisites

Download and install VMware PowerCLI from: https://my.vmware.com/en/web/vmware/downloads
Usage Examples

Script directly connects to each ESXi host in the cluster, therefore a list of ESXi hostnames or IP addresses is required, as well as the root password.

PS> .\vss-config-v1.0.ps1 -EsxHostnames "10.0.0.1,10.0.0.2,10.0.0.3" -RootPassword P@$$w0rd

Pick a selection from the list of available actions and script will request all required information in interactive mode.

If you have made a mistake, script provides remove and disconnect options to revert the changes. You will be provided with an option to choose which objects to remove or disconnect.

For detailed description see script help:

PS> Get-Help .\vss-config-v1.0.ps1 -full

### Environment Configuration

vSphere 6.0
PowerShell 4.0
PowerCLI 6.0

### Author

Nick Andreev:

nandreev@deloitte.com.au
https://niktips.wordpress.com
@nick_andreev_au