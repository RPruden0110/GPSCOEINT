<#	
	.NOTES
	===========================================================================
	 Created on:   	7/18/2024 7:26 AM
	 Created by:   	RP230049
	 Organization: 	NCR Atleos Corp
	 Filename:     	Setup_WinPE.ps1
	===========================================================================
	.DESCRIPTION
		Starting Script to Setup the Hard Drive connected to the machine.
#>

# Load Assemblies
Add-Type -AssemblyName PresentationCore, PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Setup Variables
$Log = "X:\Setup\Log.log"
$Setup = "X:\Setup"
$Setupconfig = "X:\Setup\Config"

Write-Log -LogPath "$Log" -Message "Starting Hard Drive Partition Setup" -Level Info

# Verify Hard Disk is present in WinPE
Write-Log -LogPath "$Log" -Message "Validate a Physical hard disk is connected to core"
try
{
	$Bustype = Get-Disk -Number 0 -ErrorAction Stop | select bustype
	if (("$Bustype" -eq "HDD") -or ("$Bustype" -eq "SSD"))
	{
		Write-Log -LogPath "$Log" -Message "Valid Disk Detected Prepare drive for installation"
		Get-Disk | Out-File -FilePath "$Log" -Append
	}
}
catch
{
	Write-Log -LogPath "$Log" -Message "Failed to detect valid disk drive for installation" -Level Error
	Get-Disk | Out-File -FilePath "$Log" -Append
	$MsgBox = [System.Windows.MessageBox]::Show("Valid Hard Drive Not detected `nVerify Drive is authorized `nPress OK to Shutdown", 'Init-Disk', 'OK', 'Error')
	switch ("$msgBox") { 'OK' { Stop-Computer -ComputerName localhost } }
	break
}

# Parse Disk Configuration file
$DiskConfig = Get-Content -Raw -Path "$Setupconfig\WinPE_Config.json" | ConvertFrom-Json -Depth 99
$PartitionCount = $DiskConfig.Disk.PartitionCount

# Prepare drive for setup
Clear-Disk -Number 0 -RemoveData -Confirm:$false
$InitDisk = Get-Disk -Number 0 | select PartitionStyle
if ("$InitDisk.PartitionStyle" -eq "GPT") { Initialize-Disk -Number 0 } else { Initialize-Disk -Number 0 -PartitionStyle GPT }

# Disk - Partition Setup
if ($PartitionCount -gt 1)
{
	For ($i = 1; $i -le $PartitionCount; $i++)
	{
		$Name = ($DiskConfig.Disk.Partitions.$i).Name
		$Letter = ($DiskConfig.Disk.Partitions.$i).Letter
		$Type = ($DiskConfig.Disk.Partitions.$i).Type
		$Size = ($DiskConfig.Disk.Partitions.$i).Size
		
		Write-Log -LogPath "$Log" -Message "Disk Setup Partition $i" -Level Info
		Write-Log -LogPath "$Log" -Message "Disk Setup Partition $i Name : $Name" -Level Info
		Write-Log -LogPath "$Log" -Message "Disk Setup Partition $i Letter : $Letter" -Level Info
		Write-Log -LogPath "$Log" -Message "Disk Setup Partition $i Size : $Size" -Level Info
		Write-Log -LogPath "$Log" -Message "Disk Setup Partition $i Size Value Type : $Type" -Level Info
		
		
		if ($Name -eq "SYSTEM")
		{
			New-Partition -DiskNumber 0 -Size $Size -GptType "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" -DriveLetter "$Letter" | Format-Volume -newfilesystemlabel "$Name" -FileSystem FAT32 -Full | Out-File -FilePath "$Log" -Append
		}
		elseif ([System.String]::IsNullOrEmpty($Size))
		{
			# Setup last Partition of the drive
			New-Partition -DiskNumber 0 -Size $MaxSize -DriveLetter "$Letter" | Format-Volume -newfilesystemlabel "$Name" -FileSystem NTFS -Full | Out-File -FilePath "$Log" -Append
			Write-Log -LogPath "$Log" -Message "Partition $i Setup" -Level Info
			Write-Log -LogPath "$Log" -Message "Name:$Name  Letter:$Letter Size:$Size $Size Type:$Type" -Level Info
		}
		else
		{			
			if ("$Type" -eq "Percent")
			{
				if ("$Size" -eq "100")
				{
					$Size = "$MaxSize"
				}
				else
				{
					$Percent = [int]$Size /100
					# Get Percentage of the Space on the Disk
					$DriveSize = Get-Disk -Number 0 | select Size
					$Block = "GB"
					$DriveSize = $DriveSize.Size /1GB
					$DriveSize = $DriveSize * $Percent
					$Size = [string]$DriveSize + $Block
				}
			# Setup Partition
			New-Partition -DiskNumber 0 -Size $Size -DriveLetter "$Letter" | Format-Volume -newfilesystemlabel "$Name" -FileSystem NTFS -Full | Out-File -FilePath "$Log" -Append
			Write-Log -LogPath "$Log" -Message "Partition $i Setup" -Level Info
			Write-Log -LogPath "$Log" -Message "Name:$Name  Letter:$Letter Size:$Size Type:$Type" -Level Info
			}
			else
			{
				# Setup Partition if set for drive metric
				New-Partition -DiskNumber 0 -Size $Size -DriveLetter "$Letter" | Format-Volume -newfilesystemlabel "$Name" -FileSystem NTFS -Full | Out-File -FilePath "$Log" -Append
				Write-Log -LogPath "$Log" -Message "Partition $i Setup" -Level Info
				Write-Log -LogPath "$Log" -Message "Name:$Name  Letter:$Letter Size:$Size Type:$Type" -Level Info
			}
		}
	}
}
Get-Volume | Out-File -FilePath "$Log" -Append
Write-Log -LogPath "$Log" -Message "Disk Setup Complete" -Level Info

