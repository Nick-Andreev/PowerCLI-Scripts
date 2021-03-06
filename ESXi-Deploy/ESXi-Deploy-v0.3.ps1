#====================================================================#
#   SCRIPT:        ESXi Deploy                                       #
#   CREATED:       22/10/2015                                        #
#   MODIFIED:      19/04/2016                                        #
#   OWNER:         Nick Andreev                                      #
#                  Blog: niktips.wordpress.com                       #  
#                  Twitter: @nick_andreev_au                         #
#                  GitHub: github.com/Nick-Andreev                   #
#   VERSION:       v.0.3                                             #
#====================================================================#
#   CHANGELOG:                                                       #
#                                                                    #
#   v.0.1                                                            #
#     - Clean-up scripting                                           #
#     - Re-structure .csv files                                      #
#     - Add usage section                                            #
#                                                                    #
#   v.0.2                                                            #
#     - Add iSCSI and Update Manager functionality                   #
#     - Add Distributed vSwitch integration                          #
#     - Include add and remove actions to all network related        #
#       operations                                                   #
#                                                                    #
#   v.0.3                                                            #
#     - Add Dependent iSCSI adapter support                          #
#     - Add syslog and network dump collectors support               #
#     - Add support for vCenter alarms                               #
#     - First beta release                                           #
#                                                                    #
#   USAGE:                                                           #
#                                                                    #
#    - Provide the list of hosts in host_settings.csv                #
#    - Provide the list of vSwitches in vswitch_list.csv             #
#    - Provide the list of port groups in portgroup_list.csv         #
#    - Provide the list of VMkernel adapters in vmkernel_list.csv    #
#    - Provide the list of NIC teaming policies in                   #
#      adapter_policy.csv                                            #
#    - Provide the list of iSCSI tragers in iscsi_targets.csv        #
#    - Configure the script variables                                #
#                                                                    #
#   NOTES:                                                           #
#                                                                    #
#    - After filling out CSVs it's recommended to test the           #
#      configuration on one host first.                              #
#    - Changes to CSV files can be made on the fly without exiting   #
#      the script by using Re-read CSV option.                       #
#    - Update Manager should be fully configured before you attempt  #
#      an update.                                                    #
#    - Update Manager PowerCLI is required to apply patches using    #
#      the script.                                                   #
#    - When you upgrade ESXi hosts, Update Manager starts            #
#      downloading patches, which may take long time.                #
#    - When adding a vSwitch, one record for every vSwitch uplink is #
#      required in .csv file.                                        #
#    - vSwitch, port group and VMkernel .csv files support "Add"     #
#      action and also "Remove" action for quick cleanup in case of  #
#      an error.                                                     #
#    - Use "standard" or "distributed" type in port group, VMkernel  #
#      port and adapter policy CSV files.                            #
#    - Script doesn't support creating distributed vSwitches.        #
#    - iSCSI Type in vmkernel_list.csv can be "Software" or          #
#      "Dependent". Independent iSCSI adapters are not supported.    # 
#    - When using distributed vSwitch, script automatically          #
#      migrates vmk0 VMkernel adaptor, which is expected to be on    #
#      vSwitch0 with vmnic0 as an uplink.                            #
#    - In vSphere 6 dump collector services are stopped by default   #
#      and need to be configured to start automatically for dump     #
#      collector to work.                                            #
#    - All vCenter alarms are configured to notify via email on all  #
#      state changes: green to yellow, yellow to red, red to yellow  #
#      and yellow to green.                                          #
#                                                                    #
#   TODO:                                                            #
#                                                                    #
#    - Add safety checks in the script where possible                #  
#    - Potentially add advanced features, such as NIOC, SIOC, DRS,   #
#      SDRS                                                          #
#    - Write better documentation                                    #
#    - Output more status information on the screen throught the     #
#      script.                                                       #
#====================================================================#

#============================ Variables =============================#

$csv_rootdir = ".\"
$vcenter_ip = "10.10.10.10"
$dns_server1 = "10.10.10.11"
$dns_server2 = "10.10.10.12"
$domain_name = "acme.com"
$ntp_server = "10.10.10.13"
$um_baselines = "Critical Host Patches (Predefined)", "Non-Critical Host Patches (Predefined)"
$alarms_destination = "it@acme.com"
$vcenter_alarms = "Datastore usage on disk", "Virtual machine Consolidation Needed status",`
	"vSphere HA host status", "vSphere HA failover in progress",`
	"Insufficient vSphere HA failover resources", "Datastore cluster is out of space",`
	"Host memory usage", "VMKernel NIC not configured correctly",`
	"Network uplink redundancy degraded", "Network uplink redundancy lost",`
	"Network connectivity lost", "Host CPU usage", "Migration error",`
	"Cannot connect to storage", "Host connection failure", "Virtual machine error",`
	"Host error", "Host connection and power state"

#============================ Functions =============================#

function read_csv() {
	$global:hosts = Import-CSV $($csv_rootdir + "\host_list.csv")
	$global:vswitches = Import-CSV $($csv_rootdir +"\vswitch_list.csv")
	$global:portgroups = Import-CSV $($csv_rootdir + "\portgroup_list.csv")
	$global:vmkernels = Import-CSV $($csv_rootdir + "\vmkernel_list.csv")
	$global:policies =  Import-CSV $($csv_rootdir + "\adapter_policy.csv")
	$global:iscsitargets =  Import-CSV $($csv_rootdir + "\iscsi_targets.csv")
}

function set_iscsi_binding($ESXiHost, $iSCSIHBA, $VMKernel) {
	$ESXCli = Get-EsxCli -VMHost $ESXiHost                
	$ESXCli.iscsi.networkportal.add($iSCSIHBA.Device, $false, $VMKernel)
}

function set_syslog_settings($ESX_hostname) {
	$esxhost = Get-VMhost -Name $ESX_hostname
	$esxcli = Get-EsxCli -vmhost $esxhost
	$esxcli.system.syslog.config.set($null, $null , $null, $null, $null, $null, $null, $null, "udp://" + $vcenter_ip + ":514", $null, $null) | out-null
	$esxcli.network.firewall.ruleset.set($null, $true, "syslog") | out-null
	$esxcli.system.syslog.reload() | out-null
}

function set_networkdump_settings($ESX_hostname) {
	$esxhost = Get-VMhost -Name $ESX_hostname
	$esxcli = Get-EsxCli -vmhost $esxhost
	$esxcli.system.coredump.network.set($null, "vmk0", $null, $vcenter_ip, 6500) | out-null
	$esxcli.system.coredump.network.set($true) | out-null
}

#=========================== Main script ============================#

Connect-VIServer $vcenter_ip -username administrator@vsphere.local -password Password100# | out-null
if(!$?) { exit }
read_csv

do {
	Write-Host " "
	Write-Host "Host configuration menu:" -foregroundcolor yellow
	Write-Host " 1. Connect hosts to vCenter in maintenance mode"	
	Write-Host " 2. Configure hostnames, DNS and NTP"
	Write-Host " 3. Apply patches"
	Write-Host " "

	Write-Host "Network configuration menu:" -foregroundcolor yellow
	Write-Host " 4. Configure vSwitches"
	Write-Host " 5. Configure port groups"
	Write-Host " 6. Configure VMkernel ports"
	Write-Host " 7. Set port group adapter policies"
	Write-Host " "

	Write-Host "iSCSI configuration menu:" -foregroundcolor yellow
	Write-Host " 8. Add software iSCSI adapters"
	Write-Host " 9. Bind iSCSI VMkernel ports"
	Write-Host " 10. Add iSCSI targets"
	Write-Host " "

	Write-Host "Centralized logging and alerting:" -foregroundcolor yellow
	Write-Host " 11. Configure Syslog Collector"
	Write-Host " 12. Configure Network Dump Collector"
	Write-Host " 13. Configure vCenter alarms"
	Write-Host " "

	Write-Host "Actions menu:" -foregroundcolor yellow
	Write-Host " 14. Rescan storage"
	Write-Host " 15. Exit maintenance mode"
	Write-Host " 16. Re-read CSV"
	Write-Host " "
	Write-Host " 0. Quit"
	Write-Host " "
	$response = Read-Host "Select from menu"


switch ($response) {
1 {
	Write-Host " "
	Write-Host "-- Connect hosts to vCenter in maintenance mode" -foregroundcolor green
	foreach ($esxhost in $hosts) {
		$host_fqdn = $esxhost.Hostname + "." + $domain_name
		Add-VMHost $host_fqdn -Force -Location (Get-Cluster $esxhost.Cluster)  | out-null
		Set-VMHost -VMHost $host_fqdn -State maintenance | out-null
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
2 {
	Write-Host " "
	Write-Host "-- Configure hostnames, DNS and NTP" -foregroundcolor green
	foreach ($esxhost in $hosts) {
		$host_fqdn = $esxhost.Hostname + "." + $domain_name

		# Configure hostname and domain name
		Get-VMHostNetwork -VMHost $host_fqdn | Set-VMHostNetwork -HostName $esxhost.Hostname -DomainName $domain_name | out-null

		# Configure search domains and DNS servers
		Get-VMHostNetwork -VMHost $host_fqdn | Set-VMHostNetwork -SearchDomain $domain_name -DNSAddress $dns_server1, $dns_server2 | out-null

		# Configure NTP server
		Add-VmHostNtpServer -VMHost $host_fqdn -NtpServer $ntp_server | out-null
		# Start NTP client service and set to automatic
		Get-VmHostService -VMHost $host_fqdn | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService | out-null
		Get-VmHostService -VMHost $host_fqdn | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic" | out-null

	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
3 {
	Write-Host " "
	Write-Host "-- Apply patches" -foregroundcolor green
	foreach ($esxhost in $hosts) {
		$host_fqdn = $esxhost.Hostname + "." + $domain_name
		Scan-Inventory -Entity $host_fqdn  | out-null
		$baselines = Get-Baseline -Name $um_baselines
		Remediate-Inventory -Entity $host_fqdn -Baseline $baselines -Confirm:$false
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
4 {
	Write-Host " "
	Write-Host "-- Configure vSwitches" -foregroundcolor green
	foreach ($esxhost in $hosts) {
		foreach ($vswitch in $vswitches) {
			$host_fqdn = $esxhost.Hostname + "." + $domain_name
			
			if($vswitch.Type -eq "Standard") {
				if ($vswitch.Action -eq "Remove") {
					$vswitch_obj = Get-VirtualSwitch -VMHost $host_fqdn -Name $vswitch.Name -ErrorAction SilentlyContinue
					if($vswitch_obj) {
						Remove-VDVirtualSwitch -VirtualSwitch $vswitch_obj -Confirm:$false | out-null
					}

				}
				elseif ($vswitch.Action -eq "Add") {
					# Create vSwitch if it doesn't exist
					if(!(Get-VirtualSwitch -VMHost $host_fqdn -Name $vswitch.Name -ErrorAction SilentlyContinue)) {
						New-VirtualSwitch -VMHost $host_fqdn -Name $vswitch.Name -Mtu $vswitch.Mtu | out-null
					}
					# Set vSwitch uplinks
					$vswitch_uplink = Get-VMHostNetworkAdapter -Host $host_fqdn -Physical -Name $vswitch.Adapter
					Get-VirtualSwitch -VMHost $host_fqdn -Name $vswitch.Name | Add-VirtualSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $vswitch_uplink -Confirm:$false | out-null
				}
				else {
					Write-Host "-- Invalid action: `"$($vswitch.Action)`". Supported actions are: Add and Remove." -foregroundcolor red
				}
			}
			elseif($vswitch.Type -eq "Distributed") {
				if ($vswitch.Action -eq "Remove") {
					$vswitch_obj = Get-VDSwitch -Name $vswitch.Name -ErrorAction SilentlyContinue
					if($vswitch_obj) {
						Remove-VDSwitch -VDSwitch $vswitch_obj -Confirm:$false | out-null
					}

				}
				elseif ($vswitch.Action -eq "Add") {
					# Create vSwitch if it doesn't exist
					if(!(Get-VDSwitch -Name $vswitch.Name -ErrorAction SilentlyContinue)) {
						New-VDSwitch -Name $vswitch.Name -Mtu $vswitch.Mtu | out-null
					}
					
					# Add the host to the vSwitch if it's not already added
					$vswitch_obj = Get-VDSwitch -Name $vswitch.Name
					if(!(Get-VDSwitch -Name $vswitch.Name -VMHost $host_fqdn -ErrorAction SilentlyContinue)) {
						Add-VDSwitchVMHost -VMHost $host_fqdn -VDSwitch $vswitch_obj
					}

					# Create the "Management Network" port group to migrate vmk0 to if it doesn't already exist
					if(!(Get-VDPortgroup -name "Management Network" -VDSwitch $vswitch_obj -ErrorAction SilentlyContinue)) {
						$mgt_pg = Get-VirtualSwitch -VMHost $host_fqdn -Name "vSwitch0" | Get-VirtualPortGroup -Name "Management Network"
						Get-VDSwitch -Name $vswitch.Name | New-VDPortgroup -Name "Management Network" -VLANID $mgt_pg.Vlanid | out-null
					}
					
					# Move vmnics to distributed vSwitch. Move vmnic0 together with vmk0
					if($vswitch.adapter -eq "vmnic0") {
						$mgt_pg = Get-VDPortgroup -name "Management Network" -VDSwitch $vswitch_obj
						$vswitch_uplink = Get-VMHostNetworkAdapter -Host $host_fqdn -Physical -Name $vswitch.Adapter
						$vmk_adapter = Get-VMHostNetworkAdapter -VMhost $host_fqdn -Name "vmk0"
						Get-VDSwitch -Name $vswitch.Name | Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $vswitch_uplink -VMHostVirtualNic $vmk_adapter -VirtualNicPortgroup $mgt_pg -Confirm:$false | out-null
					}
					else {
						$vswitch_uplink = Get-VMHostNetworkAdapter -Host $host_fqdn -Physical -Name $vswitch.Adapter
						Get-VDSwitch -Name $vswitch.Name | Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $vswitch_uplink -Confirm:$false | out-null
					}
			}
				else {
					Write-Host "-- Invalid action: `"$($vswitch.Action)`". Supported actions are: Add and Remove." -foregroundcolor red
				}
			}
			else {
				Write-Host "-- Invalid virtual switch type: `"$($vswitch.Type)`". Supported types are: Standard and Distributed." -foregroundcolor red
			}
		}
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
5 {
	Write-Host " "
	Write-Host "-- Configure port groups" -foregroundcolor green
	foreach ($pg in $portgroups) {
		if($pg.Type -eq "Distributed") {
			$vswitch_obj = Get-VDSwitch -Name $pg.vSwitch_Name
			$pg_obj = Get-VDPortgroup -name $pg.Portgroup -VDSwitch $vswitch_obj -ErrorAction SilentlyContinue
			if ($pg.Action -eq "Remove") {
				if(!$pg_obj) {
					Write-Host "-- Port group doesn't exist: `"$($pg.Portgroup)`"" -foregroundcolor red
				}
				else {
					Remove-VDPortgroup -VDPortGroup $pg_obj -Confirm:$false | out-null
				}
			}
			elseif ($pg.Action -eq "Add") {
				if($pg_obj) {
					Write-Host "-- Port group already exists: `"$($pg.Portgroup)`"" -foregroundcolor red
				}
				else {
					New-VDPortgroup -VDSwitch $vswitch_obj -Name $pg.Portgroup -VlanId $pg.Vlanid | out-null
				}
			}
			else {
				Write-Host "-- Invalid action: `"$($pg.Action)`". Supported actions are: Add and Remove." -foregroundcolor red			
			}
		}
		elseif($pg.Type -eq "Standard") {
			foreach ($esxhost in $hosts) {
				$host_fqdn = $esxhost.Hostname + "." + $domain_name

				if ($pg.Action -eq "Remove") {
					Get-virtualportgroup -VMhost $host_fqdn -name $pg.Portgroup | Remove-VirtualPortGroup -Confirm:$false | out-null
				}
				elseif ($pg.Action -eq "Add") {
					Get-VirtualSwitch -VMHost $host_fqdn -Name $pg.vSwitch_name | New-VirtualPortGroup -Name $pg.Portgroup -VLANID $pg.Vlanid | out-null
				}
				else {
					Write-Host "-- Invalid action: `"$($pg.Action)`". Supported actions are: Add and Remove." -foregroundcolor red			
				}
			}
		}
		else {
			Write-Host "-- Invalid port group type: `"$($pg.Type)`". Supported types are: Standard and Distributed." -foregroundcolor red
		}
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
6 {
	Write-Host " "
	Write-Host "-- Configure VMkernel ports" -foregroundcolor green
	foreach ($vmk in $vmkernels) {
		# Creating a distributed VMkernel port requires an existing port group
		if ($vmk.Action -eq "Add" -And $vmk.Type -eq "distributed") {
			$pg_obj = Get-VDSwitch -Name $vmk.vSwitch | Get-VDPortgroup -Name $vmk.Name
			if(!$pg_obj) {
				Get-VDSwitch -Name $vmk.vSwitch | New-VDPortgroup -Name $vmk.Name | out-null
				Get-VDPortgroup -name $vmk.Name | Set-VDVlanConfiguration -VlanId $vmk.Vlan_id | out-null
			}
		}
		
		$host_fqdn = $vmk.Host + "." + $domain_name
			
		if ($vmk.Action -eq "Remove") {
			Get-VMHostNetworkAdapter -VMhost $host_fqdn | where {$_.PortgroupName -eq $($vmk.Name)} | Remove-VMHostNetworkAdapter -Confirm:$false | out-null
			if($vmk.Type -eq "standard") {
				Get-virtualportgroup -VMhost $host_fqdn -name $vmk.Name | Remove-virtualportgroup -Confirm:$false | out-null
			}
			elseif($vmk.Type -eq "distributed") {
				Get-VDPortgroup -name $vmk.Name | Remove-VDPortgroup -Confirm:$false | out-null
			}
			else {
				Write-Host "-- Invalid VMkernel port type: `"$($pg.Type)`". Supported types are: Standard and Distributed." -foregroundcolor red
			}
		}
		elseif ($vmk.Action -eq "Add") {
			# Create VMkernel adapter and port group
			New-VMHostNetworkAdapter -VMHost $host_fqdn -PortGroup $vmk.Name -VirtualSwitch $vmk.vSwitch -IP $vmk.IP -SubnetMask $vmk.Subnet_Mask -Mtu $vmk.Mtu| out-null
			if($vmk.Type -eq "standard") {
				Get-virtualportgroup -VMhost $host_fqdn -name $vmk.Name | Set-virtualportgroup -VLanId $vmk.Vlan_Id | out-null
			}
			elseif($vmk.Type -eq "distributed") {
				Get-VDPortgroup -name $vmk.Name | Set-VDPortgroup -VLanId $vmk.Vlan_Id | out-null
			}
			else {
				Write-Host "-- Invalid VMkernel port type: `"$($pg.Type)`". Supported types are: Standard and Distributed." -foregroundcolor red
			}
				
			# Enable VMotion if required
			if($vmk.vMotion -eq "enabled") {
				Get-VMHostNetworkAdapter -VMhost $host_fqdn | where {$_.PortgroupName -eq $($vmk.Name)} | Set-VMHostNetworkAdapter -vMotionEnabled:$true -Confirm:$false | out-null
			}
			elseif($vmk.vMotion -eq "disabled") {
				# do nothing
			}
			else {
				Write-Host "-- Invalid vMotion option: `"$($vmk.vMotion)`". Supported options are: Enabled and Disabled." -foregroundcolor red				
			}
		}
		else {
			Write-Host "-- Invalid action: `"$($pg.Action)`". Supported actions are: Add and Remove." -foregroundcolor red			
		}
	
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
7 {
	Write-Host " "
	Write-Host "-- Set port group adapter policies" -foregroundcolor green
	foreach ($policy in $policies) {
		if($policy.Type -eq "distributed") {
			if($policy.Policy -eq "active") {
				Get-VDPortgroup -name $policy.Portgroup | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort $($policy.Adapter) | out-null
			}
			elseif($policy.Policy -eq "standby") {
				Get-VDPortgroup -name $policy.Portgroup | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -StandbyUplinkPort $($policy.Adapter) | out-null
			}
			elseif($policy.Policy -eq "unused") {
				Get-VDPortgroup -name $policy.Portgroup | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -UnusedUplinkPort $($policy.Adapter) | out-null
			}
			else {		
				Write-Host "-- Invalid NIC teaming policy: `"$($policy.Policy)`". Supported policies are: Active, Standby, Unused." -foregroundcolor red
			}
		}
		elseif($policy.Type -eq "standard") {
			foreach ($esxhost in $hosts) {
				$host_fqdn = $esxhost.Hostname + "." + $domain_name

				if($policy.Policy -eq "active") {
					Get-virtualportgroup -VMhost $host_fqdn -name $policy.Portgroup | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive $($policy.Adapter) | out-null
				}
				elseif($policy.Policy -eq "standby") {
					Get-virtualportgroup -VMhost $host_fqdn -name $policy.Portgroup | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicStandby $($policy.Adapter) | out-null
				}
				elseif($policy.Policy -eq "unused") {
					Get-virtualportgroup -VMhost $host_fqdn -name $policy.Portgroup | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicUnused $($policy.Adapter) | out-null
				}
				else {		
					Write-Host "-- Invalid NIC teaming policy: `"$($policy.Policy)`". Supported policies are: Active, Standby, Unused." -foregroundcolor red
				}
			}
		}
		else {
			Write-Host "-- Invalid policy type: `"$($policy.Type)`". Supported types are: Standard and Distributed." -foregroundcolor red
		}
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
8 {
	Write-Host " "
	Write-Host "-- Add software iSCSI adapters" -foregroundcolor green
	foreach ($esxhost in $hosts) {
		$host_fqdn = $esxhost.Hostname + "." + $domain_name

		Get-VMHostStorage -VMHost $host_fqdn | Set-VMHostStorage -SoftwareIScsiEnabled $true | out-null
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
9 {
	Write-Host " "
	Write-Host "-- Bind iSCSI VMkernel ports" -foregroundcolor green

	foreach ($vmk in $vmkernels) {
		$host_fqdn = $vmk.Host + "." + $domain_name
		if($vmk.iSCSI -eq "enabled") {
			if($vmk.iSCSI_Type -eq "Software") {
				$iscsi_adapter = Get-VMHostHba -Host $host_fqdn -Type iScsi | Where {$_.Model -eq "iSCSI Software Adapter"}
			}
			elseif($vmk.iSCSI_Type -eq "Dependent") {
				$iscsi_adapter = Get-VMHostHba -Host $host_fqdn -Type iScsi -Device $vmk.Adapter_Name					
			}
			else {
				Write-Host "-- Invalid iSCSI adapter type: `"$($vmk.iSCSI)`". Supported adapter types are: Software and Dependent." -foregroundcolor red
			}
			$vmkernel_adapter = Get-VMHostNetworkAdapter -VMhost $host_fqdn | where {$_.PortgroupName -eq $($vmk.Name)}
			set_iscsi_binding $host_fqdn $iscsi_adapter $vmkernel_adapter
		}
		elseif($vmk.iSCSI -eq "disabled") {
			# do nothing
		}
		else {
			Write-Host "-- Invalid iSCSI option: `"$($vmk.iSCSI)`". Supported options are: Enabled and Disabled." -foregroundcolor red
		}
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
10 {
	Write-Host " "
	Write-Host "-- Add iSCSI targets" -foregroundcolor green
	foreach ($esxhost in $hosts) {
		$host_fqdn = $esxhost.Hostname + "." + $domain_name
		foreach ($target in $iscsitargets) {
			$iscsi_adapter = Get-VMHostHba -Host $host_fqdn -Type iScsi -Device $target.iscsi_adapter
			New-IScsiHbaTarget -IScsiHba $iscsi_adapter -Address $target.target_ip | out-null

		}
		Get-VMHostStorage -VMHost $host_fqdn -RescanAllHBA | out-null
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
11 {
	Write-Host " "
	Write-Host "-- Configure Syslog Collector" -foregroundcolor green
	foreach ($esxhost in $hosts) {
		$host_fqdn = $esxhost.Hostname + "." + $domain_name
		set_syslog_settings $host_fqdn
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
12 {
	Write-Host " "
	Write-Host "-- Configure Network Dump Collector" -foregroundcolor green
	foreach ($esxhost in $hosts) {
		$host_fqdn = $esxhost.Hostname + "." + $domain_name
		set_networkdump_settings $host_fqdn
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
13 {
	Write-Host " "
	Write-Host "-- Configure vCenter alarms" -foregroundcolor green
	foreach ($alarm in $vcenter_alarms) {
		# Clean-up alarm actions if they already exist
		Get-AlarmDefinition -Name "$alarm" | Get-AlarmAction -ActionType SendEmail | where {$_.to -eq $alarms_destination} | Remove-AlarmAction -Confirm:$false | out-null
		
		# Create alarm action
		$action_obj = Get-AlarmDefinition -Name "$alarm" | New-AlarmAction -Email -To "$alarms_destination"
	
		# Enable action for all state changes: Green to Yellow, Yellow to Red, Red to Yellow and Yellow to Green.
		New-AlarmActionTrigger -AlarmAction $action_obj -StartStatus "Green" -EndStatus "Yellow" | out-null
		# The Yellow to Red notification is enabled by default
		New-AlarmActionTrigger -AlarmAction $action_obj -StartStatus "Red" -EndStatus "Yellow" | out-null
		New-AlarmActionTrigger -AlarmAction $action_obj -StartStatus "Yellow" -EndStatus "Green" | out-null
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
14 {
	Write-Host " "
	Write-Host "-- Rescan storage" -foregroundcolor green
	foreach ($esxhost in $hosts) {
		$host_fqdn = $esxhost.Hostname + "." + $domain_name
		Get-VMHostStorage -VMHost $host_fqdn -RescanAllHBA | out-null
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}

15 {
	Write-Host " "
	Write-Host "-- Exit maintenance mode" -foregroundcolor green
	foreach ($esxhost in $hosts) {
		$host_fqdn = $esxhost.Hostname + "." + $domain_name
		Set-VMHost -VMHost $host_fqdn -State Connected | out-null
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
16 {
	Write-Host " "
	Write-Host "-- Re-read CSV" -foregroundcolor green
	read_csv
	Write-Host "-- Operation complete" -foregroundcolor green
}
}
} while ($response -ne "0")

Disconnect-VIServer -Confirm:$false
