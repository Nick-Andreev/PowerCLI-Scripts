<#

.SYNOPSIS
If you ever had to build a new vCenter when upgrading between vSphere 
versions, you know that recreating the same alert actions on the new 
vCenter is a very time-consuming task.

This script helps to automate it, by copying vCenter email actions from 
source to destination vCenter, preserving the same destination email 
addresses and action triggers.

.DESCRIPTION
Script copies email actions only. Actions of other types (such as SNMP
traps) and alert triggers are not supported and have to be copied manually.

Script also expects alert definitions from the source vCenter to exist 
on the destination vCenter, otherwise email action will not be copied
across.

.PARAMETER SourceVcenter
VMware vCenter that alerts will be copied from

.PARAMETER DestinationVcenter
VMware vCenter that alerts will be copied to

.EXAMPLE
.\copy-vcenter-alerts-v1.0.ps1 -SourceVcenter old-vc.acme.com -DestinationVcenter new-vc.acme.com

.NOTES
VMware PowerCLI is required for script to run
   
.LINK
https://niktips.wordpress.com

#>

Param(
	[Parameter(Mandatory = $true)][string]$SourceVcenter,
	[Parameter(Mandatory = $true)][string]$DestinationVcenter
)


Write-Host "Connecting to vCenter ""$SourceVcenter"".." -foreground green
Connect-ViServer $SourceVcenter | out-null
if(!$?) { exit }


Write-Host "Connecting to vCenter ""$DestinationVcenter"".." -foreground green
Connect-ViServer $DestinationVcenter | out-null
if(!$?) { exit }

Write-Host "Retrieving email actions from ""$SourceVcenter"".." -foreground green
$email_actions = Get-AlarmDefinition -Server $SourceVcenter| Get-AlarmAction -ActionType SendEmail

foreach($action in $email_actions) {	
	# Check if alarm exists on the destination vCenter
	$alarm_def = Get-AlarmDefinition -Server $DestinationVcenter -Name $action.alarmdefinition -ErrorAction SilentlyContinue
	if(!$alarm_def) {
		Write-Host "Cannot copy email action to ""$($action.to)"". Alarm ""$($action.alarmdefinition)"" not found on $DestinationVcenter. If it is a custom alarm, it has to be copied manually.." -foreground red
	}
	else {
		# Create email action on the destination vCenter
		$existing_action = Get-AlarmAction -AlarmDefinition $alarm_def -ActionType SendEmail | where { $_.to -eq $action.to }
		if($existing_action) {
			Write-Host "Email action to ""$($action.to)"" already configured for alarm ""$($action.alarmdefinition)"" on $DestinationVcenter.." -foreground yellow		
		}
		else {
			Write-Host "Copying email action for alarm ""$($action.alarmdefinition)"". Action destination is ""$($action.to)"".." -foreground green
			$alarm_action = New-AlarmAction -Email -AlarmDefinition $alarm_def -Server $DestinationVcenter -To $action.to

			# Get alarm triggers of the source alarm
			$alarm_triggers = Get-AlarmActionTrigger -AlarmAction $action

			# Recreate the same alarm triggers on the destination alarm
			foreach($trigger in $alarm_triggers) {
				# Yellow to Red trigger is enabled by default
				if($trigger.StartStatus -eq "Yellow" -and $trigger.EndStatus -eq "Red") {
						continue
				}
				else {
					Write-Host "Creating action trigger from ""$($trigger.StartStatus)"" to ""$($trigger.EndStatus)"". Repeat is set to ""$($trigger.Repeat)"".." -foreground green
					if($trigger.Repeat) {
						New-AlarmActionTrigger -AlarmAction $alarm_action -StartStatus $trigger.StartStatus -EndStatus $trigger.EndStatus -Repeat | out-null
					}
					else {
						New-AlarmActionTrigger -AlarmAction $alarm_action -StartStatus $trigger.StartStatus -EndStatus $trigger.EndStatus | out-null
					}
				}
			}
		}
	} 
}


Disconnect-VIServer $SourceVcenter -Confirm:$false	
Disconnect-VIServer $DestinationVcenter -Confirm:$false	