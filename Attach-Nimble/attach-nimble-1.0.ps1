<#

.SYNOPSIS
This script attaches a Nimble storage array to a VMware cluster.

.DESCRIPTION
Script performs the following tasks:
1. Creates a Nimble iSCSI initiator group with software iSCSI adaptor IQNs from all cluster hosts.
2. Adds specified Nimble discovery IPs to VMware hosts' software iSCSI adaptor.

Script prompts for vCenter server credentials, followed by Nimble storage array credentials. 

.PARAMETER VIServerName
VMware vCenter server host name or IP address

.PARAMETER ClusterName
VMware ESXi host cluster name

.PARAMETER ArrayIP
Nimble storage array management IP address

.PARAMETER iGroupName
Name for the new Nimble storage array initiator group

.PARAMETER Targets
Comma separated list of Nimble storage array discovery IP addresses to be added to VMware ESXi hosts' software iSCSI adapter dynamic discovery list

.EXAMPLE
.\attach-nimble-1.0.ps1 -VIServerName vc01.acme.com -ClusterName Production -ArrayIP 192.168.1.111 -iGroupname VMware-ESX

.NOTES
Nimble PowerShell Toolkit and VMware PowerCLI are requred for script to run
   
.LINK
http://niktips.wordpress.com

#>

Param(
	[Parameter(Mandatory = $true)][string]$VIServerName,
	[Parameter(Mandatory = $true)][string]$ClusterName,
	[Parameter(Mandatory = $true)][string]$ArrayIP,
	[Parameter(Mandatory = $true)][string]$iGroupName,
	[Parameter(Mandatory = $true)][string[]]$Targets
)

Import-Module VMware.VimAutomation.Core
Import-Module NimblePowerShellToolkit
Connect-ViServer $VIServerName | out-null
if(!$?) { exit }

Get-Cluster $ClusterName | out-null
if(!$?) { exit }

Connect-NSGroup -Group $ArrayIP | out-null
Write-Host "Creating initiator group ""$iGroupName""." -foreground green
$iGroup = New-NSInitiatorGroup -Name $iGroupName -access_protocol "iscsi"

$vmhosts = Get-Cluster $ClusterName | Get-VMHost

# Create Nimble storage array iSCSI initiator group
foreach ($vmhost in $vmhosts) {
	$iscsi_adapter = Get-VMHostHba -Host $vmhost -Type iSCSI | Where {$_.Model -eq "iSCSI Software Adapter"}
	if(!$iscsi_adapter) { 
		Write-Host "ERROR: iSCSi Software Adaptor not found on host ""$($vmhost.Name)""." -foregroundcolor red
		exit
	}
	Write-Host "Adding host ""$($vmhost.Name)"" initiator ""$($iscsi_adapter.IScsiName)"" to initiator group: ""$iGroupName""." -foreground green
	New-NSInitiator -initiator_group_id $($iGroup.id) -ip_address "*" -access_protocol "iscsi" -label $($vmhost.Name) -iqn $($iscsi_adapter.IScsiName) | out-null
}

# Add iSCSI targets to VMware software iSCSI initiators and rescan host storage
foreach ($vmhost in $vmhosts) {
	$iscsi_adapter = Get-VMHostHba -Host $vmhost -Type iSCSI | Where {$_.Model -eq "iSCSI Software Adapter"}
	if(!$iscsi_adapter) { 
		Write-Host "ERROR: iSCSi Software Adaptor not found on host ""$($vmhost.Name)""." -foregroundcolor red
		exit
	}
		
	foreach ($target in $Targets) {
		Write-Host "Adding Nimble iSCSI discovery IP ""$target"" to host ""$($vmhost.Name)""." -foreground green
		New-IScsiHbaTarget -IScsiHba $iscsi_adapter -Address $target | out-null
	}
	Write-Host "Rescanning host ""$($vmhost.Name)"" storage." -foreground green
	Get-VMHostStorage -VMhost $vmhost -RescanAllHBA | out-null
}

Disconnect-VIServer -confirm:$false