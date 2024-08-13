@{
    RootModule             = "UnattendXmlBuilder.psm1"
    ModuleVersion          = '1.1'
    CompatiblePSEditions   = @("Core", "Desktop")
    GUID                   = 'e99124c9-56eb-4032-b40c-1508a7c3c62c'
    Author                 = 'MartinGC94'
    CompanyName            = 'Unknown'
    Copyright              = '(c) 2023 MartinGC94. All rights reserved.'
    Description            = 'Module for building Windows unattend XML documents.'
    PowerShellVersion      = '5.1'
    FormatsToProcess       = @()
    FunctionsToExport      = @('Add-UnattendCommand','Add-UnattendDiskPartition','Add-UnattendDriverPath','Add-UnattendGroupMember','Add-UnattendImage','Add-UnattendInterfaceDnsConfig','Add-UnattendInterfaceIpConfig','Add-UnattendUser','Export-UnattendFile','New-UnattendBuilder','Set-UnattendAudioSetting','Set-UnattendAutoLogon','Set-UnattendComputerName','Set-UnattendDnsSetting','Set-UnattendDomainJoinInfo','Set-UnattendFirewallSetting','Set-UnattendIpSetting','Set-UnattendLanguageSetting','Set-UnattendOobeSetting','Set-UnattendOwnerInfo','Set-UnattendPowerSetting','Set-UnattendProductKey','Set-UnattendRdpSetting','Set-UnattendServerManagerSetting','Set-UnattendSysPrepSetting','Set-UnattendTimeSetting','Set-UnattendTpmSetting','Set-UnattendUacSetting','Set-UnattendWindowsSetupSetting','Set-UnattendWinReSetting')
    CmdletsToExport        = @()
    VariablesToExport      = @()
    AliasesToExport        = @()
    DscResourcesToExport   = @()
    FileList               = @('UnattendXmlBuilder.psd1','UnattendXmlBuilder.psm1')
    PrivateData            = @{
        PSData = @{
             Tags         = @("Unattend", "Autounattend", "XML", "Windows", "Installation")
             ProjectUri   = 'https://github.com/MartinGC94/UnattendXmlBuilder'
             ReleaseNotes = @'
1.1
    Assign parameter position 0 to Export-UnattendFile:FilePath
    Add "RecoveryBIOS" as a valid value for Add-UnattendDiskPartition:PartitionType
    Update the BIOS disk template for Add-UnattendDiskPartition so it creates the partition with the correct ID.
1.0.3
    Resolve relative paths for the SourceFile parameter of the New-UnattendBuilder command
1.0.2
    Fix TimeZone completer for Set-UnattendTimeSetting
1.0.1
    Add argument completers for the following Commands and parameters:
        Set-UnattendTimeSetting:TimeZone
        Set-UnattendLanguageSetting:UiLanguageFallback
    Add positions for the following command and parameter combinations:
        Add-UnattendCommand:Command
        Add-UnattendDriverPath:Path
        Set-UnattendComputerName:ComputerName
        Set-UnattendProductKey:ProductKey
    Fix commands that wouldn't work properly when using certain parameters:
        Add-UnattendDriverPath:Path
        Add-UnattendInterfaceIpConfig:DefaultGateway
        Set-UnattendFirewallSetting:EnabledFirewallGroups
        Set-UnattendFirewallSetting:DisabledFirewallGroups
        Set-UnattendFirewallSetting:LogDroppedPackets
1.0
    Initial release
'@
        }
    }
}
