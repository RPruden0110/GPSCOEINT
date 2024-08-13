using namespace System
using namespace System.Collections
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Text
using namespace System.Xml
enum RdpSecurityLayer
{
    RDP       = 0
    Negotiate = 1
    TLS       = 2
}
enum TpmClearBehavior
{
    Never     = 0
    WhenOwner = 1
    Always    = 2
}
class UnattendBuilder
{
#region Properties
    hidden [xml] $UnattendXml
    hidden [XmlNamespaceManager] $NamespaceManager
    hidden [XmlElement[]] $Passes = [XmlElement[]]::new(7)
    hidden [string] $Namespace = 'builder'
#endregion

#region Constructors
    UnattendBuilder()
    {
        $Xml  = [xml]::new()
        $null = $Xml.AppendChild($Xml.CreateXmlDeclaration("1.0", 'utf-8', $null))
        $null = $Xml.AppendChild($Xml.CreateElement('unattend', "urn:schemas-microsoft-com:unattend"))
        $null = $Xml.ChildNodes[1].SetAttribute('xmlns', 'http://www.w3.org/2000/xmlns/', 'urn:schemas-microsoft-com:unattend')

        $this.UnattendXml = $Xml
        $this.SetNamespaceManager()
    }

    UnattendBuilder([xml] $LoadedXml)
    {
        $this.UnattendXml = $LoadedXml
        $this.SetNamespaceManager()
        $this.UpdatePasses()
    }

    UnattendBuilder([string] $XmlFilePath)
    {
        $Xml = [xml]::new()
        $Xml.Load($XmlFilePath)
        $this.UnattendXml = $Xml
        $this.SetNamespaceManager()
        $this.UpdatePasses()
    }
#endregion

#region Internal methods
    hidden [XmlElement] AddPass([UnattendPass] $Pass)
    {
        $NewPass = $this.UnattendXml.CreateElement("settings", 'urn:schemas-microsoft-com:unattend')
        $NewPass.SetAttribute("pass", $Pass)
        $this.Passes[$Pass.value__] = $NewPass
        return $NewPass
    }

    hidden [void] SetNamespaceManager()
    {
        $Manager = [XmlNamespaceManager]::new($this.UnattendXml.NameTable)
        $Manager.AddNamespace($this.Namespace, 'urn:schemas-microsoft-com:unattend')
        $this.NamespaceManager = $Manager
    }

    hidden [void] UpdatePasses()
    {
        foreach ($Pass in [Enum]::GetValues([UnattendPass]))
        {
            $FoundItem = $this.UnattendXml.SelectSingleNode("./$($this.Namespace):unattend/$($this.Namespace):settings[@pass = '$Pass']", $this.NamespaceManager)
            if ($null -ne $FoundItem)
            {
                $this.Passes[$Pass.value__] = $FoundItem
            }
        }
    }

    hidden [XmlElement] CreateComponent([string] $ComponentName)
    {
        return $this.CreateElement(
            "component",
            [ordered]@{
                name                  = $ComponentName
                processorArchitecture = 'amd64'
                publicKeyToken        = '31bf3856ad364e35'
                language              = 'neutral'
                versionScope          = 'nonSxS'
                'xmlns:wcm'           = 'http://schemas.microsoft.com/WMIConfig/2002/State'
                'xmlns:xsi'           = 'http://www.w3.org/2001/XMLSchema-instance'
            },
            $true
        )
    }
#endregion

#region Public methods
    [void] AddSimpleListToElement([string[]] $List, [string] $ItemName, [XmlElement] $Element)
    {
        for ($i = 0; $i -lt $List.Count; $i++)
        {
            $this.CreateAndAppendElement(
                $ItemName,
                $List[$i],
                [ordered]@{
                    action   = 'add'
                    keyValue = "$i"
                },
                $Element
            )
        }
    }

    [void] AddHashtableValuesToElement([hashtable] $Table, [XmlElement] $Element)
    {
        foreach ($Key in $Table.Keys)
        {
            $Value = $Table[$Key]

            if ($Value -is [bool])
            {
                $null = $Element.AppendChild($this.CreateElement($Key, $Value))
            }
            else
            {
                $null = $Element.AppendChild($this.CreateElement($Key, $Value))
            }
        }
    }

    [void] AddCredentialToElement([pscredential] $Credential, [XmlElement] $Element)
    {
        $CredentialsElement = $Element.AppendChild($this.CreateElement('Credentials'))
        $NetCreds = $Credential.GetNetworkCredential()
        if (![string]::IsNullOrEmpty($NetCreds.Domain))
        {
            $this.CreateAndAppendElement('Domain', $NetCreds.Domain, $CredentialsElement)
        }
        $this.CreateAndAppendElement('Username', $NetCreds.UserName, $CredentialsElement)
        $this.CreateAndAppendElement('Password', $NetCreds.Password, $CredentialsElement)
    }

    [void] SetCredentialOnElement([pscredential] $Credential, [XmlElement] $Element)
    {
        $CredentialsElement = $Element.SelectSingleNode("./$($this.Namespace):Credentials", $this.NamespaceManager)
        if ($null -eq $CredentialsElement)
        {
            $CredentialsElement = $Element.AppendChild($this.CreateElement('Credentials'))
        }
        else
        {
            $CredentialsElement = $Element.ReplaceChild($this.CreateElement('Credentials'), $CredentialsElement)
        }

        $NetCreds = $Credential.GetNetworkCredential()
        if (![string]::IsNullOrEmpty($NetCreds.Domain))
        {
            $this.CreateAndAppendElement('Domain', $NetCreds.Domain, $CredentialsElement)
        }
        $this.CreateAndAppendElement('Username', $NetCreds.UserName, $CredentialsElement)
        $this.CreateAndAppendElement('Password', $NetCreds.Password, $CredentialsElement)
    }

    [XmlElement] GetOrCreatePass([UnattendPass] $Pass)
    {
        $ReturnPass = $this.Passes[$Pass.value__]
        if ($null -eq $ReturnPass)
        {
            $ReturnPass = $this.AddPass($Pass)
        }

        return $ReturnPass
    }

    [XmlElement] GetOrCreateComponent([string] $ComponentName, [UnattendPass] $Pass)
    {
        $PassElement = $this.GetOrCreatePass($Pass)
        $ComponentElement = $PassElement.SelectSingleNode("./$($this.Namespace):component[@name='$ComponentName']", $this.NamespaceManager)
        if ($null -eq $ComponentElement)
        {
            $ComponentElement = $PassElement.AppendChild($this.CreateComponent($ComponentName))
        }

        return $ComponentElement
    }

    [XmlElement] GetOrCreateChildElement([string] $ElementName, [XmlElement] $Parent)
    {
        $ChildElement = $Parent.SelectSingleNode("./$($this.Namespace):$ElementName", $this.NamespaceManager)
        if ($null -eq $ChildElement)
        {
            $ChildElement = $Parent.AppendChild($this.CreateElement($ElementName))
        }

        return $ChildElement
    }

    [XmlElement] GetChildElementFromXpath ([string]$Path, [XmlElement] $Parent)
    {
        # The regex adds the proper namespace to each path segment that needs one.
        # Relative path segments, and special xpath function calls don't get it.
        $RealPath = $Path -replace '\/(?=\w+(?:\/|$))', "/$($this.Namespace):"
        return $Parent.SelectSingleNode($RealPath, $this.NamespaceManager)
    }

    [XmlElement] CreateElement([string] $Name)
    {
        return $this.UnattendXml.CreateElement($Name, 'urn:schemas-microsoft-com:unattend')
    }

    [XmlElement] CreateElement([string] $Name, [IDictionary] $AttributesToAdd)
    {
        return $this.CreateElement($Name, $AttributesToAdd, $false)
    }

    [XmlElement] CreateElement([string] $Name, [IDictionary] $AttributesToAdd, [bool] $NoNamespaceUri)
    {
        $Element = $this.CreateElement($Name)
        foreach ($Key in $AttributesToAdd.Keys)
        {
            if ($NoNamespaceUri)
            {
                $null = $Element.SetAttribute($Key, $AttributesToAdd[$Key])
            }
            else
            {
                $null = $Element.SetAttribute($Key, 'http://schemas.microsoft.com/WMIConfig/2002/State', $AttributesToAdd[$Key])
            }
        }
        return $Element
    }

    [XmlElement] CreateElement([string] $Name, [string] $Value)
    {
        $Element = $this.CreateElement($Name)
        $ElementValue = $this.UnattendXml.CreateTextNode($Value)
        $null = $Element.AppendChild($ElementValue)
        return $Element
    }

    [XmlElement] CreateElement([string] $Name, [string] $Value, [IDictionary] $AttributesToAdd)
    {
        $Element = $this.CreateElement($Name, $AttributesToAdd)
        $ElementValue = $this.UnattendXml.CreateTextNode($Value)
        $null = $Element.AppendChild($ElementValue)
        return $Element
    }

    [XmlElement] CreateElement([string] $Name, [bool] $Value)
    {
        return $this.CreateElement($Name, $Value.ToString().ToLower())
    }

    [void] CreateAndAppendElement([string] $Name, [IDictionary] $AttributesToAdd, [XmlElement] $Parent)
    {
        $null = $Parent.AppendChild($this.CreateElement($Name, $AttributesToAdd))
    }

    [void] CreateAndAppendElement([string] $Name, [string] $Value, [XmlElement] $Parent)
    {
        $null = $Parent.AppendChild($this.CreateElement($Name, $Value))
    }

    [void] CreateAndAppendElement([string] $Name, [string] $Value, [IDictionary] $AttributesToAdd, [XmlElement] $Parent)
    {
        $null = $Parent.AppendChild($this.CreateElement($Name, $Value, $AttributesToAdd))
    }

    [void] CreateAndAppendElement([string] $Name, [bool] $Value, [XmlElement] $Parent)
    {
        $null = $Parent.AppendChild($this.CreateElement($Name, $Value))
    }

    [void] SetElementValue([string] $Name, [string] $Value, [XmlElement] $Parent)
    {
        $Element = $this.GetOrCreateChildElement($Name, $Parent)
        if ($Element.HasChildNodes)
        {
            $null = $Element.ReplaceChild($this.UnattendXml.CreateTextNode($Value), $Element.FirstChild)
        }
        else
        {
            $null = $Element.AppendChild($this.UnattendXml.CreateTextNode($Value))
        }
    }

    [void] SetElementValue([string] $Name, [bool] $Value, [XmlElement] $Parent)
    {
        $this.SetElementValue($Name, $Value.ToString().ToLower(), $Parent)
    }

    [xml] ToXml()
    {
        foreach ($Pass in $this.Passes)
        {
            if ($null -ne $Pass)
            {
                $ExistingNode = $this.UnattendXml.SelectSingleNode("/$($this.Namespace):unattend/$($this.Namespace):settings[@pass=$($Pass.pass)]", $this.NamespaceManager)
                if ($null -eq $ExistingNode)
                {
                    $null = $this.UnattendXml.ChildNodes[1].AppendChild($Pass)
                }
            }
        }

        return $this.UnattendXml
    }

    [string] ToString()
    {
        $Xml = $this.ToXml()
        $Writer = [StringWriter]::new()
        $Xml.Save($Writer)
        $Text = $Writer.ToString()
        $Writer.Dispose()
        return $Text
    }
#endregion
}
enum UnattendPass
{
    windowsPE        = 0
    offlineServicing = 1
    generalize       = 2
    specialize       = 3
    auditSystem      = 4
    auditUser        = 5
    oobeSystem       = 6
}
function AddFirewallGroupsToElement
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter(Mandatory)]
        [XmlElement]
        $Parent,

        [Parameter(Mandatory)]
        [string[]]
        $GroupNames,

        [Parameter(Mandatory)]
        [string]
        $FirewallProfile,

        [Parameter(Mandatory)]
        [bool]
        $Active
    )
    process
    {
        foreach ($GroupName in $GroupNames)
        {
            $Attributes = [ordered]@{
                action   = 'add'
                keyValue = (New-Guid).Guid
            }
            $FwGroupElement = $Parent.AppendChild($UnattendBuilder.CreateElement("FirewallGroup", $Attributes))
            $UnattendBuilder.CreateAndAppendElement("Group", $GroupName, $FwGroupElement)
            $UnattendBuilder.CreateAndAppendElement("Active", $Active, $FwGroupElement)
            $UnattendBuilder.CreateAndAppendElement("Profile", $FirewallProfile, $FwGroupElement)
        }
    }
}
function EncodeUnattendPassword
{
    [OutputType([String])]
    Param
    (
        [Parameter(Mandatory)]
        [string]
        $Password,

        [Parameter()]
        [ValidateSet('OfflineLocalAdmin', 'LocalAdmin', 'UserAccount')]
        [string]
        $Kind
    )
    End
    {
        $MagicString = switch ($Kind)
        {
            'OfflineLocalAdmin' {'OfflineAdministratorPassword';break}
            'LocalAdmin' {'AdministratorPassword';break}
            'UserAccount' {'Password';break}
            Default{''}
        }
        [Convert]::ToBase64String([Encoding]::Unicode.GetBytes($Password + $MagicString))
    }
}
<#
.SYNOPSIS
    Adds commands that are run automatically at logon, or during the installation.

.DESCRIPTION
    Adds commands that are run automatically at logon, or during the installation.
    Commands can be set to run at first login, or on every login.
    Multiple commands can be specified at once, but if more specific settings need to be specified (different descriptions) then you can run this command multiple times to add each command.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass where the commands should run.
    Valid values are:
    windowsPE
    specialize (default)
    auditUser

.PARAMETER FirstLogonCommand
    Specifies that the command should only run the first time a user logs in.

.PARAMETER LogonCommand
    Specifies that the command is persistent, and should run every time a user logs in.

.PARAMETER Async
    Specifies that the command is run asynchronously so the logon process can finish quicker.

.PARAMETER RequiresUserInput
    Specifies that the command requires user input.

.PARAMETER RebootBehavior
    Controls how rebooting should be handled.
    Valid values are:
    Never - Never reboot the system.
    Always - Always reboot the system after this command.
    OnRequest - Reboot if the command returns with specific exit codes (1, 2)

.PARAMETER Command
    Specifies the command line to run.

.PARAMETER Description
    Specifies a description for the command.

.PARAMETER RunAsCredential
    Specifies alternative credentials that the command should run as.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Add-UnattendCommand
{
    [CmdletBinding(DefaultParameterSetName = 'Default', PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter(ParameterSetName = 'Default')]
        [ValidateSet('windowsPE', 'specialize', 'auditUser')]
        [string]
        $Pass = 'specialize',

        [Parameter(Mandatory, ParameterSetName = 'FirstLogon')]
        [switch]
        $FirstLogonCommand,

        [Parameter(Mandatory, ParameterSetName = 'LogonPersistent')]
        [switch]
        $LogonCommand,

        [Parameter(ParameterSetName = 'Default')]
        [switch]
        $Async,

        [Parameter(ParameterSetName = 'FirstLogon')]
        [Parameter(ParameterSetName = 'LogonPersistent')]
        [switch]
        $RequiresUserInput,

        [Parameter(ParameterSetName = 'Default')]
        [ValidateSet('Never', 'Always', 'OnRequest')]
        [string]
        $RebootBehavior,

        [Parameter(Mandatory, Position = 0)]
        [string[]]
        $Command,

        [Parameter()]
        [string]
        $Description,

        [Parameter(ParameterSetName = "Default")]
        [pscredential]
        $RunAsCredential
    )
    process
    {
        if ($FirstLogonCommand)
        {
            $Component         = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Shell-Setup', 'oobeSystem')
            $ParentElementName = 'FirstLogonCommands'
            $ElementName       = 'SynchronousCommand'
            $CmdElementName    = 'CommandLine'
        }
        elseif ($LogonCommand)
        {
            $Component         = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Shell-Setup', 'oobeSystem')
            $ParentElementName = 'LogonCommands'
            $ElementName       = 'AsynchronousCommand'
            $CmdElementName    = 'CommandLine'
        }
        else
        {
            $CmdElementName = 'Path'
            if ($Pass -eq "windowsPE")
            {
                $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Setup', 'WindowsPE')
            }
            else
            {
                $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Deployment', $Pass)
            }

            if ($Async)
            {
                $ParentElementName = 'RunAsynchronous'
                $ElementName = 'RunAsynchronousCommand'
            }
            else
            {
                $ParentElementName = 'RunSynchronous'
                $ElementName = 'RunSynchronousCommand'
            }
        }

        $ParentElement = $UnattendBuilder.GetOrCreateChildElement($ParentElementName, $Component)
        $CommandCounter = $ParentElement.ChildNodes.Count + 1

        foreach ($Cmd in $Command)
        {
            $CommandElement = $ParentElement.AppendChild($UnattendBuilder.CreateElement($ElementName, @{action = 'add'}))
            $UnattendBuilder.CreateAndAppendElement($CmdElementName, $Cmd, $CommandElement)
            $UnattendBuilder.CreateAndAppendElement('Order', ($CommandCounter++), $CommandElement)

            switch ($PSBoundParameters.Keys)
            {
                'RequiresUserInput'
                {
                    $UnattendBuilder.CreateAndAppendElement('RequiresUserInput', $RequiresUserInput, $CommandElement)
                    continue
                }
                'RebootBehavior'
                {
                    if ($Async)
                    {
                        Write-Warning "$_ cannot be set for async commands. Skipping this property."
                    }
                    elseif ($Pass -eq "windowsPE")
                    {
                        Write-Warning "$_ cannot be set for WinPE commands. Skipping this property."
                    }
                    else
                    {
                        $UnattendBuilder.CreateAndAppendElement('WillReboot', $RebootBehavior, $CommandElement)
                    }
                    continue
                }
                'Description'
                {
                    $UnattendBuilder.CreateAndAppendElement('Description', $Description, $CommandElement)
                    continue
                }
                'RunAsCredential'
                {
                    $UnattendBuilder.AddCredentialToElement($RunAsCredential, $CommandElement)
                    continue
                }
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Adds disk partitioning related settings to the unattend file.

.DESCRIPTION
    Adds disk partitioning related settings to the unattend file.
    You can either use one of the predefined templates that handle all the partitioning, or run this command multiple times to add all the custom partitions you need.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Template
    Specifies the template to use.
    BIOS will create 3 partitions (System (100MB), Recovery (620MB), Windows (Rest of disk))
    UEFI will create 4 partitions (System (100MB), MSR (16MB), Recovery (620MB), Windows (Rest of disk))

.PARAMETER DontWipeDisk
    Specifies that the disk should not be wiped.

.PARAMETER DiskNumber
    Specifies which disk to target.

.PARAMETER SizeMB
    Specifies how big the partition should be.

.PARAMETER UseRemainingSpace
    Specifies that it should use the remaining space on the disk for this partition.

.PARAMETER PartitionType
    Specifies what kind of partition should be created.

.PARAMETER Active
    Specifies that the partition should be marked "Active" (this is needed for the System partition on BIOS layouts)

.PARAMETER Filesystem
    Specifies the filesystem for this partition.

.PARAMETER VolumeLabel
    Specifies a custom label for this partition.

.PARAMETER DriveLetter
    Assigns a driveletter to this partition.

.PARAMETER PartitionTypeID
    Specifies a custom partition ID to be set. This is rarely needed.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Add-UnattendDiskPartition
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter(Mandatory, ParameterSetName = "Predefined")]
        [ValidateSet("BIOS", "UEFI")]
        [string]
        $Template,

        [Parameter()]
        [switch]
        $DontWipeDisk,

        [Parameter(Mandatory)]
        [uint32]
        $DiskNumber,

        [Parameter(Mandatory, ParameterSetName = "CustomSize")]
        [uint32]
        $SizeMB,

        [Parameter(Mandatory, ParameterSetName = "CustomExtend")]
        [switch]
        $UseRemainingSpace,

        [Parameter(ParameterSetName = "CustomSize")]
        [Parameter(ParameterSetName = "CustomExtend")]
        [ValidateSet('Primary', 'EFI', 'MSR', 'Recovery', 'RecoveryBIOS')]
        [string]
        $PartitionType = 'Primary',

        [Parameter(ParameterSetName = "CustomSize")]
        [Parameter(ParameterSetName = "CustomExtend")]
        [switch]
        $Active,

        [Parameter(ParameterSetName = "CustomSize")]
        [Parameter(ParameterSetName = "CustomExtend")]
        [ValidateSet('FAT32', 'NTFS')]
        [string]
        $Filesystem,

        [Parameter(ParameterSetName = "CustomSize")]
        [Parameter(ParameterSetName = "CustomExtend")]
        [string]
        $VolumeLabel,

        [Parameter(ParameterSetName = "CustomSize")]
        [Parameter(ParameterSetName = "CustomExtend")]
        [char]
        $DriveLetter,

        [Parameter(ParameterSetName = "CustomSize")]
        [Parameter(ParameterSetName = "CustomExtend")]
        [string]
        $PartitionTypeID
    )
    process
    {
        if ($Template)
        {
            $Disk = @{DiskNumber = $DiskNumber}
            $SystemCommonParams = @{
                DontWipeDisk = $DontWipeDisk
                SizeMB       = 100
                VolumeLabel  = "System"
            }
            $RecoveryParams = @{
                SizeMB        = 620
                Filesystem    = "NTFS"
                VolumeLabel   = "Recovery"
            }
            $WindowsParams = @{
                UseRemainingSpace = $true
                FileSystem        = "NTFS"
                PartitionType     = "Primary"
                VolumeLabel       = "Windows"
                DriveLetter       = "C"
            }
            if ($Template -eq 'BIOS')
            {
                $UnattendBuilder |
                    Add-UnattendDiskPartition @Disk @SystemCommonParams -PartitionType Primary -Active -Filesystem NTFS |
                    Add-UnattendDiskPartition @Disk @RecoveryParams -PartitionType RecoveryBIOS |
                    Add-UnattendDiskPartition @Disk @WindowsParams
            }
            else
            {
                $UnattendBuilder |
                    Add-UnattendDiskPartition @Disk @SystemCommonParams -PartitionType EFI -Filesystem FAT32 |
                    Add-UnattendDiskPartition @Disk -SizeMB 16 -PartitionType MSR |
                    Add-UnattendDiskPartition @Disk @RecoveryParams -PartitionType Recovery |
                    Add-UnattendDiskPartition @Disk @WindowsParams
            }
        }
        else
        {
            $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Setup', 'windowsPE')
            $DiskConfig = $UnattendBuilder.GetOrCreateChildElement('DiskConfiguration', $Component)
            $DiskElement = $UnattendBuilder.GetChildElementFromXpath("./Disk/DiskID/text()[. = '$DiskNumber']/../..", $DiskConfig)
            $AddAction = @{action = 'add'}

            if ($null -eq $DiskElement)
            {
                $DiskElement = $DiskConfig.AppendChild($UnattendBuilder.CreateElement("Disk", $AddAction))
                $UnattendBuilder.CreateAndAppendElement("DiskID", $DiskNumber, $DiskElement)
            }

            if ($PSBoundParameters.ContainsKey('DontWipeDisk'))
            {
                $UnattendBuilder.SetElementValue('WillWipeDisk', !$DontWipeDisk, $DiskElement)
            }

            $CreatePartitionsElement = $UnattendBuilder.GetOrCreateChildElement('CreatePartitions', $DiskElement)
            $ModifyPartitionsElement = $UnattendBuilder.GetOrCreateChildElement('ModifyPartitions', $DiskElement)
            $Order = $CreatePartitionsElement.ChildNodes.Count + 1

            $Partition = $CreatePartitionsElement.AppendChild($UnattendBuilder.CreateElement("CreatePartition", $AddAction))
            $UnattendBuilder.CreateAndAppendElement("Order", $Order, $Partition)
            if ($SizeMB)
            {
                $UnattendBuilder.CreateAndAppendElement("Size", $SizeMB, $Partition)
            }
            else
            {
                $UnattendBuilder.CreateAndAppendElement('Extend', $UseRemainingSpace, $Partition)
            }

            if ($PartitionType -eq "Recovery")
            {
                $RealPartitionType = "Primary"
                $RealCustomPartitionID = 'DE94BBA4-06D1-4D40-A16A-BFD50179D6AC'
            }
            elseif ($PartitionType -eq "RecoveryBIOS")
            {
                $RealPartitionType = "Primary"
                $RealCustomPartitionID = '0x27'
            }
            else
            {
                $RealPartitionType = $PartitionType
                $RealCustomPartitionID = $PartitionTypeID
            }
            $UnattendBuilder.CreateAndAppendElement('Type', $RealPartitionType, $Partition)

            $ModifyPartition = $ModifyPartitionsElement.AppendChild($UnattendBuilder.CreateElement("ModifyPartition", $AddAction))
            $UnattendBuilder.CreateAndAppendElement("Order", $Order, $ModifyPartition)
            $UnattendBuilder.CreateAndAppendElement("PartitionID", $Order, $ModifyPartition)

            if ($VolumeLabel)
            {
                $UnattendBuilder.CreateAndAppendElement("Label", $VolumeLabel, $ModifyPartition)
            }
            if ($Filesystem)
            {
                $UnattendBuilder.CreateAndAppendElement("Format", $Filesystem, $ModifyPartition)
            }
            if ($RealCustomPartitionID)
            {
                $UnattendBuilder.CreateAndAppendElement("TypeID", $RealCustomPartitionID, $ModifyPartition)
            }
            if ($PSBoundParameters.ContainsKey('Active'))
            {
                $UnattendBuilder.CreateAndAppendElement("Active", $Active, $ModifyPartition)
            }

            $UnattendBuilder
        }
    }
}
<#
.SYNOPSIS
    Configures the paths Windows should use to look for drivers to install during setup.

.DESCRIPTION
    Configures the paths Windows should use to look for drivers to install during setup.
    Any driver files found will be added to the driverstore.
    You can run this command multiple times if you need to specify multiple UNC paths with different credentials.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    The pass that this command should apply to.
    Supported values:
    windowsPE
    offlineServicing (default)
    auditSystem

.PARAMETER Path
    The folder that contains the drivers to install.
    This folder will be checked recursively for drivers that can be installed.
    It can either be local, or a UNC path.

.PARAMETER Credential
    The credential used to access the specified folder, useful if the specified folder is a UNC path.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Add-UnattendDriverPath
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet('windowsPE', 'offlineServicing', 'auditSystem')]
        [string[]]
        $Pass = 'offlineServicing',

        [Parameter(Position = 0)]
        [string[]]
        $Path,

        [Parameter()]
        [pscredential]
        $Credential
    )
    process
    {
        foreach ($PassName in $Pass)
        {
            $Component = if ($PassName -eq 'windowsPE')
            {
                $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-PnpCustomizationsWinPE', $PassName)
            }
            else
            {
                $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-PnpCustomizationsNonWinPE', $PassName)
            }

            $DriverPaths = $UnattendBuilder.GetOrCreateChildElement("DriverPaths", $Component)
            $Counter = $DriverPaths.ChildNodes.Count + 1
            foreach ($Item in $Path)
            {
                $PathElement = $DriverPaths.AppendChild($UnattendBuilder.CreateElement("PathAndCredentials", @{action = "add";keyValue = ($Counter++)}))
                $UnattendBuilder.CreateAndAppendElement("Path", $Item, $PathElement)
                if ($Credential)
                {
                    $UnattendBuilder.AddCredentialToElement($Credential, $PathElement)
                }
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Adds domain accounts to one or more groups.

.DESCRIPTION
    Adds domain accounts to one or more groups.
    Local accounts can be added to groups while creating them with "Add-UnattendAccount".

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass where the account should be added.
    Valid values are:
    offlineServicing
    auditSystem
    oobeSystem (default)

.PARAMETER DomainName
    Specifies the name of the domain where the domain account is located.

.PARAMETER Name
    Specifies the domain user or group name to add to a group.

.PARAMETER SID
    Specifies the SID of the domain user or group to add to a group.

.PARAMETER Group
    Specifies the groups the domain account should be added to.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Add-UnattendGroupMember
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter(ParameterSetName = 'DomainAccount')]
        [ValidateSet('auditSystem', 'oobeSystem')]
        [string]
        $Pass = 'oobeSystem',

        [Parameter(Mandatory, ParameterSetName = 'DomainAccount')]
        [string]
        $DomainName,

        [Parameter(Mandatory, ParameterSetName = 'DomainAccount')]
        [string[]]
        $Name,

        [Parameter(Mandatory, ParameterSetName = 'OfflineDomainAccount')]
        [string[]]
        $SID,

        [Parameter(Mandatory)]
        [string[]]
        $Group
    )
    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'OfflineDomainAccount')
        {
            $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Shell-Setup', 'offlineServicing')
            $UserAccountsElement = $UnattendBuilder.GetOrCreateChildElement('OfflineUserAccounts', $Component)
            $DomainAccountsElement = $UnattendBuilder.GetOrCreateChildElement('OfflineDomainAccounts', $UserAccountsElement)
            foreach ($User in $SID)
            {
                $NewAccount = $DomainAccountsElement.AppendChild($UnattendBuilder.CreateElement('OfflineDomainAccount', @{action = 'add'}))
                $UnattendBuilder.CreateAndAppendElement('SID', $User, $NewAccount)
                $UnattendBuilder.CreateAndAppendElement('Group', $Group -join ';', $NewAccount)
            }

        }
        else
        {
            $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Shell-Setup', $Pass)
            $UserAccountsElement = $UnattendBuilder.GetOrCreateChildElement('UserAccounts', $Component)
            $DomainAccountsElement = $UnattendBuilder.GetOrCreateChildElement('DomainAccounts', $UserAccountsElement)
            $DomainElement = $UnattendBuilder.GetChildElementFromXpath("./DomainAccountList/Domain/text()[. = '$DomainName']/../..", $DomainAccountsElement)
            if ($null -eq $DomainElement)
            {
                $DomainElement = $DomainAccountsElement.AppendChild($UnattendBuilder.CreateElement("DomainAccountList", @{action = 'add'}))
                $UnattendBuilder.CreateAndAppendElement("Domain", $DomainName, $DomainElement)
            }
            $NewAccount = $DomainElement.AppendChild($UnattendBuilder.CreateElement('DomainAccount', @{action = 'add'}))
            $UnattendBuilder.CreateAndAppendElement('Name', $Name, $NewAccount)
            $UnattendBuilder.CreateAndAppendElement('Group', $Group -join ';', $NewAccount)
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Adds image source/destination details to the unattend file.

.DESCRIPTION
    This command adds image source and destination details to the unattend file.
    This can be used to automate the selection of an OS installation image, as well as one or more data images.
    When selecting a source image, you can use the image index, name or description.
    If you specify multiple sources, the XML file will be invalid.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER SourceImagePath
    The path to the the install/data image file, including the extension (.Wim or .Esd)

.PARAMETER SourceImageIndex
    The index of the image to be applied, indexes start at 1.
    This should not be used together with "SourceImageName" nor "SourceImageDescription".
    The index for a particular image. Can be viewed with the command: Get-WindowsImage

.PARAMETER SourceImageName
    The name of the image to be applied.
    This should not be used together with "SourceImageIndex" nor "SourceImageDescription".
    The name for a particular image.

.PARAMETER SourceImageDescription
    The description of the image to be applied.
    This should not be used together with "SourceImageIndex" nor "SourceImageName".
    The description for a particular image can be viewed with the command: Get-WindowsImage

.PARAMETER SourceImageGroup
    The image group on the WDS server that contains the image to be installed.

.PARAMETER DestinationDiskID
    The disk number where the image should be applied, typically 0.

.PARAMETER DestinationPartitionID
    The ID of the partition where the image should be applied.

.PARAMETER Credential
    The credential used to access the image source location (if on a fileshare) or the credential used to log on to the WDS server.

.PARAMETER WDS
    Specifies that the image source is WDS (Windows Deployment Services).

.PARAMETER DataImage
    Specifies that the image source is a data image.
    Multiple data images can be applied on top of the OS install image to add additional files.
    To apply multiple data images, run this command multiple times.

.PARAMETER Compact
    Specifies that the OS image should be compacted when installed to the disk.
    Compacting the OS will make it take up less space, but performance can be slightly decreased.

.PARAMETER InstallToAvailablePartition
    When set, the installer will find the first available partition with enough space for the OS, and install it there.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Add-UnattendImage
{
    [CmdletBinding(DefaultParameterSetName = "Standard", PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [string]
        $SourceImagePath,

        [Parameter(ParameterSetName = "Standard")]
        [Parameter(ParameterSetName = "DataImage")]
        [uint32]
        $SourceImageIndex,

        [Parameter()]
        [string]
        $SourceImageName,

        [Parameter(ParameterSetName = "Standard")]
        [Parameter(ParameterSetName = "DataImage")]
        [string]
        $SourceImageDescription,

        [Parameter(ParameterSetName = "WDS")]
        [string]
        $SourceImageGroup,

        [Parameter()]
        [uint32]
        $DestinationDiskID,

        [Parameter()]
        [uint32]
        $DestinationPartitionID,

        [Parameter()]
        [pscredential]
        $Credential,

        [Parameter(Mandatory, ParameterSetName = "WDS")]
        [switch]
        $WDS,

        [Parameter(Mandatory, ParameterSetName = "DataImage")]
        [switch]
        $DataImage,

        [Parameter(ParameterSetName = "Standard")]
        [switch]
        $Compact,

        [Parameter(ParameterSetName = "Standard")]
        [switch]
        $InstallToAvailablePartition
    )
    process
    {
        $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Setup', 'windowsPE')

        if ($WDS)
        {
            $SubComponent = $UnattendBuilder.GetOrCreateChildElement('WindowsDeploymentServices', $Component)
            if ($SourceImagePath -or $SourceImageGroup -or $SourceImageName -or $DestinationDiskID -or $DestinationPartitionID)
            {
                $ImageSelection = $SubComponent.AppendChild($UnattendBuilder.CreateElement('ImageSelection'))
                switch ($PSBoundParameters.Keys)
                {
                    'SourceImagePath'
                    {
                        $InstallImage = $UnattendBuilder.GetOrCreateChildElement('InstallImage', $ImageSelection)
                        $UnattendBuilder.CreateAndAppendElement('Filename', $SourceImagePath, $InstallImage)
                        continue
                    }
                    'SourceImageGroup'
                    {
                        $InstallImage = $UnattendBuilder.GetOrCreateChildElement('InstallImage', $ImageSelection)
                        $UnattendBuilder.CreateAndAppendElement('ImageGroup', $SourceImageGroup, $InstallImage)
                        continue
                    }
                    'SourceImageName'
                    {
                        $InstallImage = $UnattendBuilder.GetOrCreateChildElement('InstallImage', $ImageSelection)
                        $UnattendBuilder.CreateAndAppendElement('ImageName', $SourceImageName, $InstallImage)
                        continue
                    }
                    'DestinationDiskID'
                    {
                        $InstallTo = $UnattendBuilder.GetOrCreateChildElement('InstallTo', $ImageSelection)
                        $UnattendBuilder.CreateAndAppendElement('DiskID', $DestinationDiskID, $InstallImage)
                        continue
                    }
                    'DestinationPartitionID'
                    {
                        $InstallTo = $UnattendBuilder.GetOrCreateChildElement('InstallTo', $ImageSelection)
                        $UnattendBuilder.CreateAndAppendElement('PartitionID', $DestinationPartitionID, $InstallImage)
                        continue
                    }
                }
            }
            if ($Credential)
            {
                $Login = $SubComponent.AppendChild($UnattendBuilder.CreateElement('Login'))
                $UnattendBuilder.AddCredentialToElement($Credential, $Login)
            }
        }
        else
        {
            $SubComponent = $UnattendBuilder.GetOrCreateChildElement('ImageInstall', $Component)
            if ($DataImage)
            {
                $ImageElement = $SubComponent.AppendChild($UnattendBuilder.CreateElement("DataImage", @{action = 'add'}))
                $UnattendBuilder.CreateAndAppendElement("Order", $SubComponent.ChildNodes.Count, $ImageElement)
            }
            else
            {
                $ImageElement = $UnattendBuilder.GetOrCreateChildElement('OSImage', $SubComponent)
                if ($PSBoundParameters.ContainsKey('Compact'))
                {
                    $UnattendBuilder.CreateAndAppendElement('Compact', $Compact, $ImageElement)
                }
                if ($PSBoundParameters.ContainsKey('InstallToAvailablePartition'))
                {
                    $UnattendBuilder.CreateAndAppendElement('InstallToAvailablePartition', $InstallToAvailablePartition, $ImageElement)
                }
            }

            if ($SourceImagePath -or $SourceImageIndex -or $SourceImageName -or $SourceImageDescription -or $Credential)
            {
                $InstallFrom = $ImageElement.AppendChild($UnattendBuilder.CreateElement('InstallFrom'))
                switch ($PSBoundParameters.Keys)
                {
                    'SourceImagePath'
                    {
                        $UnattendBuilder.CreateAndAppendElement('Path', $SourceImagePath, $InstallFrom)
                        continue
                    }
                    'SourceImageIndex'
                    {
                        $MetaData = $InstallFrom.AppendChild($UnattendBuilder.CreateElement('MetaData', @{action = 'add'}))
                        $UnattendBuilder.CreateAndAppendElement('Key', '/IMAGE/INDEX', $MetaData)
                        $UnattendBuilder.CreateAndAppendElement('Value', $SourceImageIndex, $MetaData)
                        continue
                    }
                    'SourceImageName'
                    {
                        $MetaData = $InstallFrom.AppendChild($UnattendBuilder.CreateElement('MetaData', @{action = 'add'}))
                        $UnattendBuilder.CreateAndAppendElement('Key', '/IMAGE/NAME', $MetaData)
                        $UnattendBuilder.CreateAndAppendElement('Value', $SourceImageName, $MetaData)
                        continue
                    }
                    'SourceImageDescription'
                    {
                        $MetaData = $InstallFrom.AppendChild($UnattendBuilder.CreateElement('MetaData', @{action = 'add'}))
                        $UnattendBuilder.CreateAndAppendElement('Key', '/IMAGE/DESCRIPTION', $MetaData)
                        $UnattendBuilder.CreateAndAppendElement('Value', $SourceImageDescription, $MetaData)
                        continue
                    }
                    'Credential'
                    {
                        $UnattendBuilder.AddCredentialToElement($Credential, $InstallFrom)
                    }
                }
            }
            if ($DestinationDiskID)
            {
                $InstallTo = $UnattendBuilder.GetOrCreateChildElement('InstallTo', $ImageElement)
                $UnattendBuilder.CreateAndAppendElement('DiskID', $DestinationDiskID, $InstallTo)
            }
            if ($DestinationPartitionID)
            {
                $InstallTo = $UnattendBuilder.GetOrCreateChildElement('InstallTo', $ImageElement)
                $UnattendBuilder.CreateAndAppendElement('PartitionID', $DestinationPartitionID, $InstallTo)
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures DNS settings that are interface specific.

.DESCRIPTION
    Configures DNS settings that are interface specific.
    Run this command multiple times with different interface identifiers to add settings for multiple interfaces.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass this command should apply to.
    Valid values are:
    windowsPE
    specialize (Default)

.PARAMETER InterfaceIdentifier
    Specifies the interface that these settings should apply to.
    Can either be the friendly name like: "Ethernet" or the Mac address, like: "AA-AA-AA-AA-AA-AA"

.PARAMETER InterfaceDomain
    Specifies the DNS domain that should be used for connections out from the specified interface.
    If a global DNS domain has been set then that takes priority, and if nothing is found then the interface domain is used.

.PARAMETER EnableDynamicUpdate
    Specifies that A and PTR resource records are registered dynamically.

.PARAMETER DisableAdapterDomainRegistration
    Specifies that A and PTR resource records are not registered for this adapter.

.PARAMETER DnsServer
    Specifies a list of IP addresses to use when searching for the DNS server on the network.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Add-UnattendInterfaceDnsConfig
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet('windowsPE', 'specialize')]
        [string[]]
        $Pass = 'specialize',

        [Parameter(Mandatory)]
        [string]
        $InterfaceIdentifier,

        [Parameter()]
        [string]
        $InterfaceDomain,

        [Parameter()]
        [switch]
        $EnableDynamicUpdate,

        [Parameter()]
        [switch]
        $DisableAdapterDomainRegistration,

        [Parameter()]
        [ipaddress[]]
        $DnsServer
    )
    process
    {
        foreach ($PassName in $Pass)
        {
            $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-DNS-Client', $PassName)
            $InterfacesElement = $UnattendBuilder.GetOrCreateChildElement("Interfaces", $Component)
            $Interface = $InterfacesElement.AppendChild($UnattendBuilder.CreateElement('Interface', @{action = 'add'}))

            switch ($PSBoundParameters.Keys)
            {
                'EnableDynamicUpdate'
                {
                    $UnattendBuilder.CreateAndAppendElement('DisableDynamicUpdate', !$EnableDynamicUpdate, $Interface)
                    continue
                }
                'InterfaceDomain'
                {
                    $UnattendBuilder.CreateAndAppendElement('DNSDomain', $InterfaceDomain, $Interface)
                    continue
                }
                'DisableAdapterDomainRegistration'
                {
                    $UnattendBuilder.CreateAndAppendElement('EnableAdapterDomainNameRegistration', !$DisableAdapterDomainRegistration, $Interface)
                    continue
                }
                'DnsServer'
                {
                    $DnsElement = $Interface.AppendChild($UnattendBuilder.CreateElement('DNSServerSearchOrder'))
                    $UnattendBuilder.AddSimpleListToElement($DnsServer, "IpAddress", $DnsElement)
                }
            }

            $UnattendBuilder.CreateAndAppendElement('Identifier', $InterfaceIdentifier, $Interface)
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures interface specific settings.

.DESCRIPTION
    Configures interface specific settings.
    Run this command multiple times with different interface identifiers to configure multiple interfaces.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass to use.
    Valid values are:
    windowsPE
    specialize (default)

.PARAMETER InterfaceIdentifier
    Specifies the interface that settings should apply to.
    Can either be the friendly name like: "Ethernet" or the Mac address, like: "AA-AA-AA-AA-AA-AA"

.PARAMETER IpAddress
    The ip address to assign to the interface.
    Can be specified with or without the cidr notation.
    If the cidr notation is left out, Windows will use the class based system to guess the right subnet mask.

.PARAMETER DefaultGateway
    Specifies the default gateway the interface should use.

.PARAMETER Routes
    Specifies the custom routes to add to the interface.
    Use a hashtable with the following keys:
    Metric - a number that sets the priority for the route, the lower the number, the higher the priority.
    NextHopAddress - What the route should point to.
    Prefix - Specifies which destination IP addresses this route should apply to.
    For more information, see: https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-tcpip-interfaces-interface-routes-route

.PARAMETER Ipv4InterfaceSettings
    Specifies ipv4 settings for the interface.
    Use a hashtable with the following keys:
    DhcpEnabled - a bool that controls whether or not DHCP is enabled on this interface.
    Metric - a number that sets the priority for the interface, the lower the number, the higher the priority.
    RouterDiscoveryEnabled - Specifies whether the router discovery protocol, which informs hosts of the existence of routers, is enabled.
    For more information, see: https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-tcpip-interfaces-interface-ipv4settings

.PARAMETER Ipv6InterfaceSettings
    Specifies ipv6 settings for the interface.
    Use a hashtable with the following keys:
    DhcpEnabled - a bool that controls whether or not DHCP is enabled on this interface.
    Metric - a number that sets the priority for the interface, the lower the number, the higher the priority.
    RouterDiscoveryEnabled - Specifies whether the router discovery protocol, which informs hosts of the existence of routers, is enabled.
    For more information, see: https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-tcpip-interfaces-interface-ipv6settings

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Add-UnattendInterfaceIpConfig
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet('windowsPE', 'specialize')]
        [string[]]
        $Pass = 'specialize',

        [Parameter(Mandatory)]
        [string]
        $InterfaceIdentifier,

        [Parameter()]
        [string[]]
        $IpAddress,

        [Parameter()]
        [ipaddress]
        $DefaultGateway,

        [Parameter()]
        [hashtable[]]
        $Routes,

        [Parameter()]
        [hashtable]
        $Ipv4InterfaceSettings,

        [Parameter()]
        [hashtable]
        $Ipv6InterfaceSettings
    )
    begin
    {
        if ($DefaultGateway)
        {
            $Routes += @{
                NextHopAddress = $DefaultGateway.ToString()
                Metric = 0
                Prefix = "0.0.0.0/0"
            }
        }
    }

    process
    {
        foreach ($PassName in $Pass)
        {
            $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-TCPIP', $PassName)
            $InterfacesElement = $UnattendBuilder.GetOrCreateChildElement("Interfaces", $Component)
            $Interface = $InterfacesElement.AppendChild($UnattendBuilder.CreateElement("Interface", @{action = 'add'}))

            if ($Ipv4InterfaceSettings)
            {
                $SettingsElement = $Interface.AppendChild($UnattendBuilder.CreateElement('Ipv4Settings'))
                $UnattendBuilder.AddHashtableValuesToElement($Ipv4InterfaceSettings, $SettingsElement)
            }
            if ($Ipv6InterfaceSettings)
            {
                $SettingsElement = $Interface.AppendChild($UnattendBuilder.CreateElement('Ipv6Settings'))
                $UnattendBuilder.AddHashtableValuesToElement($Ipv6InterfaceSettings, $SettingsElement)
            }

            $UnattendBuilder.CreateAndAppendElement('Identifier', $InterfaceIdentifier, $Interface)

            if ($IpAddress)
            {
                $IpElement = $Interface.AppendChild($UnattendBuilder.CreateElement('UnicastIpAddresses'))
                $UnattendBuilder.AddSimpleListToElement($IpAddress, 'IpAddress', $IpElement)
            }

            if ($Routes)
            {
                $RoutesElement = $Interface.AppendChild($UnattendBuilder.CreateElement('Routes'))
                for ($i = 0; $i -lt $Routes.Count; $i++)
                {
                    $RouteItem = $RoutesElement.AppendChild($UnattendBuilder.CreateElement('Route', @{action = 'add'}))
                    $Table = $Routes[$i].Clone()
                    $Table.Add('Identifier', $i)
                    $UnattendBuilder.AddHashtableValuesToElement($Table, $RouteItem)
                }
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Adds local accounts to the machine and optionally adds them to groups.

.DESCRIPTION
    Adds local accounts to the machine and optionally adds them to groups.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass where the account should be added.
    Valid values are:
    offlineServicing
    auditSystem
    oobeSystem (default)

.PARAMETER LocalAdmin
    Specifies that you are setting the local admin password.

.PARAMETER Name
    Specifies the name of the user to create.

.PARAMETER Password
    Specifies the password to set for the local account.
    If a name is not specified then this will set the local admin password.

.PARAMETER DisplayName
    Specifies a displayname for the new local account.

.PARAMETER Group
    Specifies the groups local account should be added to.

.PARAMETER Description
    Specifies a description for the new local account.

.PARAMETER PasswordAsPlainText
    Specifies that the PW should be stored as plaintext in the unattend file.

.PARAMETER SkipPasswordEncoding
    Skips encoding the PW for the unattend file. Useful if you want to add a PW that has already been encoded.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Add-UnattendUser
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet('offlineServicing', 'auditSystem', 'oobeSystem')]
        [string]
        $Pass = 'oobeSystem',

        [Parameter(Mandatory, ParameterSetName = 'LocalAdmin')]
        [switch]
        $LocalAdmin,

        [Parameter(Mandatory, ParameterSetName = 'LocalUser')]
        [string[]]
        $Name,

        [Parameter(ParameterSetName = 'LocalUser')]
        [Parameter(Mandatory, ParameterSetName = 'LocalAdmin')]
        [AllowEmptyString()]
        [string]
        $Password,

        [Parameter(ParameterSetName = 'LocalUser')]
        [string]
        $DisplayName,

        [Parameter(ParameterSetName = 'LocalUser')]
        [string[]]
        $Group,

        [Parameter(ParameterSetName = 'LocalUser')]
        [string]
        $Description,

        [Parameter()]
        [switch]
        $PasswordAsPlainText,

        [Parameter()]
        [switch]
        $SkipPasswordEncoding
    )
    process
    {
        $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Shell-Setup', $Pass)
        if ($LocalAdmin)
        {
            if ($Pass -eq 'offlineServicing')
            {
                $UserAccounts = $UnattendBuilder.GetOrCreateChildElement('OfflineUserAccounts', $Component)
                $AdminElement = $UnattendBuilder.GetOrCreateChildElement('OfflineAdministratorPassword', $UserAccounts)
            }
            else
            {
                $UserAccounts = $UnattendBuilder.GetOrCreateChildElement('UserAccounts', $Component)
                $AdminElement = $UnattendBuilder.GetOrCreateChildElement('AdministratorPassword', $UserAccounts)
            }

            $PW = if ($PasswordAsPlainText -or $SkipPasswordEncoding -or [string]::IsNullOrEmpty($Password))
            {
                $Password
            }
            else
            {
                if ($Pass -eq 'offlineServicing')
                {
                    EncodeUnattendPassword -Password $Password -Kind OfflineLocalAdmin
                }
                else
                {
                    EncodeUnattendPassword -Password $Password -Kind LocalAdmin
                }
            }

            $UnattendBuilder.SetElementValue('Value', $PW, $AdminElement)
            $UnattendBuilder.SetElementValue('PlainText', $PasswordAsPlainText, $AdminElement)
        }
        else
        {
            if ($Pass -eq 'offlineServicing')
            {
                $UserAccounts = $UnattendBuilder.GetOrCreateChildElement('OfflineUserAccounts', $Component)
                $LocalAccounts = $UnattendBuilder.GetOrCreateChildElement("OfflineLocalAccounts", $UserAccounts)
            }
            else
            {
                $UserAccounts = $UnattendBuilder.GetOrCreateChildElement('UserAccounts', $Component)
                $LocalAccounts = $UnattendBuilder.GetOrCreateChildElement("LocalAccounts", $UserAccounts)
            }

            foreach ($UserName in $Name)
            {
                $NewAccount = $LocalAccounts.AppendChild($UnattendBuilder.CreateElement('LocalAccount', @{action = 'add'}))
                switch ($PSBoundParameters.Keys)
                {
                    'Description'
                    {
                        $UnattendBuilder.CreateAndAppendElement('Description', $Description, $NewAccount)
                        continue
                    }
                    'DisplayName'
                    {
                        $UnattendBuilder.CreateAndAppendElement('DisplayName', $DisplayName, $NewAccount)
                        continue
                    }
                    'Group'
                    {
                        $UnattendBuilder.CreateAndAppendElement('Group', $Group -join ';', $NewAccount)
                        continue
                    }
                    'Name'
                    {
                        $UnattendBuilder.CreateAndAppendElement('Name', $UserName, $NewAccount)
                        continue
                    }
                    'Password'
                    {
                        $PasswordElement = $NewAccount.AppendChild($UnattendBuilder.CreateElement('Password'))
                        $PW = if ($PasswordAsPlainText -or $SkipPasswordEncoding -or [string]::IsNullOrEmpty($Password))
                        {
                            $Password
                        }
                        else
                        {
                            EncodeUnattendPassword -Password $Password -Kind UserAccount
                        }
                        $UnattendBuilder.CreateAndAppendElement('Value', $PW, $PasswordElement)
                        $UnattendBuilder.CreateAndAppendElement('PlainText', $PasswordAsPlainText, $PasswordElement)
                        continue
                    }
                }
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Creates an unattend file from the provided UnattendBuilder object.

.DESCRIPTION
    Creates an unattend file from the provided UnattendBuilder object.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that contains all the file contents.
    Create one with the command: New-UnattendBuilder

.PARAMETER FilePath
    The full path to the file that should be created.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder
#>
function Export-UnattendFile
{
    [CmdletBinding(PositionalBinding = $false)]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter(Mandatory, Position = 0)]
        [string]
        $FilePath
    )
    process
    {
        $ParentPath = Split-Path -LiteralPath $FilePath -ErrorAction Stop
        $ResolvedPath = Resolve-Path -LiteralPath $ParentPath -ErrorAction Stop
        if ($ResolvedPath.Provider.Name -ne 'FileSystem')
        {
            $PSCmdlet.ThrowTerminatingError(
                [ErrorRecord]::new(
                    [ArgumentException]::new("The provided path is invalid. Please provide a filesystem path.", "FilePath"),
                    "NotAFilesystemPath",
                    [ErrorCategory]::InvalidArgument,
                    $FilePath
                )
            )
        }

        $FileName = Split-Path -Path $FilePath -Leaf -ErrorAction Stop
        $OutputPath = Join-Path -Path $ResolvedPath.ProviderPath -ChildPath $FileName
        $UnattendBuilder.ToXml().Save($OutputPath)
    }
}
<#
.SYNOPSIS
    Creates a new unattendbuilder object that can be used to build an unattend file.

.DESCRIPTION
    Creates a new unattendbuilder object that can be used to build an unattend file.
    This command includes convenience parameters that allow you to get started with a new unattend file that includes the basics
    but you can also start from a clean slate.
    Another option is to import an existing file/XML document as a baseline, and add additional settings to it.

.PARAMETER SourceFile
    Specifies the path to an XML file that contains an existing unattend file to import.

.PARAMETER SourceDocument
    Specifies the XmlDocument object that contains an existing unattend file that should be modified.

.PARAMETER UiLanguage
    Specifies the display language to set in WinPE and Windows.

.PARAMETER SystemLocale
    Specifies the system locale to set in WinPE and Windows.

.PARAMETER InputLocale
    Specifies the keyboard layout to set in WinPE and Windows.

.PARAMETER ProductKey
    Specifies the product key to add the unattend file.

.PARAMETER DiskTemplate
    Specifies the predefined disk template to use during the installation

.PARAMETER SkipOOBE
    Skips all the OOBE windows.

.PARAMETER LocalAdminPassword
    Sets the local admin password.

.PARAMETER LocalUserToAdd
    Adds a local user as admin.

.PARAMETER LocalUserPassword
    Sets a password for the specified user.

.OUTPUTS
    [UnattendBuilder]
#>
function New-UnattendBuilder
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]
        $SourceFile,

        [Parameter(ValueFromPipeline)]
        [xml]
        $SourceDocument,

        [Parameter()]
        [cultureinfo]
        $UiLanguage,

        [Parameter()]
        [cultureinfo]
        $SystemLocale,

        [Parameter()]
        [cultureinfo[]]
        $InputLocale,

        [Parameter()]
        [string]
        $ProductKey,

        [Parameter()]
        [ValidateSet('BIOS', 'UEFI')]
        [string]
        $DiskTemplate,

        [Parameter()]
        [switch]
        $SkipOOBE,

        [Parameter()]
        [string]
        $LocalAdminPassword,

        [Parameter()]
        [string]
        $LocalUserToAdd,

        [Parameter()]
        [string]
        $LocalUserPassword
    )
    process
    {
        $Builder = try
        {
            if ($SourceFile)
            {
                $ResolvedPath = Resolve-Path -LiteralPath $SourceFile -ErrorAction Stop
                [UnattendBuilder]::new($ResolvedPath.ProviderPath)
            }
            elseif ($SourceDocument)
            {
                [UnattendBuilder]::new($SourceDocument)
            }
            else
            {
                [UnattendBuilder]::new()
            }
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        $LanguageParams = @{}
        switch ($PSBoundParameters.Keys)
        {
            'UiLanguage'
            {
                $LanguageParams.Add('UiLanguage', $UiLanguage)
                continue
            }
            'SystemLocale'
            {
                $LanguageParams.Add('SystemLocale', $SystemLocale)
                continue
            }
            'InputLocale'
            {
                $LanguageParams.Add('InputLocale', $InputLocale)
                continue
            }
            'ProductKey'
            {
                $null = $Builder | Set-UnattendProductKey -ProductKey $ProductKey
                continue
            }
            'DiskTemplate'
            {
                $null = $Builder | Add-UnattendDiskPartition -Template $DiskTemplate -DiskNumber 0 | Add-UnattendImage -InstallToAvailablePartition
                continue
            }
            'SkipOOBE'
            {
                $null = $Builder | Set-UnattendWindowsSetupSetting -AcceptEula | Set-UnattendOobeSetting -HideEula -HideLocalAccount -HideOem -HideOnlineAccount -HideNetworkSetup -UseExpressSettings:$false
                continue
            }
            'LocalAdminPassword'
            {
                $null = $Builder | Add-UnattendUser -LocalAdmin -Password $LocalAdminPassword
                continue
            }
            'LocalUserToAdd'
            {
                $UserParams = @{Name = $LocalUserToAdd}
                if ($LocalUserPassword)
                {
                    $UserParams.Add("Password", $LocalUserPassword)
                }
                $null = $Builder | Add-UnattendUser @UserParams -Group Administrators
                continue
            }
        }

        if ($LanguageParams.Count -gt 0)
        {
            $null = $Builder | Set-UnattendLanguageSetting -Pass windowsPE,specialize,oobeSystem @LanguageParams
        }

        $Builder
    }
}
<#
.SYNOPSIS
    Configures audio settings.

.DESCRIPTION
    Configures audio settings.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER DisableSpatialOnComboEndpoints
    Not documented.

.PARAMETER DisableCaptureMonitor
    Prevents users from playing audio by connecting devices (music players) to the "Audio in" port.

.PARAMETER DisableVolumeControlOnLockscreen
    Disables volume adjustment from the lock screen.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendAudioSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [switch]
        $DisableSpatialOnComboEndpoints,

        [Parameter()]
        [switch]
        $DisableCaptureMonitor,

        [Parameter()]
        [switch]
        $DisableVolumeControlOnLockscreen
    )
    process
    {
        $Pass = 'specialize'

        switch ($PSBoundParameters.Keys)
        {
            'DisableSpatialOnComboEndpoints'
            {
                $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Audio-AudioCore', $Pass)
                $UnattendBuilder.SetElementValue('DisableSpatialOnComboEndpoints', $DisableSpatialOnComboEndpoints, $Component)
                continue
            }
            'DisableCaptureMonitor'
            {
                $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Audio-AudioCore', $Pass)
                $UnattendBuilder.SetElementValue('EnableCaptureMonitor', !$DisableCaptureMonitor, $Component)
                continue
            }
            'DisableVolumeControlOnLockscreen'
            {
                $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Audio-VolumeControl', $Pass)
                $UnattendBuilder.SetElementValue('EnableVolumeControlWhileLocked', !$DisableVolumeControlOnLockscreen, $Component)
                continue
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures the autologon user details, and whether or not autologon is enabled.

.DESCRIPTION
    Configures the autologon user details, and whether or not autologon is enabled.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass this command should apply to.
    Valid values are:
    specialize
    auditSystem
    oobeSystem (default)

.PARAMETER UserDomain
    Specifies the domain that the autologon user is a member of.

.PARAMETER UserName
    Specifies the username of the autologon user.

.PARAMETER Password
    Specifies the password of the autologon user.

.PARAMETER PasswordAsPlainText
    Specifies that the password should be stored as plaintext in the unattend file.

.PARAMETER SkipPasswordEncoding
    Specifies that this command should not encode the password, useful if you want to add a password that has already been encoded.

.PARAMETER DisableAutoLogon
    Disables autologon.

.PARAMETER LogonCount
    Specifies how many times the user should log in automatically.
    This is useful when running multiple setup scripts that require reboots.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendAutoLogon
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet("specialize", 'auditSystem', 'oobeSystem')]
        [string[]]
        $Pass = "oobeSystem",

        [Parameter()]
        [string]
        $UserDomain,

        [Parameter(Mandatory)]
        [string]
        $UserName,

        [Parameter()]
        [string]
        $Password,

        [Parameter()]
        [switch]
        $PasswordAsPlainText,

        [Parameter()]
        [switch]
        $SkipPasswordEncoding,

        [Parameter()]
        [switch]
        $DisableAutoLogon,

        [Parameter()]
        [uint32]
        $LogonCount
    )
    process
    {
        foreach ($PassName in $Pass)
        {
            $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Shell-Setup', $PassName)
            $AutoLogon = $UnattendBuilder.GetOrCreateChildElement('AutoLogon', $Component)
            switch ($PSBoundParameters.Keys)
            {
                'UserDomain'
                {
                    $UnattendBuilder.SetElementValue("Domain", $UserDomain, $AutoLogon)
                    continue
                }
                'UserName'
                {
                    $UnattendBuilder.SetElementValue("Username", $UserName, $AutoLogon)
                    continue
                }
                'Password'
                {
                    $PasswordElement = $UnattendBuilder.GetOrCreateChildElement('Password', $AutoLogon)
                    $PW = if ($PasswordAsPlainText -or $SkipPasswordEncoding)
                    {
                        $Password
                    }
                    else
                    {
                        EncodeUnattendPassword -Password $Password -Kind UserAccount
                    }
                    $UnattendBuilder.SetElementValue('Value', $PW, $PasswordElement)
                    $UnattendBuilder.SetElementValue('PlainText', $PasswordAsPlainText, $PasswordElement)
                }
                'LogonCount'
                {
                    $UnattendBuilder.SetElementValue("LogonCount", $LogonCount, $AutoLogon)
                    continue
                }
            }

            $UnattendBuilder.SetElementValue("Enabled", !$DisableAutoLogon, $AutoLogon)
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Sets the computer computer name to be set during installation.

.DESCRIPTION
    Sets the computer computer name to be set during installation.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    The pass that this command should apply to.
    Supported values are:
    offlineServicing
    specialize (default)

.PARAMETER ComputerName
    The computer name to set during installation.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendComputerName
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet("offlineServicing", "specialize")]
        [string[]]
        $Pass = "specialize",

        [Parameter(Mandatory, Position = 0)]
        [string]
        $ComputerName
    )
    process
    {
        foreach ($PassName in $Pass)
        {
            $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Shell-Setup', $PassName)
            $UnattendBuilder.SetElementValue('ComputerName', $ComputerName, $Component)
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures global DNS settings.

.DESCRIPTION
    Configures global DNS settings.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass this command should apply to.
    Valid values are:
    windowsPE
    specialize (Default)

.PARAMETER DnsDomain
   Specifies the primary DNS domain to be used for name resolution.
   This will be used for DNS client registrations and DNS client resolution if no suffixes have been configured.

.PARAMETER DisableDomainNameDevolution
     Specifies that the name resolver does not use domain-name devolution.

.PARAMETER DnsSuffixSearchOrder
    Specifies the DNS suffixes to use when attempting to resolve hostnames without a domain.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendDnsSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet('windowsPE', 'specialize')]
        [string[]]
        $Pass = 'specialize',

        [Parameter()]
        [string]
        $DnsDomain,

        [Parameter()]
        [switch]
        $DisableDomainNameDevolution,

        [Parameter()]
        [string[]]
        $DnsSuffixSearchOrder
    )
    process
    {
        foreach ($PassName in $Pass)
        {
            $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-DNS-Client', $PassName)
            switch ($PSBoundParameters.Keys)
            {
                'DnsDomain'
                {
                    $UnattendBuilder.SetElementValue('DNSDomain', $DnsDomain, $Component)
                    continue
                }
                'DisableDomainNameDevolution'
                {
                    $UnattendBuilder.SetElementValue('UseDomainNameDevolution', !$DisableDomainNameDevolution, $Component)
                    continue
                }
                'DnsSuffixSearchOrder'
                {
                    $SuffixElement = $UnattendBuilder.GetOrCreateChildElement('DNSSuffixSearchOrder', $Component)
                    if ($SuffixElement.HasChildNodes)
                    {
                        $SuffixElement.RemoveAll()
                    }
                    $UnattendBuilder.AddSimpleListToElement($DnsSuffixSearchOrder, 'DomainName', $SuffixElement)
                    continue
                }
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures settings related to joining a domain or workgroup.

.DESCRIPTION
    Configures settings related to joining a domain or workgroup.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER OfflinePass
    Specifies that this should happen during the offline pass, otherwise it will happen during the specialization phase.

.PARAMETER UnsecureJoin
    Specifies whether to add the computer to the domain without requiring a unique password.
    UnsecureJoin is performed, by using a null session with a pre-existing account.
    This means there is no authentication to the domain controller when configuring the machine account; it is done anonymously.
    The account must have a well-known password or a specified value for MachinePassword.
    The well-known password is the first 14 characters of the computer name in lower case.

.PARAMETER AccountData
    Specifies the base64 string containing join details that has been generated by djoin.exe

.PARAMETER JoinCredential
    Specifies the credentials to use to join the domain.

.PARAMETER DomainName
    Specifies the name of the domain to join.

.PARAMETER WorkgroupName
    Specifies the workgroup name of the workgroup to join.

.PARAMETER DebugJoin
    Specifies a trigger to run the debugging routine if setup encounters an error code.
    This setting enables you to debug Windows Setup failures.

.PARAMETER DebugJoinError
    Specifies a particular error code that causes DebugJoin to trigger if encountered during Windows Setup.

.PARAMETER TargetOU
    Specifies the target OU to place the computer object in after the domain join.

.PARAMETER MachinePassword
    MachinePassword is used with UnsecureJoin, which is performed by using a null session with a pre-existing account.
    This means there is no authentication to the domain controller when configuring the computer account.
    It is done anonymously.
    The account must have a well-known password or a specified MachinePassword.
    The well-known password is the first 14 characters of the computer name in lowercase.

.PARAMETER TimeoutInMinutes
    Specifies how long Windows will wait until it gives up joining the domain.
    Valid values are between 5 and 60 minutes.
    Default is 15 minutes.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendDomainJoinInfo
{
    [CmdletBinding(DefaultParameterSetName = 'Workgroup', PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter(Mandatory, ParameterSetName = 'DomainJoinOfflinePass')]
        [switch]
        $OfflinePass,

        [Parameter(Mandatory, ParameterSetName = 'UnsecureDomainJoin')]
        [switch]
        $UnsecureJoin,

        [Parameter(Mandatory, ParameterSetName = 'DomainJoinOfflinePass')]
        [Parameter(Mandatory, ParameterSetName = 'DomainJoinPreprovisioned')]
        [string]
        $AccountData,

        [Parameter(Mandatory, ParameterSetName = 'DomainJoin')]
        [pscredential]
        $JoinCredential,

        [Parameter(Mandatory, ParameterSetName = 'DomainJoinPreprovisioned')]
        [Parameter(Mandatory, ParameterSetName = 'DomainJoin')]
        [Parameter(Mandatory, ParameterSetName = 'UnsecureDomainJoin')]
        [string]
        $DomainName,

        [Parameter(ParameterSetName = 'Workgroup')]
        [string]
        $WorkgroupName,

        [Parameter(ParameterSetName = 'DomainJoinPreprovisioned')]
        [Parameter(ParameterSetName = 'DomainJoin')]
        [Parameter(ParameterSetName = 'UnsecureDomainJoin')]
        [switch]
        $DebugJoin,

        [Parameter(ParameterSetName = 'DomainJoinPreprovisioned')]
        [Parameter(ParameterSetName = 'DomainJoin')]
        [Parameter(ParameterSetName = 'UnsecureDomainJoin')]
        [string]
        $DebugJoinError,

        [Parameter(ParameterSetName = 'DomainJoinPreprovisioned')]
        [Parameter(ParameterSetName = 'DomainJoin')]
        [Parameter(ParameterSetName = 'UnsecureDomainJoin')]
        [string]
        $TargetOU,

        [Parameter(Mandatory, ParameterSetName = 'UnsecureDomainJoin')]
        [string]
        $MachinePassword,

        [Parameter(ParameterSetName = 'DomainJoinPreprovisioned')]
        [Parameter(ParameterSetName = 'DomainJoin')]
        [Parameter(ParameterSetName = 'UnsecureDomainJoin')]
        [ValidateRange(5, 60)]
        [int]
        $TimeoutInMinutes
    )
    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'DomainJoinOfflinePass')
        {
            $PassName = 'offlineServicing'
            $ChildElementName = 'OfflineIdentification'
        }
        else
        {
            $PassName = 'specialize'
            $ChildElementName = 'Identification'
        }

        $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-UnattendedJoin', $PassName)
        $IdentificationElement = $UnattendBuilder.GetOrCreateChildElement($ChildElementName, $Component)

        switch ($PSBoundParameters.Keys)
        {
            'UnsecureJoin'
            {
                $UnattendBuilder.SetElementValue('UnsecureJoin', $UnsecureJoin, $IdentificationElement)
                continue
            }
            'AccountData'
            {
                $ProvisioningElement = $UnattendBuilder.GetOrCreateChildElement('Provisioning', $IdentificationElement)
                $UnattendBuilder.SetElementValue('AccountData', $AccountData, $ProvisioningElement)
                continue
            }
            'JoinCredential'
            {
                $UnattendBuilder.SetCredentialOnElement($JoinCredential, $IdentificationElement)
                continue
            }
            'DomainName'
            {
                $UnattendBuilder.SetElementValue('JoinDomain', $DomainName, $IdentificationElement)
                continue
            }
            'WorkgroupName'
            {
                $UnattendBuilder.SetElementValue('JoinWorkgroup', $WorkgroupName, $IdentificationElement)
                continue
            }
            'DebugJoin'
            {
                $UnattendBuilder.SetElementValue('DebugJoin', $DebugJoin, $IdentificationElement)
                continue
            }
            'DebugJoinError'
            {
                $UnattendBuilder.SetElementValue('DebugJoinOnlyOnThisError', $DebugJoinError, $IdentificationElement)
                continue
            }
            'TargetOU'
            {
                $UnattendBuilder.SetElementValue('MachineObjectOU', $TargetOU, $IdentificationElement)
                continue
            }
            'MachinePassword'
            {
                $UnattendBuilder.SetElementValue('MachinePassword', $MachinePassword, $IdentificationElement)
                continue
            }
            'TimeoutInMinutes'
            {
                $UnattendBuilder.SetElementValue('TimeoutPeriodInMinutes', $TimeoutInMinutes, $IdentificationElement)
                continue
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures firewall settings.

.DESCRIPTION
    Configures firewall settings, these firewall settings apply to the installed OS, not WinPE.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER DisableStatefulFTP
    Disables the FTP inspection engine.
    On server editions this is turned on by default, and setting this switch will disable it.
    On client editions this is turned off by default, but can be enabled by setting this switch to false: -DisableStatefulFTP:$false

.PARAMETER DisableStatefulPPTP
    Disables the point to point tunneling inspection.
    On server editions this is turned on by default, and setting this switch will disable it.
    On client editions this is turned off by default, but can be enabled by setting this switch to false: -DisableStatefulPPTP:$false

.PARAMETER FirewallProfile
    Specifies the firewall profile the profile specific settings should apply to.

.PARAMETER DisableFirewall
    Disables the specified firewall profile.

.PARAMETER DisableNotifications
    Disables notifications about programs being blocked.

.PARAMETER LogDroppedPackets
    Enables logging of dropped packets.

.PARAMETER LogSuccessfulConnections
    Enables logging of allowed connections, by default only dropped connections are logged.

.PARAMETER LogFilePath
    Specifies the filepath of the logfile for this profile.

.PARAMETER LogFileSizeKB
    Specifies how big the logfile can be.

.PARAMETER EnabledFirewallGroups
    Specifies the firewall groups to enable.
    Firewall group names can be found with this command: Get-NetFirewallRule | select Name,DisplayName,Group

.PARAMETER DisabledFirewallGroups
    Specifies the firewall groups to disable.
    Firewall group names can be found with this command: Get-NetFirewallRule | select Name,DisplayName,Group

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendFirewallSetting
{
    [CmdletBinding(DefaultParameterSetName = 'GlobalSettings', PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter(ParameterSetName = "GlobalSettings")]
        [Parameter(ParameterSetName = "ProfileSpecific")]
        [switch]
        $DisableStatefulFTP,

        [Parameter(ParameterSetName = "GlobalSettings")]
        [Parameter(ParameterSetName = "ProfileSpecific")]
        [switch]
        $DisableStatefulPPTP,

        [Parameter(Mandatory, ParameterSetName = "ProfileSpecific")]
        [ValidateSet("Domain", 'Private', 'Public', 'All')]
        [string]
        $FirewallProfile,

        [Parameter(ParameterSetName = "ProfileSpecific")]
        [switch]
        $DisableFirewall,

        [Parameter(ParameterSetName = "ProfileSpecific")]
        [switch]
        $DisableNotifications,

        [Parameter(ParameterSetName = "ProfileSpecific")]
        [switch]
        $LogDroppedPackets,

        [Parameter(ParameterSetName = "ProfileSpecific")]
        [switch]
        $LogSuccessfulConnections,

        [Parameter(ParameterSetName = "ProfileSpecific")]
        [string]
        $LogFilePath,

        [Parameter(ParameterSetName = "ProfileSpecific")]
        [int]
        $LogFileSizeKB,

        [Parameter(ParameterSetName = "ProfileSpecific")]
        [string[]]
        $EnabledFirewallGroups,

        [Parameter(ParameterSetName = "ProfileSpecific")]
        [string[]]
        $DisabledFirewallGroups
    )
    process
    {
        $Component = $UnattendBuilder.GetOrCreateComponent('Networking-MPSSVC-Svc', 'specialize')
        if ($EnabledFirewallGroups -or $DisabledFirewallGroups)
        {
            $GroupsElement = $UnattendBuilder.GetOrCreateChildElement('FirewallGroups', $Component)
            $FwCommonParams = @{
                UnattendBuilder = $UnattendBuilder
                Parent          = $GroupsElement
                FirewallProfile = $FirewallProfile.ToLower()
            }
            if ($EnabledFirewallGroups)
            {
                AddFirewallGroupsToElement @FwCommonParams -GroupNames $EnabledFirewallGroups -Active $true
            }
            if ($DisabledFirewallGroups)
            {
                AddFirewallGroupsToElement @FwCommonParams -GroupNames $DisabledFirewallGroups -Active $false
            }
        }

        if ($PSBoundParameters.ContainsKey('DisableStatefulFTP'))
        {
            $UnattendBuilder.SetElementValue('DisableStatefulFTP', $DisableStatefulFTP, $Component)
        }
        if ($PSBoundParameters.ContainsKey('DisableStatefulPPTP'))
        {
            $UnattendBuilder.SetElementValue('DisableStatefulPPTP', $DisableStatefulPPTP, $Component)
        }

        $FwProfiles = if ($FirewallProfile -eq "All")
        {
            "Domain", 'Private', 'Public'
        }
        else
        {
            $FirewallProfile
        }

        foreach ($Item in $FwProfiles)
        {
            switch ($PSBoundParameters.Keys)
            {
                'DisableFirewall'
                {
                    $UnattendBuilder.SetElementValue("${Item}Profile_EnableFirewall", !$DisableFirewall, $Component)
                    continue
                }
                'DisableNotifications'
                {
                    $UnattendBuilder.SetElementValue("${Item}Profile_DisableNotifications", $DisableNotifications, $Component)
                    continue
                }
                'LogDroppedPackets'
                {
                    $UnattendBuilder.SetElementValue("${Item}Profile_LogDroppedPackets", $LogDroppedPackets, $Component)
                    continue
                }
                'LogSuccessfulConnections'
                {
                    $UnattendBuilder.SetElementValue("${Item}Profile_LogSuccessfulConnections", $LogSuccessfulConnections, $Component)
                    continue
                }
                'LogFilePath'
                {
                    $UnattendBuilder.SetElementValue("${Item}Profile_LogFile", $LogFilePath, $Component)
                    continue
                }
                'LogFileSizeKB'
                {
                    $UnattendBuilder.SetElementValue("${Item}Profile_LogFileSize", $LogFileSizeKB, $Component)
                    continue
                }
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures global IP settings.

.DESCRIPTION
    Configures global IP settings.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass to use.
    Valid values are:
    windowsPE
    specialize (default)

.PARAMETER DisableIcmpRedirects
    Specifies that the IPv4 and IPv6 path caches are not updated in response to ICMP redirect messages.
    This is a global setting that applies to all interfaces.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendIpSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet('windowsPE', 'specialize')]
        [string[]]
        $Pass = 'specialize',

        [Parameter()]
        [switch]
        $DisableIcmpRedirects
    )
    process
    {
        foreach ($PassName in $Pass)
        {
            $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-TCPIP', $PassName)

            if ($PSBoundParameters.ContainsKey('DisableIcmpRedirects'))
            {
                $UnattendBuilder.SetElementValue('IcmpRedirectsEnabled', !$DisableIcmpRedirects, $Component)
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures language and localization settings.

.DESCRIPTION
    Configures language and localization settings.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass this command should apply to.
    Valid values are:
    windowsPE
    specialize (Default)
    oobeSystem

.PARAMETER InputLocale
    Specifies the keyboard layout that should be used, for example: da-DK

.PARAMETER SystemLocale
    Specifies the language to use for non-unicode programs. Can be specified like this: da-DK

.PARAMETER UiLanguage
    Specifies the language of the shell. Can be specified like this: da-DK

.PARAMETER SetupUiLanguage
    Specifies the language to use in the WinPE setup UI.

.PARAMETER UiLanguageFallback
    The fallback language of the shell, for components that have not been localized in the primary language.
    Can be specified like this: en-US

.PARAMETER UserLocale
    Specifies the format used for dates, currency and other localized content.
    Can be specified like this: da-DK

.PARAMETER LayeredDriver
    The keyboard driver used in WinPE for asian languages.
    Valid values are 1-6.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendLanguageSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet('windowsPE', 'specialize', 'oobeSystem')]
        [string[]]
        $Pass = 'specialize',

        [Parameter()]
        [cultureinfo[]]
        $InputLocale,

        [Parameter()]
        [cultureinfo]
        $SystemLocale,

        [Parameter()]
        [cultureinfo]
        $UiLanguage,

        [Parameter()]
        [cultureinfo]
        $SetupUiLanguage,

        [Parameter()]
        [cultureinfo]
        $UiLanguageFallback,

        [Parameter()]
        [cultureinfo]
        $UserLocale,

        [Parameter()]
        [ValidateRange(1, 6)]
        [int]
        $LayeredDriver
    )
    process
    {
        foreach ($PassName in $Pass)
        {
            $ComponentName = if ($PassName -eq "windowsPE")
            {
                'Microsoft-Windows-International-Core-WinPE'
            }
            else
            {
                'Microsoft-Windows-International-Core'
            }

            $Component = $UnattendBuilder.GetOrCreateComponent($ComponentName, $PassName)
            switch ($PSBoundParameters.Keys)
            {
                'InputLocale'
                {
                    $UnattendBuilder.SetElementValue('InputLocale', $InputLocale.Name -join ';', $Component)
                    continue
                }
                'SystemLocale'
                {
                    $UnattendBuilder.SetElementValue('SystemLocale', $SystemLocale.Name, $Component)
                    continue
                }
                'UiLanguage'
                {
                    $UnattendBuilder.SetElementValue('UILanguage', $UiLanguage.Name, $Component)
                    continue
                }
                'UiLanguageFallback'
                {
                    $UnattendBuilder.SetElementValue('UILanguageFallback', $UiLanguageFallback.Name, $Component)
                    continue
                }
                'UserLocale'
                {
                    $UnattendBuilder.SetElementValue('UserLocale', $UserLocale.Name, $Component)
                    continue
                }
                'SetupUiLanguage'
                {
                    if ($PassName -eq "windowsPE")
                    {
                        $SetupUIElement = $UnattendBuilder.GetOrCreateChildElement('SetupUILanguage', $Component)
                        $UnattendBuilder.SetElementValue('UILanguage', $SetupUiLanguage, $SetupUIElement)
                    }
                    else
                    {
                        Write-Warning -Message "$_ can only be set on windowsPE pass. Ignoring it for pass: $PassName"
                    }
                    continue
                }
                'LayeredDriver'
                {
                    if ($PassName -eq "windowsPE")
                    {
                        $UnattendBuilder.SetElementValue('LayeredDriver', $LayeredDriver, $ComponentName)
                    }
                    else
                    {
                        Write-Warning -Message "$_ can only be set on windowsPE pass. Ignoring it for pass: $PassName"
                    }
                    continue
                }
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures settings related to the OOBE.

.DESCRIPTION
    Configures settings related to the Out Of Box Experience.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER HideEula
    Skips the EULA page (With the implication that you accept the EULA)

.PARAMETER HideLocalAccount
    Skips the page to set the password for the Administrator account on server editions.

.PARAMETER HideOem
    Skips any OEM specific page.

.PARAMETER HideOnlineAccount
    Skips the online account sign in/creation screen.

.PARAMETER HideNetworkSetup
    Skips the network setup page.

.PARAMETER UseExpressSettings
    Skips the pages related to express settings.
    When this switch is set, express settings will be turned on, and the page will be skipped.
    When this switch is explicitly turned off (by specifying the parameter like this: -UseExpressSettings:$false)
    Express settings will be turned off, and the page will be skipped.
    If this is not set then the page will be shown during OOBE.

.PARAMETER SkipMachineOOBE
    Is supposedly deprecated but skips the OOBE.

.PARAMETER SkipUserOOBE
    Is supposedly deprecated but skips the OOBE.

.PARAMETER NetworkLocation
    Sets the network location.
    Valid values are:
    Home
    Work
    Other

.PARAMETER SkipAdminProfileRemoval
    Skip removing the default administrator account profile.

.PARAMETER SkipLanguageChange
    Skips notifying windows about language changes during the OOBE.

.PARAMETER SkipWinReInitialization
    Skips setting up Win RE during the OOBE.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendOobeSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [switch]
        $HideEula,

        [Parameter()]
        [switch]
        $HideLocalAccount,

        [Parameter()]
        [switch]
        $HideOem,

        [Parameter()]
        [switch]
        $HideOnlineAccount,

        [Parameter()]
        [switch]
        $HideNetworkSetup,

        [Parameter()]
        [switch]
        $UseExpressSettings,

        [Parameter()]
        [switch]
        $SkipMachineOOBE,

        [Parameter()]
        [switch]
        $SkipUserOOBE,

        [Parameter()]
        [ValidateSet('Home', 'Work', 'Other')]
        [string]
        $NetworkLocation,

        [Parameter()]
        [switch]
        $SkipAdminProfileRemoval,

        [Parameter()]
        [switch]
        $SkipLanguageChange,

        [Parameter()]
        [switch]
        $SkipWinReInitialization
    )
    process
    {
        $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Shell-Setup', 'oobeSystem')
        $OOBE = $UnattendBuilder.GetOrCreateChildElement('OOBE', $Component)
        switch ($PSBoundParameters.Keys)
        {
            'HideEula'
            {
                $UnattendBuilder.SetElementValue('HideEULAPage', $HideEula, $OOBE)
                continue
            }
            'HideLocalAccount'
            {
                $UnattendBuilder.SetElementValue('HideLocalAccountScreen', $HideLocalAccount, $OOBE)
                continue
            }
            'HideOem'
            {
                $UnattendBuilder.SetElementValue('HideOEMRegistrationScreen', $HideOem, $OOBE)
                continue
            }
            'HideOnlineAccount'
            {
                $UnattendBuilder.SetElementValue('HideOnlineAccountScreens', $HideOnlineAccount, $OOBE)
                continue
            }
            'HideNetworkSetup'
            {
                $UnattendBuilder.SetElementValue('HideWirelessSetupInOOBE', $HideNetworkSetup, $OOBE)
                continue
            }
            'UseExpressSettings'
            {
                $Value = if ($UseExpressSettings)
                {
                    1
                }
                else
                {
                    3
                }
                $UnattendBuilder.SetElementValue('ProtectYourPC', $Value, $OOBE)
                continue
            }
            'SkipMachineOOBE'
            {
                $UnattendBuilder.SetElementValue('SkipMachineOOBE', $SkipMachineOOBE, $OOBE)
                continue
            }
            'SkipUserOOBE'
            {
                $UnattendBuilder.SetElementValue('SkipUserOOBE', $SkipUserOOBE, $OOBE)
                continue
            }
            'NetworkLocation'
            {
                $UnattendBuilder.SetElementValue('NetworkLocation', $NetworkLocation, $OOBE)
                continue
            }
            'SkipAdminProfileRemoval'
            {
                $VmOptimizations = $UnattendBuilder.GetOrCreateChildElement('VMModeOptimizations', $OOBE)
                $UnattendBuilder.SetElementValue('SkipAdministratorProfileRemoval', $SkipAdminProfileRemoval, $VmOptimizations)
                continue
            }
            'SkipLanguageChange'
            {
                $VmOptimizations = $UnattendBuilder.GetOrCreateChildElement('VMModeOptimizations', $OOBE)
                $UnattendBuilder.SetElementValue('SkipNotifyUILanguageChange', $SkipLanguageChange, $VmOptimizations)
                continue
            }
            'SkipWinReInitialization'
            {
                $VmOptimizations = $UnattendBuilder.GetOrCreateChildElement('VMModeOptimizations', $OOBE)
                $UnattendBuilder.SetElementValue('SkipWinREInitialization', $SkipWinReInitialization, $VmOptimizations)
                continue
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Adds information about the user and organization for Windows to the unattend file.

.DESCRIPTION
    Adds information about the user and organization for Windows to the unattend file.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass this command applies to.
    By default, this is applied to the windowsPE and specialize phases.
    Valid values are:
    windowsPE
    offlineServicing
    generalize
    specialize
    auditUser
    oobeSystem

.PARAMETER Owner
    Sets the name of the end user of the computer.

.PARAMETER Organization
    Sets the organization that the computer belongs to.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendOwnerInfo
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet("windowsPE", "offlineServicing", "generalize", "specialize", "auditUser", "oobeSystem")]
        [string[]]
        $Pass = ("windowsPE", "specialize"),

        [Parameter()]
        [string]
        $Owner,

        [Parameter()]
        [string]
        $Organization
    )
    process
    {
        foreach ($PassName in $Pass)
        {
            if ($PassName -eq "windowsPE")
            {
                $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Setup', $PassName)
                $UserData = $UnattendBuilder.GetOrCreateChildElement('UserData', $Component)
                switch ($PSBoundParameters.Keys)
                {
                    'Owner'
                    {
                        $UnattendBuilder.SetElementValue('FullName', $Owner, $UserData)
                        continue
                    }
                    'Organization'
                    {
                        $UnattendBuilder.SetElementValue('Organization', $Organization, $UserData)
                        continue
                    }
                }
            }
            else
            {
                $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Shell-Setup', $PassName)
                switch ($PSBoundParameters.Keys)
                {
                    'Owner'
                    {
                        $UnattendBuilder.SetElementValue('RegisteredOwner', $Owner, $Component)
                        continue
                    }
                    'Organization'
                    {
                        $UnattendBuilder.SetElementValue('RegisteredOrganization', $Organization, $Component)
                        continue
                    }
                }
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures power settings.

.DESCRIPTION
    Configures power settings.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass the command should apply to.
    Supported values are:
    generalize
    specialize (default)

.PARAMETER PowerPlan
    The GUID of the powerplan that should be set

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendPowerSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet('generalize', 'specialize')]
        [string[]]
        $Pass = 'specialize',

        [Parameter(Mandatory)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $TrimmedWord = $wordToComplete.Trim(("'",'"'))
            $PowerplanTable = @{
                PowerSaver          = 'a1841308-3541-4fab-bc81-f71556f20b4a'
                Balanced            = '381b4222-f694-41f0-9685-ff5bb260df2e'
                HighPerformance     = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
                UltimatePerformance = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
            }
            foreach ($Key in $PowerplanTable.Keys)
            {
                if ($Key -like "$TrimmedWord*")
                {
                    $CompletionText = $PowerplanTable[$Key]
                    $ListItemText   = $Key
                    $ResultType     = [System.Management.Automation.CompletionResultType]::ParameterValue
                    $ToolTip        = $Key
                    [System.Management.Automation.CompletionResult]::new($CompletionText, $ListItemText, $ResultType, $ToolTip)
                }
            }
        })]
        [guid]
        $PowerPlan
    )
    process
    {
        foreach ($PassName in $Pass)
        {
            $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-powercpl', $PassName)
            $UnattendBuilder.SetElementValue('PreferredPlan', $PowerPlan.Guid, $Component)
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Sets the product key to use during installation.

.DESCRIPTION
    Sets the product key to use during installation.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    The pass this command should apply to.
    By default, this command will add the key to all supported install phases.
    Supported values:
    windowsPE
    specialize

.PARAMETER ProductKey
    The product key to install.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendProductKey
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet("windowsPE", "specialize")]
        [string[]]
        $Pass = ("windowsPE", "specialize"),

        [Parameter(Mandatory, Position = 0)]
        [string]
        $ProductKey
    )
    process
    {
        switch ($Pass)
        {
            'windowsPE'
            {
                $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Setup', $_)
                $UserData = $UnattendBuilder.GetOrCreateChildElement("UserData", $Component)
                $KeyElement = $UnattendBuilder.GetOrCreateChildElement('ProductKey', $UserData)
                $UnattendBuilder.SetElementValue('Key', $ProductKey, $KeyElement)
                continue
            }
            'specialize'
            {
                $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Shell-Setup', $_)
                $UnattendBuilder.SetElementValue('ProductKey', $ProductKey, $Component)
                continue
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures RDP settings.

.DESCRIPTION
    Configures RDP settings.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass this should apply to.
    Valid values are:
    offlineServicing
    generalize
    specialize (default)

.PARAMETER EnableRDP
    Enables RDP connections to this computer.

.PARAMETER AllowArbitraryRemoteApps
    Allows remote users to launch remote apps that haven't been explicitly whitelisted on this computer.

.PARAMETER DisableNLA
    Disables Network Level Authentication when connecting to this computer.

.PARAMETER SecurityLayer
    Sets the security layer used when connecting to this computer.
    Valid values are:
    RDP - The RDP protocol is used.
    Negotiate - Client and server negotiates the most secure protocol supported by both.
    TLS - Forces the protocol to use TLS.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendRdpSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet('offlineServicing', 'generalize', 'specialize')]
        [string[]]
        $Pass = 'specialize',

        [Parameter()]
        [switch]
        $EnableRDP,

        [Parameter()]
        [switch]
        $AllowArbitraryRemoteApps,

        [Parameter()]
        [switch]
        $DisableNLA,

        [Parameter()]
        [RdpSecurityLayer]
        $SecurityLayer
    )
    process
    {
        foreach ($PassName in $Pass)
        {
            switch ($PSBoundParameters.Keys)
            {
                'EnableRDP'
                {
                    $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-TerminalServices-LocalSessionManager', $PassName)
                    $UnattendBuilder.SetElementValue('fDenyTSConnections', !$EnableRDP, $Component)
                    continue
                }
                'AllowArbitraryRemoteApps'
                {
                    $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-TerminalServices-Publishing-WMIProvider', $PassName)
                    $UnattendBuilder.SetElementValue('fDisabledAllowList', $AllowArbitraryRemoteApps, $Component)
                    continue
                }
                'DisableNLA'
                {
                    if ($PassName -ne "offlineServicing")
                    {
                        $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-TerminalServices-RDP-WinStationExtensions', $PassName)
                        $UnattendBuilder.SetElementValue('UserAuthentication', (!$DisableNLA).ToInt32($null), $Component)
                    }
                    else
                    {
                        Write-Warning -Message "$_ cannot be set in offlineServicing pass. Ignoring it for this pass."
                    }

                    continue
                }
                'SecurityLayer'
                {
                    if ($PassName -ne "offlineServicing")
                    {
                        $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-TerminalServices-RDP-WinStationExtensions', $PassName)
                        $UnattendBuilder.SetElementValue('SecurityLayer', $SecurityLayer.value__, $Component)
                    }
                    else
                    {
                        Write-Warning -Message "$_ cannot be set in offlineServicing pass. Ignoring it for this pass."
                    }

                    continue
                }
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures server manager settings.

.DESCRIPTION
    Configures server manager settings.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass this command should apply to.
    Supported values:
    generalize
    specialize (default)

.PARAMETER DontOpenServerManagerAtLogon
    Stops server manager from opening by default when a user logs on.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendServerManagerSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet('generalize', 'specialize')]
        [string[]]
        $Pass = 'specialize',

        [Parameter(Mandatory)]
        [switch]
        $DontOpenServerManagerAtLogon
    )
    process
    {
        foreach ($PassName in $Pass)
        {
            $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-ServerManager-SvrMgrNc', $PassName)
            $UnattendBuilder.SetElementValue('DoNotOpenServerManagerAtLogon', $DontOpenServerManagerAtLogon, $Component)
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures sysprep behavior for devices and device drivers.

.DESCRIPTION
    Configures sysprep behavior for devices and device drivers.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER DontCleanNonPresentDevices
    Specifies whether Plug and Play information persists on the destination computer during the following specialize configuration pass.

.PARAMETER PersistAllDeviceInstalls
    Specifies whether all Plug and Play information persists on the destination computer during the generalize configuration pass.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendSysPrepSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [switch]
        $DontCleanNonPresentDevices,

        [Parameter()]
        [switch]
        $PersistAllDeviceInstalls
    )
    process
    {
        $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-PnpSysprep', 'generalize')
        switch ($PSBoundParameters.Keys)
        {
            'DontCleanNonPresentDevices'
            {
                $UnattendBuilder.SetElementValue('DoNotCleanUpNonPresentDevices', $DontCleanNonPresentDevices, $Component)
                continue
            }
            'PersistAllDeviceInstalls'
            {
                $UnattendBuilder.SetElementValue('PersistAllDeviceInstalls', $PersistAllDeviceInstalls, $Component)
                continue
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures time settings.

.DESCRIPTION
    Configures time settings.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER Pass
    Specifies the pass this command should apply to.
    Supported values:
    specialize (default)
    auditSystem
    oobeSystem

.PARAMETER TimeZone
    The ID of the timezone to set during installation.
    The available timzones can be listed with the following PS command: [System.TimeZoneInfo]::GetSystemTimeZones()

.PARAMETER DisableAutoDaylight
    Specifies that daylight savings should not be applied automatically by Windows.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendTimeSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [ValidateSet("specialize", "auditSystem", "oobeSystem")]
        [string[]]
        $Pass = "specialize",

        [Parameter()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $TrimmedWord = $wordToComplete.Trim(("'",'"'))

            foreach ($Timezone in [System.TimeZoneInfo]::GetSystemTimeZones())
            {
                if ($Timezone.Id -like "$TrimmedWord*")
                {
                    $CompletionText = "'$($Timezone.Id)'"
                    $ListItemText   = $Timezone.Id
                    $ResultType     = [System.Management.Automation.CompletionResultType]::ParameterValue
                    $ToolTip        = $Timezone.DisplayName
                    [System.Management.Automation.CompletionResult]::new($CompletionText, $ListItemText, $ResultType, $ToolTip)
                }
            }
        })]
        [string]
        $TimeZone,

        [Parameter()]
        [switch]
        $DisableAutoDaylight
    )
    process
    {
        foreach ($PassName in $Pass)
        {
            $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Shell-Setup', $PassName)
            switch ($PSBoundParameters.Keys)
            {
                'TimeZone'
                {
                    $UnattendBuilder.SetElementValue('TimeZone', $TimeZone, $Component)
                    continue
                }
                'DisableAutoDaylight'
                {
                    $UnattendBuilder.SetElementValue('DisableAutoDaylightTimeSet', $DisableAutoDaylight, $Component)
                    continue
                }
            }
        }

        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures TPM settings.

.DESCRIPTION
    Configures Trusted Platform Module settings.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER ClearBehavior
    Controls under which circumstances the TPM should be cleared.
    Clearing the TPM will delete all the keys stored on the TPM, such as bitlocker keys or Windows Hello PINs.
    Valid values:
    Never - Does not clear the TPM (Default behavior).
    WhenOwner - Clears the TPM if Windows has taken ownership of the TPM.
    Always - Always clears the TPM.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendTpmSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter(Mandatory)]
        [TpmClearBehavior]
        $ClearBehavior
    )
    process
    {
        $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-TPM-Tasks', 'specialize')
        $UnattendBuilder.SetElementValue('ClearTpm', $ClearBehavior.value__, $Component)
        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures UAC settings.

.DESCRIPTION
    Configures User Account Control settings (previously known as Limited User Account).

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER DisableUAC
    Disables UAC.
    Disabling UAC means that any program run by privileged accounts will run elevated without any prompt, even if "Run As Administrator" is not chosen by the user.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendUacSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter(Mandatory)]
        [switch]
        $DisableUAC
    )
    process
    {
        $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-LUA-Settings', "offlineServicing")
        $UnattendBuilder.SetElementValue('EnableLUA', !$DisableUAC, $Component)
        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures various settings used during Windows setup in WinPE.

.DESCRIPTION
    Configures various settings used during Windows setup in WinPE.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER DisableFirewall
    Specifies whether Windows Firewall is enabled for Windows Preinstallation Environment (Windows PE).
    This setting does not apply to the Windows Firewall settings of the Windows installation.

.PARAMETER EnableNetwork
    Specifies whether network connection is enabled.
    This setting applies only to Windows Preinstallation Environment (Windows PE).
    In the standard Windows setup WinPE image, networking is disabled by default.
    For custom WinPE images, networking is enabled by default.

.PARAMETER LogDirectory
    Specifies where log files for WinPE will be saved.

.PARAMETER ShutdownAfterWinPE
    Specifies that WinPE should shutdown rather than reboot after finishing.

.PARAMETER UseConfigurationSet
    Specifies whether to use a configuration set for Windows Setup.
    A configuration set is a folder that contains additional device drivers, applications, or other binaries that you want to add to Windows during installation.
    You can create a configuration set in Windows System Image Manager.

.PARAMETER DisableDiskEncryptionProvisioning
    Specifies whether Windows activates encryption on blank drives that are capable of hardware-based encryption during installation.

.PARAMETER PagefilePath
    Specifies the path to use for the page file used in WinPE.

.PARAMETER PagefileSizeMB
    Specifies the max size of the page file used in WinPE.

.PARAMETER AcceptEula
    Specifies that you accept the Windows EULA of the image you are installing.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendWindowsSetupSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter()]
        [switch]
        $DisableFirewall,

        [Parameter()]
        [switch]
        $EnableNetwork,

        [Parameter()]
        [string]
        $LogDirectory,

        [Parameter()]
        [switch]
        $ShutdownAfterWinPE,

        [Parameter()]
        [switch]
        $UseConfigurationSet,

        [Parameter()]
        [switch]
        $DisableDiskEncryptionProvisioning,

        [Parameter()]
        [string]
        $PagefilePath,

        [Parameter()]
        [string]
        $PagefileSizeMB,

        [Parameter()]
        [switch]
        $AcceptEula
    )
    process
    {
        $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-Setup', 'windowsPE')
        switch ($PSBoundParameters.Keys)
        {
            'DisableFirewall'
            {
                $UnattendBuilder.SetElementValue('EnableFirewall', !$DisableFirewall, $Component)
                continue
            }
            'EnableNetwork'
            {
                $UnattendBuilder.SetElementValue('EnableNetwork', $EnableNetwork, $Component)
                continue
            }
            'LogDirectory'
            {
                $UnattendBuilder.SetElementValue('LogPath', $LogDirectory, $Component)
                continue
            }
            'ShutdownAfterWinPE'
            {
                $Text = if ($ShutdownAfterWinPE)
                {
                    "Shutdown"
                }
                else
                {
                    "Restart"
                }
                $UnattendBuilder.SetElementValue('Restart', $Text, $Component)
                continue
            }
            'UseConfigurationSet'
            {
                $UnattendBuilder.SetElementValue('UseConfigurationSet', $UseConfigurationSet, $Component)
                continue
            }
            'DisableDiskEncryptionProvisioning'
            {
                $DiskConfig = $UnattendBuilder.GetOrCreateChildElement('DiskConfiguration', $Component)
                $UnattendBuilder.SetElementValue('DisableEncryptedDiskProvisioning', $DisableDiskEncryptionProvisioning, $DiskConfig)
                continue
            }
            'PagefilePath'
            {
                $PageFile = $UnattendBuilder.GetOrCreateChildElement('PageFile', $Component)
                $UnattendBuilder.SetElementValue('Path', $PagefilePath, $PageFile)
                continue
            }
            'PagefileSizeMB'
            {
                $PageFile = $UnattendBuilder.GetOrCreateChildElement('PageFile', $Component)
                $UnattendBuilder.SetElementValue('Size', $PagefileSizeMB, $PageFile)
                continue
            }
            'AcceptEula'
            {
                $UserData = $UnattendBuilder.GetOrCreateChildElement('UserData', $Component)
                $UnattendBuilder.SetElementValue('AcceptEula', $AcceptEula, $UserData)
                continue
            }
        }
        $UnattendBuilder
    }
}
<#
.SYNOPSIS
    Configures Windows RE settings.

.DESCRIPTION
    Configures Windows Recovery Environment settings.

.PARAMETER UnattendBuilder
    The UnattendBuilder object that this should be added to.
    Create one with the command: New-UnattendBuilder

.PARAMETER UninstallWindowsRE
    Uninstalls the recovery environment during OOBE.
    This can be used to save disk space (Typically, about 500MB) on systems where recovery options aren't needed.

.INPUTS
    [UnattendBuilder]
    Create one with the command: New-UnattendBuilder

.OUTPUTS
    [UnattendBuilder]
#>
function Set-UnattendWinReSetting
{
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([UnattendBuilder])]
    Param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [UnattendBuilder]
        $UnattendBuilder,

        [Parameter(Mandatory)]
        [switch]
        $UninstallWindowsRE
    )
    process
    {
        $Component = $UnattendBuilder.GetOrCreateComponent('Microsoft-Windows-WinRE-RecoveryAgent', 'oobeSystem')
        $UnattendBuilder.SetElementValue('UninstallWindowsRE', $UninstallWindowsRE, $Component)
        $UnattendBuilder
    }
}
$CultureCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $TrimmedWord = $wordToComplete.Trim(("'",'"'))
    foreach ($Culture in [cultureinfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures))
    {
        if ($Culture.Name -ne "" -and $Culture.Name -like "$TrimmedWord*")
        {
            $CompletionText = $Culture.Name
            $ListItemText   = $Culture.Name
            $ResultType     = [System.Management.Automation.CompletionResultType]::ParameterValue
            $ToolTip        = $Culture.DisplayName
            [System.Management.Automation.CompletionResult]::new($CompletionText, $ListItemText, $ResultType, $ToolTip)
        }
    }
}
Register-ArgumentCompleter -CommandName New-UnattendBuilder,Set-UnattendLanguageSetting -ParameterName UiLanguage      -ScriptBlock $CultureCompleter
Register-ArgumentCompleter -CommandName New-UnattendBuilder,Set-UnattendLanguageSetting -ParameterName SystemLocale    -ScriptBlock $CultureCompleter
Register-ArgumentCompleter -CommandName New-UnattendBuilder,Set-UnattendLanguageSetting -ParameterName InputLocale     -ScriptBlock $CultureCompleter
Register-ArgumentCompleter -CommandName Set-UnattendLanguageSetting                     -ParameterName SetupUiLanguage -ScriptBlock $CultureCompleter
Register-ArgumentCompleter -CommandName Set-UnattendLanguageSetting                     -ParameterName UserLocale -ScriptBlock $CultureCompleter
Register-ArgumentCompleter -CommandName Set-UnattendLanguageSetting                     -ParameterName UiLanguageFallback -ScriptBlock $CultureCompleter

Register-ArgumentCompleter -CommandName New-UnattendBuilder,Set-UnattendProductKey -ParameterName ProductKey -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $TrimmedWord = $wordToComplete.Trim(("'",'"'))
    $WindowsKeyTable = [ordered]@{
        Win10Home            = 'YTMG3-N6DKC-DKB77-7M9GH-8HVX7'
        Win10Pro             = 'VK7JG-NPHTM-C97JM-9MPGT-3V66T'
        Win10Edu             = 'YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY'
        Win10Enterprise      = 'XGVPP-NMH47-7TTHJ-W3FW7-8HV2C'
        Server2016Standard   = 'WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY'
        Server2016Datacenter = 'CB7KF-BWN84-R7R2Y-793K2-8XDDG'
        Server2019Standard   = 'N69G4-B89J2-4G8F4-WWYCC-J464C'
        Server2019Datacenter = 'WMDGN-G9PQG-XVVXX-R3X43-63DFG'
        Server2022Standard   = 'VDYBN-27WPP-V4HQT-9VMD4-VMK7H'
        Server2022Datacenter = 'WX4NM-KYWYW-QJJR4-XV3QB-6VM33'
    }
    foreach ($Key in $WindowsKeyTable.Keys)
    {
        if ($Key -like "$TrimmedWord*")
        {
            $CompletionText = $WindowsKeyTable[$Key]
            $ListItemText   = $Key
            $ResultType     = [System.Management.Automation.CompletionResultType]::ParameterValue
            $ToolTip        = $Key
            [System.Management.Automation.CompletionResult]::new($CompletionText, $ListItemText, $ResultType, $ToolTip)
        }
    }
}

$FwGroupCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $TrimmedWord = $wordToComplete.Trim(("'",'"'))
    $AllGroups = @'
DisplayGroup;Group
COM+ Network Access;@%systemroot%\system32\firewallapi.dll,-3400
COM+ Remote Administration;@%systemroot%\system32\firewallapi.dll,-3405
Core Networking;@FirewallAPI.dll,-25000
Core Networking Diagnostics;@FirewallAPI.dll,-27000
DHCP Server;@FirewallAPI.dll,-50209
DHCP Server Management;@FirewallAPI.dll,-50213
DIAL protocol server;@FirewallAPI.dll,-37101
Distributed Transaction Coordinator;@FirewallAPI.dll,-33502
DNS Service;@firewallapi.dll,-53012
File and Printer Sharing;@FirewallAPI.dll,-28502
File and Printer Sharing over QUIC;@FirewallAPI.dll,-28652
File and Printer Sharing over SMBDirect;@FirewallAPI.dll,-28602
File Server Remote Management;@fssmres.dll,-100
Hyper-V;@%systemroot%\system32\vmms.exe,-210
Hyper-V Management Clients;@FirewallAPI.dll,-60201
Hyper-V Replica HTTP;@%systemroot%\system32\vmms.exe,-251
Hyper-V Replica HTTPS;@%systemroot%\system32\vmms.exe,-253
iSCSI Service;@FirewallAPI.dll,-29002
Key Management Service;@FirewallAPI.dll,-28002
mDNS;@%SystemRoot%\system32\firewallapi.dll,-37302
Microsoft Media Foundation Network Source;@FirewallAPI.dll,-54001
Netlogon Service;@firewallapi.dll,-37681
Network Discovery;@FirewallAPI.dll,-32752
Performance Logs and Alerts;@FirewallAPI.dll,-34752
Remote Desktop;@FirewallAPI.dll,-28752
Remote Desktop (WebSocket);@FirewallAPI.dll,-28782
Remote Event Log Management;@FirewallAPI.dll,-29252
Remote Event Monitor;@FirewallAPI.dll,-36801
Remote Scheduled Tasks Management;@FirewallAPI.dll,-33252
Remote Service Management;@FirewallAPI.dll,-29502
Remote Shutdown;@firewallapi.dll,-36751
Remote Volume Management;@FirewallAPI.dll,-34501
Routing and Remote Access;@FirewallAPI.dll,-33752
Secure Socket Tunneling Protocol;@sstpsvc.dll,-35001
SNMP Trap;@firewallapi.dll,-50323
Windows Defender Firewall Remote Management;@FirewallAPI.dll,-30002
Windows Deployment Services;@firewallapi.dll,-38201
Windows Device Management;@FirewallAPI.dll,-37502
Windows Management Instrumentation (WMI);@FirewallAPI.dll,-34251
Windows Remote Management;@FirewallAPI.dll,-30267
Windows Remote Management (Compatibility);@FirewallAPI.dll,-30252
'@ | ConvertFrom-Csv -Delimiter ';'
    foreach ($Group in $AllGroups)
    {
        if ($Group.DisplayGroup -like "$TrimmedWord*")
        {
            $CompletionText = "'$($Group.Group)'"
            $ListItemText   = $Group.DisplayGroup
            $ResultType     = [System.Management.Automation.CompletionResultType]::ParameterValue
            $ToolTip        = $Group.DisplayGroup
            [System.Management.Automation.CompletionResult]::new($CompletionText, $ListItemText, $ResultType, $ToolTip)
        }
    }
}
Register-ArgumentCompleter -CommandName Set-UnattendFirewallSetting -ParameterName EnabledFirewallGroups -ScriptBlock $FwGroupCompleter
Register-ArgumentCompleter -CommandName Set-UnattendFirewallSetting -ParameterName DisabledFirewallGroups -ScriptBlock $FwGroupCompleter

