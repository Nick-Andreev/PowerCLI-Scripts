<#

.SYNOPSIS
This is a PowerShell script that collects Veeam job and repository statistics for the purpose of performing a simple health check.

.DESCRIPTION
Script supports Veeam backup, replication and tape jobs, as well as backup and tape repository/pool reporting. VM Copy and 
SureBackup jobs are not supported at this stage. Size and restore point statistics are currently supported for backup jobs only.

.PARAMETER VeeamServer
Specifies the hostname or IP address of the server where Veeam Backup and Replication is installed. Since the script should be
typically run from the Veeam server itself, "localhost" can be used.

.EXAMPLE
./veeam-stats-x.x.ps1

.EXAMPLE
./veeam-stats-x.x.ps1 -VeeamServer 10.10.10.1

.NOTES
Veeam PowerShell module is required to run the script. Run the script from the Veeam server, unless VeeamPSSnapIn is installed locally.
   
.LINK
http://niktips.wordpress.com

#>

<#
Script name: veeam-stats.ps1
Created on: 16/09/2016
Last updated: 27/11/2016
Author: Nick Andreev, @nick_andreev_au, https://niktips.wordpress.com
Description: The purpose of the script is to gather Veeam backup job and repository information.
Dependencies: None known

===Tested Against Environment====
Veeam Version: 9
PowerShell Version: 2.0
OS Version: Windows Server 2008 R2

Veeam Version: 9
PowerShell Version: 3.0
OS Version: Windows Server 2008 R2

Veeam Version: 9
PowerShell Version: 3.0
OS Version: Windows Server 2012
#>

#region script and variables initialization
Param (
	[string]$VeeamServer = "localhost"
)

if ((Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue) -eq $null) {
    Write-Host -foreground Green "Loading the Veeam PowerShell snap-in.."
    Add-PsSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue 
	if((Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue) -eq $null) {
		Write-Host -foreground red "Cannot load Veeam PowerShell module. Make sure the script is run from the Veeam server, unless VeeamPSSnapIn is installed locally."
		exit
	}
}

if((Get-PSSnapin VeeamPSSnapIn).Version.Major -lt 9) {
		Write-Host -foreground red "This script will not work for Veeam Backup and Replication older than version 9."
		exit
}

$error_messages = @()
$warning_messages = @()

Connect-VBRServer -Server $VeeamServer
if(!(Get-VBRServerSession)) {
	Write-Host -foreground red "Cannot connect to Veeam backup server ""$veeam_server""."
	exit
}
#endregion

#region backup and replication job statistics
Write-Host -foreground Green "`nJob Name; Job Type; Full Backup Size, GB; Incremental Size, GB; Total Consumed Space, GB; Restore Points; State; Last Run; Last Result"
$backup_jobs = Get-VBRJob | Sort-Object JobType
foreach ($job in $backup_jobs) {
    #$job.JobType

	$job_schedule = Get-VBRJobScheduleOptions -Job $job
	# This job is disabled	
	if($job.IsScheduleEnabled -ne "True") {
		$job_state = "Disabled"
		$warning_messages += "$($job.Name); Job is disabled."
		continue
	}
	# This job is enabled, but not scheduled to run
	elseif(!$job_schedule.NextRun -and !$job_schedule.OptionsScheduleAfterJob.IsEnabled) {
		$job_state = "Not Scheduled"
		$warning_messages += "$($job.Name); Job is enabled, but not scheduled."
		continue
	}
	else {
		$job_state = "Enabled"
	}


	$last_result = $job.GetLastresult()
	# If last result is None, job is may still be working. Then use the state instead.
	if($last_result -eq "None") {
		$last_session = Get-VBRSession -Job $job -Last
		$last_result = $last_session.State
	}

	# Gather information on backup jobs
	if($job.JobType -eq "Backup") {
		# This job has never run
		if($job_schedule.LatestRunLocal -eq 0) {
			$last_run = "Never"
			$error_messages += "$($job.Name); Job has never run." 
		}
		else {
			$last_run = Get-Date $job_schedule.LatestRunLocal -Format 'dd/MM/yyyy'
		}
		
		# Calculate full backup size, incremental backup size and total space consumed
		$veeam_backups = Get-VBRBackup | Where-Object {$_.Info.JobId -eq $job.Info.Id}
        	$full_size = 0
        	$inc_size = 0
		$backup_size = 0
		$inc_backup_sizes = @()
		$full_backup_sizes = @()
		foreach($backup in $veeam_backups) {
			$restore_points = $backup.getallstorages().Count
			foreach($restore_point in $backup.getallstorages()) {
				$backup_size += $restore_point.Stats.backupsize
				if($restore_point.IsFull -ne "True") {
					$inc_backup_sizes += $restore_point.Stats.backupsize
				}
				else {
					$full_backup_sizes += $restore_point.Stats.backupsize
				}
			}
		}

		$backup_size_gb = [math]::Round($backup_size / 1024 / 1024 / 1024, 1)

		$inc_min_max = $inc_backup_sizes | Measure-Object -Minimum -Maximum
		$inc_min_gb = [math]::Round($inc_min_max.Minimum / 1024 / 1024 / 1024, 1)
		$inc_max_gb = [math]::Round($inc_min_max.Maximum / 1024 / 1024 / 1024, 1)

		$full_min_max = $full_backup_sizes | Measure-Object -Minimum -Maximum
		$full_min_gb = [math]::Round($full_min_max.Minimum / 1024 / 1024 / 1024, 1)
		$full_max_gb = [math]::Round($full_min_max.Maximum / 1024 / 1024 / 1024, 1)

		# If there is only one restore point, incremental size doesn't apply
		if($restore_points -eq 1) {
			$inc_size = "n/a"
		}
		else {
			if($inc_min_gb -eq $inc_max_gb) {
				$inc_size = "$inc_min_gb"
			}
			else {
				$inc_size = "$inc_min_gb - $inc_max_gb"
			}
		}
		if($full_min_gb -eq $full_max_gb) {
			$full_size = "$full_min_gb"
		}
		else {
			$full_size = "$full_min_gb - $full_max_gb"
		}

		# Determine the number of configured restore points
		$retain_cycles = $job.Options.BackupStorageOptions.RetainCycles

		# This job has only one restore point
		if($retain_cycles -eq 1) {
			$warning_messages += "$($job.Name); Job is configured to keep only one full backup (no incrementals)."
		}

		# Notify if the number of restore points is less than the number of configured retain cycles
		if($restore_points -lt $retain_cycles) {
			$warning_messages += "$($job.Name); Job has less restore points ($restore_points) than configured ($retain_cycles)."
		}

		Write-Host "$($job.Name); Local; $full_size; $inc_size; $backup_size_gb; $restore_points; $job_state; $last_run; $last_result"
	}

	# Gather information on replication jobs
	elseif($job.JobType -eq "Replica"){
		# Get-VBRJobScheduleOptions for replica jobs return wrong LatestRunLocal time. This is a workaround, 
		# which is slow. It uses job session creation time to determine last run time.
		$last_session = Get-VBRBackupSession | where { $_.OrigJobName -eq $job.Name} | Sort creationtime -Descending | select -First 1
		$last_run = Get-Date $last_session.CreationTime -Format 'dd/MM/yyyy' 

		Write-Host "$($job.Name); Replication; n/a; n/a; n/a; n/a; $job_state; $last_run; $last_result"
	}

	# Gather information on copy jobs
	elseif($job.JobType -eq "BackupSync"){
		# For the most time, the backup job remains in the "Idle" state, waiting for a new restore point to appear
		# and represents a healthy job state.
		if ($last_result) {
			$last_result = "Success"
		}
		Write-Host "$($job.Name); Backup Copy; n/a; n/a; n/a; n/a; $job_state; $last_run; $last_result"
	}


	# Determine if job last run was not successfull
	if(($job.JobType -eq "Backup" -or $job.JobType -eq "Replica" -or $job.JobType -eq "BackupSync") -and
		($job_state -eq "Enabled" -and $last_result -ne "Success" -and $last_result -ne "Working"))
	{
		$warning_messages += "$($job.Name); Job last run result is not ""Success""."
		# 1. Determine what the warning/error message was.
		# 2. Get-VBRBackupSession is used here, as Get-VBRSession does not work for replica jobs.
		# 3. "where" statement is used instead of the "-Name" parameter in Get-VBRBackupSession, as
		#    job names returned by Get-VBRBackupSession do not match job names returned by Get-VBRJob
		#    and include additional information:
		#    Get-VBRJob: Replication PROD Servers
		#    Get-VBRBackupSession: Replication PROD Servers (Incremental)
		# 4. Using Veeam.Backup.Core.CBackupTaskSession is a hack and may not work in future versions,
		#    but there is no other supported way in Veeam 9 to get the job failure reason.
		$last_session = Get-VBRBackupSession | where {$_.OrigJobName -eq $job.Name} | Sort creationtime -Descending | select -First 1
		$infos = [Veeam.Backup.Core.CBackupTaskSession]::GetByJobSession($last_session.id)
		foreach($info in $infos) {
			if($info.Status -ne "Success") {
				$warning_messages += "$($job.Name); Object Name: $($info.ObjectName). Job error message is ""$($info.Reason)""."
			}
		}
	}
}
#endregion

#region tape job statistics
$tape_jobs = Get-VBRTapeJob
foreach ($job in $tape_jobs) {
	# If there're no tape jobs configured, Get-VBRTapeJob returns one empty tape job. Skip
	# it and exit the loop if that's the case.
	if(!$job) {
		continue
	}

	# This job is disabled
	if(!$job.NextRun) {
		$job_state = "Disabled"
		$warning_messages += "$($job.Name); Job is disabled."
		continue
	}
	else {
		$job_state = "Enabled"
	}

	$last_result = $job.LastResult
	# If last result is None, job may still be working or it can be waiting for tape. Then
	# use the state instead.
	if($last_result -eq "None") {
		$last_result = $job.LastState
	}

	$last_session = Get-VBRSession -Job $job -Last
	# Determine if the job has never run
	if(!$last_session) {
		$last_run = "Never"
		$error_messages += "$($job.Name); Job has never run." 
	}
	else {
		$last_run = Get-Date $last_session.CreationTime -Format 'dd/MM/yyyy'
	}

	Write-Host "$($job.Name); Tape; n/a; n/a; n/a; n/a; $job_state; $last_run; $last_result"

	# Determine whether job last run was successfull
	if($job_state -eq "Enabled" -and $last_result -ne "Success" -and 
        $last_result -ne "Working" -and $last_result -ne "WaitingTape")
    {
		$warning_messages += "$($job.Name); Job last run result is not ""Success""."
		# Determine what the warning/error message was
		$last_session = Get-VBRSession -Job $job -Last
		$infos = [Veeam.Backup.Core.CBackupTaskSession]::GetByJobSession($last_session.id)
		foreach($info in $infos) {
			if($info.Status -ne "Success") {
				$warning_messages += "$($job.Name); Job last error message is ""$($info.Reason)""."
			}
		}
	}
}
#endregion

#region SureBackup job statistics
$surebackup_jobs = Get-VSBJob
foreach ($job in $surebackup_jobs) {
	# This job is disabled
	if(!$job.NextRun) {
		Write-Host "Job: $job"
		$job_state = "Disabled"
		$warning_messages += "$($job.Name); Job is disabled."
		continue
	}
	else {
		$job_state = "Enabled"
	}

	# SureBackup jobs have neither the "LastResult", nor "LastState" parameters. Fetch this information
	# from the last session.
	$last_session = Get-VSBSession -Name $job.Name | Sort creationtime -Descending | select -First 1
	# Determine if the job has never run
	if(!$last_session) {
		$last_run = "Never"
        $last_result = "None"
		$error_messages += "$($job.Name); Job has never run." 
	}
	else {
		$last_run = Get-Date $last_session.CreationTime -Format 'dd/MM/yyyy'
        	$last_result = $last_session.Result
	}

	Write-Host "$($job.Name); SureBackup; n/a; n/a; n/a; n/a; $job_state; $last_run; $last_result"

	# Determine whether job last run was successfull
	if($job_state -eq "Enabled" -and $last_result -ne "Success" -and $last_result -ne "Working") {
		$warning_messages += "$($job.Name); Job last run result is not ""Success""."
		# Determine what the warning/error message was
		$last_session = Get-VSBSession -Job $job -Last
		$infos = [Veeam.Backup.Core.CBackupTaskSession]::GetByJobSession($last_session.id)
		foreach($info in $infos) {
			if($info.Status -ne "Success") {
				$warning_messages += "$($job.Name); Job last error message is ""$($info.Reason)""."
			}
		}
	}
}
#endregion

#region backup repository and tape pool information
Write-Host -foreground Green "`nRepository; Path; Free, GB; Total, GB"
$backup_repos = Get-VBRBackupRepository
foreach($repo in $backup_repos) {
	# Calculate free space and total capacity
	$total_space = [math]::Round($repo.Info.CachedTotalSpace / 1024 / 1024 / 1024, 1)
	$free_space = [math]::Round($repo.Info.CachedFreeSpace / 1024 / 1024 / 1024, 1)
	Write-Host "$($repo.Name); $($repo.Path); $free_space; $total_space"

	# Log a warning if free space is less than 10% or error if less than 5%
	$pct_free = [math]::Round($repo.Info.CachedFreeSpace * 100 / $repo.Info.CachedTotalSpace)
	if($pct_free -le 5) {
		$error_messages += "n/a; Backup repository ""$($repo.Name)"" has %$pct_free of free space"
	}	
	elseif($pct_free -le 10) {
		$warning_messages += "n/a; Backup repository ""$($repo.Name)"" has %$pct_free of free space"
	}
}


$tape_pools = Get-VBRTapeMediaPool
foreach($pool in $tape_pools) {
	# Skip empty pools
	if($pool.Capacity -eq 0) {
		continue
	}

	# Calculate free space and total capacity
	$total_space = [math]::Round($pool.Capacity / 1024 / 1024 / 1024, 1)
	$free_space = [math]::Round($pool.FreeSpace / 1024 / 1024 / 1024, 1)
	Write-Host "$($pool.Name); n/a; $free_space; $total_space"

	# Log a warning if free space is less than 10% or error if less than 5%
	$pct_free = [math]::Round($pool.FreeSpace * 100 / $pool.Capacity)
	if($pct_free -le 5) {
		$error_messages += "n/a; Tape media pool ""$($pool.Name)"" has %$pct_free of free space"
	}
	elseif($pct_free -le 10) {
		$warning_messages += "n/a; Tape media pool ""$($pool.Name)"" has %$pct_free of free space"
	}	
}
#endregion

#region print warnings/errors and exit
Write-Host -foreground Green "`nJob; Error Description"
if($warning_messages) {
	foreach($msg in $warning_messages) {
		Write-Host -foreground yellow "$msg"
	}
}

if($error_messages) {
	foreach($msg in $error_messages) {
		Write-Host -foreground red "$msg"
	}
}
 
Disconnect-VBRServer
#endregion
