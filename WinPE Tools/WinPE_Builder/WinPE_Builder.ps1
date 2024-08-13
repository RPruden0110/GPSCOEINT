<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2024 v5.8.241
	 Created on:   	7/10/2024 7:29 AM
	 Created by:   	RP230049
	 Organization: 	NCR Atleos Corp
	 Filename:     	
	===========================================================================
	.DESCRIPTION
		A description of the file.
#>

# Requires -RunAsAdministrator

# Settings
$ToolBuild_Path = "G:\Work\Setup"
$PowerShell7File = "G:\Work\Setup\PowerShell-7.4.3-win-x64.zip"
$WinPE_BuildFolder = "G:\Work\Setup\WinPE"
$WinPE_Architecture = "amd64" # Or x86
$WinPE_MountFolder = "G:\Work\Setup\Mount"
$WinPE_ISOFolder = "G:\Work\Setup\ISO"
$WinPE_ISOfile = "$WinPE_ISOFolder\WinPE11_x64_PowerShell7.iso"
$Language = "en-US"

$ADK_Path = "D:\Program Files\Windows Kits\10\Assessment and Deployment Kit"
$WinPE_ADK_Path = $ADK_Path + "\Windows Preinstallation Environment"
$WinPE_OCs_Path = $WinPE_ADK_Path + "\$WinPE_Architecture\WinPE_OCs"
$DISM_Path = $ADK_Path + "\Deployment Tools" + "\$WinPE_Architecture\DISM"
$OSCDIMG_Path = $ADK_Path + "\Deployment Tools" + "\$WinPE_Architecture\Oscdimg"

# Validate locations
If (!(Test-path $OSCDIMG_Path)) { Write-Warning "OSCDIMG Path does not exist, aborting..."; Break }
If (!(Test-path $PowerShell7File)) { Write-Warning "PowerShell7File Path does not exist, aborting..."; Break }


# Delete existing WinPE build folder (if exist)
try
{
	if (Test-Path -path $WinPE_BuildFolder) { Remove-Item -Path $WinPE_BuildFolder -Recurse -ErrorAction Stop }
}
catch
{
	Write-Warning "Oupps, Error: $($_.Exception.Message)"
	Write-Warning "Most common reason is existing WIM still mounted, use DISM /Cleanup-Wim to clean up and run script again"
	Break
}

# Delete existing WinPE Mount Folder (if exist)
try
{
	if (Test-Path -path $WinPE_MountFolder) { Remove-Item -Path $WinPE_MountFolder -Recurse -ErrorAction Stop }
}
catch
{
	Write-Warning "Oupps, Error: $($_.Exception.Message)"
	Write-Warning "Most common reason is existing WIM still mounted, use DISM /Cleanup-Wim to clean up and run script again"
	Break
}
# Create Mount folder
New-Item -Path $WinPE_MountFolder -ItemType Directory -Force

# Create ISO folder
New-Item -Path $WinPE_ISOFolder -ItemType Directory -Force

# Make a copy of the WinPE boot image from Windows ADK
if (!(Test-Path -path "$WinPE_BuildFolder\Sources")) { New-Item "$WinPE_BuildFolder\Sources" -Type Directory }
Copy-Item "$WinPE_ADK_Path\$WinPE_Architecture\en-us\winpe.wim" "$WinPE_BuildFolder\Sources\boot.wim"

# Copy WinPE boot files
Copy-Item "$WinPE_ADK_Path\$WinPE_Architecture\Media\Boot" "$WinPE_BuildFolder" -Recurse
Copy-Item "$WinPE_ADK_Path\$WinPE_Architecture\Media\EFI" "$WinPE_BuildFolder" -Recurse
Copy-Item "$WinPE_ADK_Path\$WinPE_Architecture\Media\$Language" "$WinPE_BuildFolder"
Copy-Item "$WinPE_ADK_Path\$WinPE_Architecture\Media\BOOTMGR" "$WinPE_BuildFolder"
Copy-Item "$WinPE_ADK_Path\$WinPE_Architecture\Media\bootmgr.efi" "$WinPE_BuildFolder"


# Mount the WinPE image
$WimFile = "$WinPE_BuildFolder\Sources\boot.wim"
Mount-WindowsImage -ImagePath $WimFile -Path $WinPE_MountFolder -Index 1

# Add native WinPE optional components (using ADK version of dism.exe instead of Add-WindowsPackage)
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-WMI.cab # Install WinPE-WMI before you install WinPE-NetFX (dependency)
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-WMI_$Language.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-NetFx.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-NetFx_$Language.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-Scripting.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-Scripting_$Language.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-EnhancedStorage.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-EnhancedStorage_$Language.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-Dot3Svc.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-Dot3Svc_$Language.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\Microsoft-Windows-VBSCRIPT.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\Microsoft-Windows-VBSCRIPT_$Language.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-DismCmdlets.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-DismCmdlets_$Language.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-PowerShell.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-PowerShell_$Language.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-StorageWMI.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-StorageWMI_$Language.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-HTA.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-HTA_$Language.cab

# Change Background Image of WinPE
$NewAcl = Get-Acl -Path "$WinPE_MountFolder\Windows\System32\winpe.jpg"
$identity = "BUILTIN\Administrators"
$fileSystemRights = "FullControl"
$type = "Allow"
$fileSystemAccessRuleArgumentList = $identity, $fileSystemRights, $type
$fileSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $fileSystemAccessRuleArgumentList
$NewAcl.SetAccessRule($fileSystemAccessRule)
Set-Acl -Path "$WinPE_MountFolder\Windows\System32\winpe.jpg" -AclObject $NewAcl
Copy-Item -Path "$ToolBuild_Path\NCR_Boot\*" -Destination "$WinPE_MountFolder" -Recurse -Force

# Add PowerShell 7
Expand-Archive -Path $PowerShell7File -DestinationPath "$WinPE_MountFolder\Program Files\PowerShell\7" -Force

# Update the offline environment PATH for PowerShell 7
$HivePath = "$WinPE_MountFolder\Windows\System32\config\SYSTEM"
reg load "HKLM\OfflineWinPE" $HivePath
Start-Sleep -Seconds 5

# Add PowerShell 7 Paths to Path and PSModulePath
$RegistryKey = "HKLM:\OfflineWinPE\ControlSet001\Control\Session Manager\Environment"
$CurrentPath = (Get-Item -path $RegistryKey).GetValue('Path', '', 'DoNotExpandEnvironmentNames')
$NewPath = $CurrentPath + ";%ProgramFiles%\PowerShell\7\"
$Result = New-ItemProperty -Path $RegistryKey -Name "Path" -PropertyType ExpandString -Value $NewPath -Force

$CurrentPSModulePath = (Get-Item -path $RegistryKey).GetValue('PSModulePath', '', 'DoNotExpandEnvironmentNames')
$NewPSModulePath = $CurrentPSModulePath + ";%ProgramFiles%\PowerShell\;%ProgramFiles%\PowerShell\7\;%SystemRoot%\system32\config\systemprofile\Documents\PowerShell\Modules\"
$Result = New-ItemProperty -Path $RegistryKey -Name "PSModulePath" -PropertyType ExpandString -Value $NewPSModulePath -Force


# Add additional environment variables for PowerShell Gallery Support
$APPDATA = "%SystemRoot%\System32\Config\SystemProfile\AppData\Roaming"
$Result = New-ItemProperty -Path $RegistryKey -Name "APPDATA" -PropertyType String -Value $APPDATA -Force

$HOMEDRIVE = "%SystemDrive%"
$Result = New-ItemProperty -Path $RegistryKey -Name "HOMEDRIVE" -PropertyType String -Value $HOMEDRIVE -Force

$HOMEPATH = "%SystemRoot%\System32\Config\SystemProfile"
$Result = New-ItemProperty -Path $RegistryKey -Name "HOMEPATH" -PropertyType String -Value $HOMEPATH -Force

$LOCALAPPDATA = "%SystemRoot%\System32\Config\SystemProfile\AppData\Local"
$Result = New-ItemProperty -Path $RegistryKey -Name "LOCALAPPDATA" -PropertyType String -Value $LOCALAPPDATA -Force

# Cleanup (to prevent access denied issue unloading the registry hive)
Get-Variable Result | Remove-Variable
Get-Variable RegistryKey | Remove-Variable
[gc]::collect()
Start-Sleep -Seconds 5

# Unload the registry hive
reg unload "HKLM\OfflineWinPE"

# Write winpeshl.ini that launches PowerShell 7
$winpeshl = @'
[LaunchApps]
%WINDIR%\System32\wpeinit.exe
powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
%ProgramFiles%\PowerShell\7\pwsh.exe
'@ | Out-File "$WinPE_MountFolder\Windows\System32\winpeshl.ini" -Force

# Write unattend.xml file to change screen resolution
$UnattendPEx64 = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <Display>
                <ColorDepth>32</ColorDepth>
                <HorizontalResolution>1280</HorizontalResolution>
                <RefreshRate>60</RefreshRate>
                <VerticalResolution>720</VerticalResolution>
            </Display>
        </component>
    </settings>
</unattend>
'@ | Out-File "$WinPE_MountFolder\Unattend.xml" -Encoding utf8 -Force


# Unmount the WinPE image and save changes
Dismount-WindowsImage -Path $WinPE_MountFolder -Save

# Create a bootable WinPE ISO file (comment out if you don't need the ISO)
$BootData = '2#p0,e,b"{0}"#pEF,e,b"{1}"' -f "$OSCDIMG_Path\etfsboot.com", "$OSCDIMG_Path\efisys_noprompt.bin"

$Proc = Start-Process -FilePath "$OSCDIMG_Path\oscdimg.exe" -ArgumentList @("-bootdata:$BootData", '-u2', '-udfver102', "$WinPE_BuildFolder", "$WinPE_ISOfile") -PassThru -Wait -NoNewWindow
if ($Proc.ExitCode -ne 0)
{
	Throw "Failed to generate ISO with exitcode: $($Proc.ExitCode)"
}

