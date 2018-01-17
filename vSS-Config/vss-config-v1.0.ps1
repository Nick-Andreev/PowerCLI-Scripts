<#

.SYNOPSIS
When using virtual standard switches, switch configuration changes have to
be manually applied to every host in a vSphere cluster. This script helps
to automate this process by replicating the configuration across all hosts.

.DESCRIPTION
Script directly connects to each ESXi host in the cluster, therefore a
list of ESXi hostnames or IP addresses is required, as well as the root
password.

Pick a selection from the list of available actions and script will request
all required information in interactive mode.

If you have made a mistake, script provides remove and disconnect options 
to revert the changes. You will be provided with an option to choose which
objects to remove or disconnect.

The following operations are supported:
- Add/remove a virtual switch
- Connect/disconnect virtual switch uplinks
- Add/remove a VMkernel port
- Add/remove a port group
- Set/show NIC teaming policy
- Add/remove software iSCSI adapters
- Bind iSCSI VMkernel adapters
- Add/remove iSCSI targets
- Rescan storage

.PARAMETER EsxHostnames
Comma-separated list of ESXi hostnames or IP addresses. List has to be
enclosed in double quotes. Avoid using spaces after commas.

.PARAMETER RootPassword
Root password for ESXi hosts

.EXAMPLE
.\vss-config-v1.0.ps1 -EsxHostnames "10.0.0.1,10.0.0.2,10.0.0.3" -RootPassword P@$$w0rd

.NOTES
VMware PowerCLI is required for script to run
   
.LINK
https://niktips.wordpress.com

#>

Param(
	[Parameter(Mandatory = $true)][string]$EsxHostnames,
	[Parameter(Mandatory = $true)][string]$RootPassword
)

#Connect-ViServer $VIServerName | out-null
#if(!$?) { exit }

# Put ESXi server hostnames or IPs in an array
$esx_hostnames = $EsxHostnames.split(",")
$esxi_hosts = @()
foreach($esx_hostname in $esx_hostnames) {
	Write-Host "Connecting to ESXi server ""$esx_hostname"".." -foreground green
	Connect-ViServer $esx_hostname -User root -Password $RootPassword | out-null
	if(!$?) { exit }
    $vmhost = Get-VMHost -Name $esx_hostname
    $esxi_hosts += $vmhost
}

do {
	Write-Host ""
	Write-Host "Virtual switch configuration:" -foreground yellow
	Write-Host " 1. Add a Standard vSwitch"
	Write-Host " 2. Remove a Standard vSwitch"
	Write-Host " 3. Connect Uplinks"
	Write-Host " 4. Disconnect Uplinks"
	Write-Host " "
	Write-Host "VMkernel port configuration:" -foreground yellow
	Write-Host " 5. Add a VMkernel Port"
	Write-Host " 6. Remove a VMkernel Port"
	Write-Host " "
	Write-Host "Port group configuration:" -foreground yellow
	Write-Host " 7. Add a Port Group"
	Write-Host " 8. Remove a Port Group"
	Write-Host " 9. Set NIC Teaming Policy"
	Write-Host " 10. Show NIC Teaming Policy"
	Write-Host " "
	Write-Host "iSCSI configuration:" -foreground yellow
	Write-Host " 11. Add Software iSCSI Adapters"
	Write-Host " 12. Bind iSCSI VMkernel Adapters"
	Write-Host " 13. Add iSCSI Targets"
	Write-Host " 14. Remove iSCSI Targets"
	Write-Host " 15. Rescan Storage"
	Write-Host " "
	Write-Host " 0. Quit"
	Write-Host " "
	$response = Read-Host "Select from menu"


switch ($response) {
1 {


	Write-Host " "
	$vss_name = Read-Host "vSwitch Name"
	$vss_uplinks = Read-Host "vSwitch uplinks"
	$vss_uplinks = $vss_uplinks.split(',')
	
	foreach($esx_host in $esxi_hosts) {
		# Create vSwitch if it doesn't exist
		if(Get-VirtualSwitch -VMHost $esx_host -Name $vss_name -ErrorAction SilentlyContinue) {
			Write-Host "vSwitch ""$vss_name"" already exists on server ""$esx_host""" -foregroundcolor red		
		}
		else {
			Write-Host "Creating vSwitch ""$vss_name"" on server ""$esx_host"".." -foregroundcolor green
			New-VirtualSwitch -VMHost $esx_host -Name $vss_name | out-null
			
			# Set vSwitch uplinks
			foreach($vss_uplink in $vss_uplinks) {
				$existing_vswitch = Get-VirtualSwitch -VMHost $esx_host | Where-object {$_.nic -eq $vss_uplink}
				if($existing_vswitch) {				
					Write-Host "Uplink ""$vss_uplink"" is already connected to vSwitch ""$($existing_vswitch.Name)"" on server ""$esx_host"".." -foregroundcolor red
				}
				else {
					Write-Host "Connecting uplink ""$vss_uplink"" to vSwitch ""$vss_name"" on server ""$esx_host"".." -foregroundcolor green
					$host_adapter = Get-VMHostNetworkAdapter -Host $esx_host -Physical -Name $vss_uplink
					Get-VirtualSwitch -VMHost $esx_host -Name $vss_name | Add-VirtualSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $host_adapter -Confirm:$false | out-null
				}
			}
		}
	}
}
2 {
	Write-Host " "
	$vss_name = Read-Host "vSwitch Name"

	foreach($esx_host in $esxi_hosts) {
		# Check if vSwitch exists
		$vswitch_obj = Get-VirtualSwitch -VMHost $esx_host -Name $vss_name -ErrorAction SilentlyContinue
		if(!$vswitch_obj) {
			Write-Host "vSwitch ""$vss_name"" doesn't exist on server ""$esx_host""" -foregroundcolor red		
		}
		else {
			Write-Host "Removing vSwitch ""$vss_name"" from server ""$esx_host""" -foregroundcolor green	
			Remove-VirtualSwitch -VirtualSwitch $vswitch_obj -Confirm:$false | out-null		
		}
	}
}
3 {
	Write-Host " "
	$vss_name = Read-Host "vSwitch Name"
	$vss_uplinks = Read-Host "vSwitch uplinks"
	$vss_uplinks = $vss_uplinks.split(',')

	foreach($esx_host in $esxi_hosts) {	
		if(!(Get-VirtualSwitch -VMHost $esx_host -Name $vss_name -ErrorAction SilentlyContinue)) {
			Write-Host "vSwitch ""$vss_name"" doesn't exist on server ""$esx_host""" -foregroundcolor red		
		}
		else {
			# Add vSwitch uplinks
			foreach($vss_uplink in $vss_uplinks) {
				$existing_vswitch = Get-VirtualSwitch -VMHost $esx_host | Where-object {$_.nic -eq $vss_uplink}
				if($existing_vswitch) {				
					Write-Host "Uplink ""$vss_uplink"" is already connected to vSwitch ""$($existing_vswitch.Name)"" on server ""$esx_host"".." -foregroundcolor red
				}
				else {
					Write-Host "Connecting uplink ""$vss_uplink"" to vSwitch ""$vss_name"" on server ""$esx_host"".." -foregroundcolor green
					$host_adapter = Get-VMHostNetworkAdapter -Host $esx_host -Physical -Name $vss_uplink
					Get-VirtualSwitch -VMHost $esx_host -Name $vss_name | Add-VirtualSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $host_adapter -Confirm:$false | out-null
				}
			}
		}
	}	
}
4 {
	Write-Host " "
	$vss_uplinks = Read-Host "vSwitch uplinks"
	$vss_uplinks = $vss_uplinks.split(',')

	foreach($esx_host in $esxi_hosts) {	
		# Remove vSwitch uplinks
		foreach($vss_uplink in $vss_uplinks) {
			$existing_vswitch = Get-VirtualSwitch -VMHost $esx_host | Where-object {$_.nic -eq $vss_uplink}
			if(!$existing_vswitch) {				
				Write-Host "Uplink ""$vss_uplink"" is not connected on server ""$esx_host"".." -foregroundcolor red
			}
			else {
				Write-Host "Disconnecting uplink ""$vss_uplink"" on server ""$esx_host"".." -foregroundcolor green
				$host_adapter = Get-VMHostNetworkAdapter -Host $esx_host -Physical -Name $vss_uplink
				Remove-VirtualSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $host_adapter -Confirm:$false | out-null
			}
		}
	}
}
5 {
	Write-Host " "
	$vmk_name = Read-Host "VMkernel Name"
	$vmk_ips = @{}
	foreach($esx_host in $esxi_hosts) {
		$vmk_ip = Read-Host "VMkernel IP Address for $esx_host"
		$vmk_ips.Add($esx_host, $vmk_ip)
	}
	$vmk_mask = Read-Host "VMkernel Subnet Mask"
	$vmk_vlan = Read-Host "VMkernel VLAN ID (0 for no VLAN)"
	do {
		$vmk_vmotion = Read-Host "Enable vMotion [y/n]"
	} 
	until ('y','Y','n','N' -contains $vmk_vmotion)
	$vss_name = Read-Host "vSwitch Name"

	foreach($esx_host in $esxi_hosts) {
		$vmk_adapter = Get-VMHostNetworkAdapter -VMhost $esx_host | where {$_.PortgroupName -eq $vmk_name}
		if($vmk_adapter) {
			Write-Host "VMkernel adapter ""$vmk_name"" already exists on server ""$esx_host"".." -foreground red
		}
		else {
			# Create VMkernel adapter and port group
			Write-Host "Creating VMkernel adapter ""$vmk_name"" on server ""$esx_host"" with the following settings:" -foregroundcolor green		
			Write-Host "	vSwitch: ""$vss_name""" -foregroundcolor yellow
			Write-Host "	IP Address: ""$($vmk_ips.Get_Item($esx_host))""" -foregroundcolor yellow
			Write-Host "	Subnet Mask: ""$vmk_mask""" -foregroundcolor yellow
			Write-Host "	VLAN ID: ""$vmk_vlan""" -foregroundcolor yellow
			Write-Host "	Enable vMotion: ""$vmk_vmotion""" -foregroundcolor yellow

			New-VMHostNetworkAdapter -VMHost $esx_host -PortGroup $vmk_name -VirtualSwitch $vss_name -IP $vmk_ips.Get_Item($esx_host) -SubnetMask $vmk_mask | out-null
			Get-virtualportgroup -VMhost $esx_host -name $vmk_name | Set-virtualportgroup -VLanId $vmk_vlan | out-null
					
			# Enable VMotion if required
			if('y','Y' -contains $vmk_vmotion) {
				Get-VMHostNetworkAdapter -VMhost $esx_host | where {$_.PortgroupName -eq $vmk_name} | Set-VMHostNetworkAdapter -vMotionEnabled:$true -Confirm:$false | out-null
			}
		}
	}
}
6 {
	Write-Host " "
	$vmk_name = Read-Host "VMkernel Name"

	foreach($esx_host in $esxi_hosts) {
		$vmk_adapter = Get-VMHostNetworkAdapter -VMhost $esx_host | where {$_.PortgroupName -eq $vmk_name}
		if(!$vmk_adapter) {
			Write-Host "VMkernel adapter ""$vmk_name"" doesn't exist on server ""$esx_host"".." -foreground red
		}
		else {
			Write-Host "Removing VMkernel adapter ""$vmk_name"" from server ""$esx_host"".." -foreground green	
			$vmk_adapter | Remove-VMHostNetworkAdapter -Confirm:$false | out-null
			Get-virtualportgroup -VMhost $esx_host -name $vmk_name | Remove-virtualportgroup -Confirm:$false | out-null
		}
	}
}
7 {
	Write-Host " "
	$pg_name = Read-Host "Port Group Name"
	$vss_name = Read-Host "vSwitch Name"
	$vmk_vlan = Read-Host "VMkernel VLAN ID (0 for no VLAN)"

	foreach($esx_host in $esxi_hosts) {
		$pg_obj = Get-virtualportgroup -VMhost $esx_host -name $pg_name -ErrorAction SilentlyContinue
		if($pg_obj) {
			Write-Host "Port group ""$pg_name"" already exists on server ""$esx_host"".." -foreground red		
		}
		else {
			Write-Host "Creating port group ""$pg_name"" on vSwitch ""$vss_name"" on server ""$esx_host"".." -foreground green	
			Get-VirtualSwitch -VMHost $esx_host -Name $vss_name | New-VirtualPortGroup -Name $pg_name -VLANID $vmk_vlan | out-null
		}
	}
}
8 {
	Write-Host " "
	$pg_name = Read-Host "Port Group Name"

	foreach($esx_host in $esxi_hosts) {
		$pg_obj = Get-virtualportgroup -VMhost $esx_host -name $pg_name -ErrorAction SilentlyContinue
		if(!$pg_obj) {
			Write-Host "Port group ""$pg_name"" doesn't exist on server ""$esx_host"".." -foreground red
		}
		else {
			Write-Host "Removing port group ""$pg_name"" from server ""$esx_host"".." -foreground green	
			Get-virtualportgroup -VMhost $esx_host -name $pg_name | Remove-VirtualPortGroup -Confirm:$false | out-null
		}
	}
}
9 {
	Write-Host " "
	$pg_name = Read-Host "Port Group Name"
	$adpt_active = Read-Host "Active Adapters"
	$adpt_active = $adpt_active.split(',')
	$adpt_standby  = Read-Host "Standby Adapters"
	$adpt_standby = $adpt_standby.split(',')
	$adpt_unused = Read-Host "Unused Adapters"
	$adpt_unused = $adpt_unused.split(',')

	foreach($esx_host in $esxi_hosts) {
		$pg_obj = Get-virtualportgroup -VMhost $esx_host -name $pg_name -ErrorAction SilentlyContinue
		if(!$pg_obj) {
			Write-Host "Port group ""$pg_name"" doesn't exist on server ""$esx_host"".." -foreground red
		}
		else {
			foreach($adpt in $adpt_active) {
				if(!$adpt) { continue }
				$nic_teaming = Get-virtualportgroup -VMhost $esx_host -name $pg_name | Get-NicTeamingPolicy
				if($nic_teaming.ActiveNic -notcontains $adpt -And $nic_teaming.StandbyNic -notcontains $adpt -And $nic_teaming.UnusedNic -notcontains $adpt) {
					Write-Host "Physical adapter ""$adpt"" isn't connected to port group ""$pg_name"" on server ""$esx_host"".." -foreground red
				}
				else {
					Write-Host "Setting adapter ""$adpt"" as active for port group ""$pg_name"" on server ""$esx_host"".." -foreground green	
					Get-virtualportgroup -VMhost $esx_host -name $pg_name | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive $adpt | out-null
				}
			}
			foreach($adpt in $adpt_standby) {
				if(!$adpt) { continue }
				$nic_teaming = Get-virtualportgroup -VMhost $esx_host -name $pg_name | Get-NicTeamingPolicy
				if($nic_teaming.ActiveNic -notcontains $adpt -And $nic_teaming.StandbyNic -notcontains $adpt -And $nic_teaming.UnusedNic -notcontains $adpt) {
					Write-Host "Physical adapter ""$adpt"" isn't connected to port group ""$pg_name"" on server ""$esx_host"".." -foreground red
				}
				else {
					Write-Host "Setting adapter ""$adpt"" as standby for port group ""$pg_name"" on server ""$esx_host"".." -foreground green	
					Get-virtualportgroup -VMhost $esx_host -name $pg_name | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicStandby $adpt | out-null
				}
			}
			foreach($adpt in $adpt_unused) {
				if(!$adpt) { continue }
				$nic_teaming = Get-virtualportgroup -VMhost $esx_host -name $pg_name | Get-NicTeamingPolicy
				if($nic_teaming.ActiveNic -notcontains $adpt -And $nic_teaming.StandbyNic -notcontains $adpt -And $nic_teaming.UnusedNic -notcontains $adpt) {
					Write-Host "Physical adapter ""$adpt"" isn't connected to port group ""$pg_name"" on server ""$esx_host"".." -foreground red
				}
				else {
					Write-Host "Setting adapter ""$adpt"" as unused for port group ""$pg_name"" on server ""$esx_host"".." -foreground green	
					Get-virtualportgroup -VMhost $esx_host -name $pg_name | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicUnused $adpt | out-null
				}
			}
		}
	}
}
10 {
	Write-Host " "
	$pg_name = Read-Host "Port Group Name"

	foreach($esx_host in $esxi_hosts) {
		$pg_obj = Get-virtualportgroup -VMhost $esx_host -name $pg_name -ErrorAction SilentlyContinue
		if(!$pg_obj) {
			Write-Host "Port group ""$pg_name"" doesn't exist on server ""$esx_host"".." -foreground red
		}
		else {		
			$nic_teaming = Get-virtualportgroup -VMhost $esx_host -name $pg_name | Get-NicTeamingPolicy
			Write-Host "NIC teaming policy for port group ""$pg_name"" on server ""$esx_host"":" -foreground green
			Write-Host "	Active NICs: " -NoNewline -foreground yellow
			foreach($adpt in $nic_teaming.ActiveNic) {
				Write-Host "$adpt " -NoNewline -foreground yellow
			}
			Write-Host " "
			Write-Host "	Standby NICs: " -NoNewline -foreground yellow
			foreach($adpt in $nic_teaming.StandbyNic) {
			Write-Host "$adpt " -NoNewline -foreground yellow
			}
			Write-Host " "
			Write-Host "	Unused NICs: " -NoNewline -foreground yellow
			foreach($adpt in $nic_teaming.UnusedNic) {
			Write-Host "$adpt " -NoNewline -foreground yellow
			}
			Write-Host " "
		}
	}	
}
11 {
	Write-Host " "
	foreach($esx_host in $esxi_hosts) {
		$iscsi_storage = Get-VMHostStorage -VMHost $esx_host
		if($iscsi_storage.SoftwareIscsiEnabled) {
			Write-Host "Software iSCSI initiator already enabled on server ""$esx_host"".." -foreground red			
		}
		else {
			Write-Host "Enabling software iSCSI initiator on server ""$esx_host"".." -foregroundcolor green
			$iscsi_storage | Set-VMHostStorage -SoftwareIScsiEnabled $true | out-null
		}
	}
}
12 {
	Write-Host " "
	$vmk_names = Read-Host "VMkernel Adapters"
	$vmk_names = $vmk_names.split(',')

	foreach($esx_host in $esxi_hosts) {
		$iscsi_storage = Get-VMHostStorage -VMHost $esx_host
		if(!$iscsi_storage.SoftwareIscsiEnabled) {
			Write-Host "Software iSCSI initiator is disabled on server ""$esx_host"".." -foreground red			
		}
		else {
			$ESXCli = Get-EsxCli -VMHost $esx_host
			$bound_vmks = $ESXCli.iscsi.networkportal.list($iscsi_adapter.Device)
			$iscsi_adapter = Get-VMHostHba -Host $esx_host -Type iScsi | Where {$_.Model -eq "iSCSI Software Adapter"}	
			foreach($vmk in $vmk_names) {
				if($bound_vmks.PortGroup -contains $vmk) {
					Write-Host "VMkernel adapter ""$vmk"" is already bound to software iSCSI initiator on server ""$esx_host"".." -foreground red			
				}
				else {
					$vmk_adapter = Get-VMHostNetworkAdapter -VMhost $esx_host | where {$_.PortgroupName -eq $vmk}
					if(!$vmk_adapter) {
						Write-Host "VMkernel adapter ""$vmk"" doesn't exist on server ""$esx_host"".." -foreground red
					}
					else {
						Write-Host "Binding VMkernel adapter ""$vmk"" to software iSCSI initiator on host ""$esx_host"".." -foregroundcolor green
						$vmkernel_adapter = Get-VMHostNetworkAdapter -VMhost $esx_host | where {$_.PortgroupName -eq $vmk}
          					$ESXCli.iscsi.networkportal.add($iscsi_adapter.Device, $false, $vmkernel_adapter) | out-null
					}
				}				
			}
		}
	}
}
13 {
	Write-Host " "
	$iscsi_targets = Read-Host "iSCSI Target IPs"
	$iscsi_targets = $iscsi_targets.split(',')

	foreach($esx_host in $esxi_hosts) {
		$iscsi_storage = Get-VMHostStorage -VMHost $esx_host
		if(!$iscsi_storage.SoftwareIscsiEnabled) {
			Write-Host "Software iSCSI initiator is disabled on server ""$esx_host"".." -foreground red			
		}
		else {
			$iscsi_adapter = Get-VMHostHba -Host $esx_host -Type iScsi | Where {$_.Model -eq "iSCSI Software Adapter"}	
			foreach($target in $iscsi_targets) {
				$existing_target = Get-IScsiHbaTarget -IScsiHba $iscsi_adapter | Where {$_.Address -eq $target}	
				if($existing_target) {
					Write-Host "iSCSI target ""$target"" is already in the list of software iSCSI initiator targets on server ""$esx_host"".." -foreground red			
				}
				else {
					Write-Host "Adding iSCSI target ""$target"" to the list of software iSCSI initiator targets on host ""$esx_host"".." -foregroundcolor green
					New-IScsiHbaTarget -IScsiHba $iscsi_adapter -Address $target | out-null
				}
			}
		}
	}
}
14 {
	Write-Host " "
	$iscsi_targets = Read-Host "iSCSI Target IPs"
	$iscsi_targets = $iscsi_targets.split(',')

	foreach($esx_host in $esxi_hosts) {
		$iscsi_storage = Get-VMHostStorage -VMHost $esx_host
		if(!$iscsi_storage.SoftwareIscsiEnabled) {
			Write-Host "Software iSCSI initiator is disabled on server ""$esx_host"".." -foreground red			
		}
		else {
			$iscsi_adapter = Get-VMHostHba -Host $esx_host -Type iScsi | Where {$_.Model -eq "iSCSI Software Adapter"}	
			foreach($target in $iscsi_targets) {
				$existing_target = Get-IScsiHbaTarget -IScsiHba $iscsi_adapter | Where {$_.Address -eq $target}	
				if(!$existing_target) {
					Write-Host "iSCSI target ""$target"" is not in the list of software iSCSI initiator targets on server ""$esx_host"".." -foreground red			
				}
				else {
					Write-Host "Removing iSCSI target ""$target"" from the list of software iSCSI initiator targets on host ""$esx_host"".." -foregroundcolor green
					Remove-IScsiHbaTarget -Target $existing_target -Confirm:$false | out-null
				}
			}
		}
	}
}
15 {
	Write-Host " "
	foreach($esx_host in $esxi_hosts) {
		Write-Host "Rescanning storage on host ""$esx_host"".." -foregroundcolor green
		Get-VMHostStorage -VMHost $host_fqdn -RescanAllHBA | out-null
	}
}
}
} while ($response -ne "0")

foreach($esx_hostname in $esx_hostnames) {
	Disconnect-VIServer $esx_hostname -Confirm:$false	
}
