#====================================================================#
#   SCRIPT:        Compellent Deploy                                 #
#   CREATED:       15/04/2016                                        #
#   MODIFIED:      15/04/2016                                        #
#   OWNER:         Nick Andreev / Blog: niktips.wordpress.com        #  
#                  / Twitter: @nick_andreev_au                       #
#   VERSION:       v.1.0                                             #
#====================================================================#
#   CHANGELOG:                                                       #
#                                                                    #
#   v.1.0                                                            #
#     - First release                                                #
#                                                                    #
#   USAGE:                                                           #
#                                                                    #
#    - Provide the list of servers in server_list.csv                #
#    - Provide the list of volumes in volume_list.csv                #
#    - Configure the script variables                                #
#                                                                    #
#   NOTES:                                                           #
#                                                                    #
#    - Install Dell Storage Center Command Set for Windows           #
#      PowerShell before using the script, which can be found at     #
#      Dell Compellent Knowledge Center.                             #
#    - Value of the Unit column in volume_list.csv can be            #
#      m (megabytes), g (gigabytes) or t (terabytes)                 #                           
#    - Changes to CSV files can be made on the fly without exiting   #
#      the script by using Re-read CSV option.                       #
#    - You can get the full list of supported server operating       #
#      systems and versions for the $server_os and $server_os_ver    #
#      variables by using the "List supported server operating       #
#      systems" menu option.                                         #
#                                                                    #
#   TODO:                                                            #
#                                                                    #
#====================================================================#


#============================ Variables =============================#

$compellent_ip = "10.10.9.100"
$username = "Admin"
$server_cluster = "Production vSphere Cluster"
$volume_folder = "VMware Datastores"
$server_os = "VMware ESX"
$server_os_ver = "5.5"
$csv_rootdir = ".\"

#============================ Functions =============================#

function read_csv() {
	$global:servers = Import-CSV $($csv_rootdir + "\server_list.csv")
	$global:volumes = Import-CSV $($csv_rootdir + "\volume_list.csv")
}

#=========================== Main script ============================#

# Add Compellent PowerShell Snap-In

if (!(Get-PSSnapin -Name Compellent.StorageCenter.PSSnapin -ErrorAction SilentlyContinue)) {
	Add-PSSnapin Compellent.StorageCenter.PSSnapin
}

# Establish a connection

$connection = Get-SCConnection -HostName $compellent_ip -User $username
if(!$connection) { exit }

# Read CSV files

read_csv

do {
	Write-Host " "
	Write-Host "Server configuration menu:" -foregroundcolor yellow
	Write-Host " 1. Create a server cluster"	
	Write-Host " 2. Create servers"
	Write-Host " "

	Write-Host "Volume configuration menu:" -foregroundcolor yellow
	Write-Host " 3. Create a volume folder"
	Write-Host " 4. Provision volumes"
	Write-Host " 5. Map volumes"
	Write-Host " "

	Write-Host "Actions menu:" -foregroundcolor yellow
	Write-Host " 6. Re-read CSV"
	Write-Host " 7. List supported server operating systems"
	Write-Host " 0. Quit"
	Write-Host " "
	$response = Read-Host "Select from menu"


switch ($response) {
1 {
	Write-Host " "
	Write-Host "-- Create a server cluster" -foregroundcolor green
	$ostype_obj = Get-SCOSType -Product $server_os -Version $server_os_ver -Connection $connection
	if(!$ostype_obj) {
		Write-Host "-- No such server OS/version combination: `"$($server_os) $($server_os_ver)`"." -foregroundcolor red	
		break
	}
	New-SCServer -Name $server_cluster -ServerType "Cluster" -SCOSType $ostype_obj -Connection $connection | out-null
	Write-Host "-- Operation complete" -foregroundcolor green
}
2 {
	Write-Host " "
	Write-Host "-- Create servers" -foregroundcolor green
	$ostype_obj = Get-SCOSType -Product $server_os -Version $server_os_ver -Connection $connection
	if(!$ostype_obj) {
		Write-Host "-- No such server OS/version combination: `"$($server_os) $($server_os_ver)`"." -foregroundcolor red	
		break
	}
	$cluster = Get-SCServer -Name $server_cluster -Connection $connection
	if(!$cluster) {
		Write-Host "-- No such server cluster: `"$($server_cluster)`"." -foregroundcolor red	
		break
	}
	foreach ($server in $servers) {
		New-SCServer -Name $server.Host -SCOSType $ostype_obj -ParentSCServer $cluster -iSCSIAddresses $server.iSCSI_IP1, $server.iSCSI_IP2 -Connection $connection | out-null
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
3 {
	Write-Host " "
	Write-Host "-- Create a volume folder" -foregroundcolor green
	New-SCVolumeFolder -Name $volume_folder -Connection $connection | out-null
	Write-Host "-- Operation complete" -foregroundcolor green
}
4 {
	Write-Host " "
	Write-Host "-- Provision volumes" -foregroundcolor green
	$volume_folder_obj = Get-SCVolumeFolder -Name $volume_folder -Connection $connection
	if(!$volume_folder_obj) {
		Write-Host "-- No such volume folder: `"$($volume_folder)`"." -foregroundcolor red	
		break
	}
	foreach ($volume in $volumes) {
		if($volume.Unit -ne "m" -And $volume.Unit -ne "g" -And $volume.Unit -ne "t") {
			Write-Host "-- Invalid unit of measurement: `"$($volume.Unit)`". Has to be m for megabytes," -foregroundcolor red
			Write-Host "g for gigabytes or t for terabytes. Skipping volume: `"$($volume.Volume)`"." -foregroundcolor red	
			continue
		}
		$vol_size = $volume.Size + $volume.Unit
		New-SCVolume -Name $volume.Volume -Size $vol_size -ParentSCVolumeFolder $volume_folder_obj -Connection $connection | out-null
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
5 {
	Write-Host " "
	Write-Host "-- Map volumes" -foregroundcolor green
	foreach ($volume in $volumes) {
		$volume_path = $volume_folder + "\" + $volume.Volume
		$volume_obj = Get-SCVolume -LogicalPath $volume_path -Connection $connection
		if(!$volume_obj) {
			Write-Host "-- No such volume: `"$($volume_path)`". Skipping." -foregroundcolor red	
			continue
		}
		$server_obj = Get-SCServer -Name $server_cluster -Connection $connection
		if(!$server_obj) {
			Write-Host "-- No such server cluster: `"$($server_cluster)`". Skipping volume `"$($volume_path)`"." -foregroundcolor red	
			continue
		}
		New-SCVolumeMap -SCVolume $volume_obj -SCServer $server_obj -Connection $connection
	}
	Write-Host "-- Operation complete" -foregroundcolor green
}
6 {
	Write-Host " "
	Write-Host "-- Re-read CSV" -foregroundcolor green
	read_csv
	Write-Host "-- Operation complete" -foregroundcolor green
}
7 {
	Write-Host " "
	Write-Host "-- List supported server operating systems" -foregroundcolor green
	Get-SCOSType -Connection $connection | Format-Table -Property Product,Version
	Write-Host "-- Operation complete" -foregroundcolor green
}
}
} while ($response -ne "0")






