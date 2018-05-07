### Description

This PowerShell script reports Veeam job and repository statistics and performs a simple health check.

Script supports Veeam backup, replication and tape jobs, as well as backup and tape repository/pool reporting. VM Copy and SureBackup jobs are not supported at this stage. Size and restore point statistics are currently supported for backup jobs only.

The following checks are performed:

* Job is disabled
* Job is not scheduled
* Job has never run
* Job has no incremental backups (only a full)
* Job has less restore points than configured
* Last job run failed and what the error was (both at job and job component levels)
* Backup/tape repository has less than 10% of space
* Backup/tape repository has less than 5% of space

### Prerequisites

* None

### Usage Examples

Copy the script to the Veeam Backup and Replication server and run:

```
PS> .\veeam-stats-1.0.ps1
```

For detailed description see script help:

```
PS> Get-Help .\veeam-stats-1.0.ps1 -full
```

### Environment Configuration

* Veeam Backup and Replication 9
* PowerShell 3.0
* If script is run from the machine that is not the Veeam Backup and Replication server, VeeamPSSnapIn should also be installed. If the script is invoked locally from the Veeam Backup and Replication server, this is not required.

### Author

Nick Andreev:

* https://niktips.wordpress.com
* @nick_andreev_au