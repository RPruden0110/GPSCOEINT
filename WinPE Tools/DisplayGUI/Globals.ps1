#--------------------------------------------
# Declare Global Variables and Functions here
#--------------------------------------------

# Log Path
$Log = ".\Log\Display.log"
if (!(Test-Path ".\Log")) {New-Item -Path ".\" -ItemType "Directory" -Name "Log"}
if (Test-Path "$Log") { Remove-Item -Path "$Log" -Force }

# Configuration JSON location
$ConfigDIR = ".\Config"
IF (!(Test-Path -Path "$ConfigDIR")) { New-Item -Path ".\" -ItemType "directory" -Name "Config" }

Write-Log -LogPath "$Log" -Message "******************************************************************"
Write-Log -LogPath "$Log" -Message "Starting Terminal Configuration"
Write-Log -LogPath "$Log" -Message "******************************************************************"

#Sample function that provides the location of the script
function Get-ScriptDirectory
{
<#
	.SYNOPSIS
		Get-ScriptDirectory returns the proper location of the script.

	.OUTPUTS
		System.String
	
	.NOTES
		Returns the correct path within a packaged executable.
#>
	[OutputType([string])]
	param ()
	if ($null -ne $hostinvocation)
	{
		Split-Path $hostinvocation.MyCommand.path
	}
	else
	{
		Split-Path $script:MyInvocation.MyCommand.Path
	}
}

#Sample variable that provides the location of the script
[string]$ScriptDirectory = Get-ScriptDirectory


#region Control Helper Functions
function Update-ComboBox
{
<#
	.SYNOPSIS
		This functions helps you load items into a ComboBox.
	
	.DESCRIPTION
		Use this function to dynamically load items into the ComboBox control.
	
	.PARAMETER ComboBox
		The ComboBox control you want to add items to.
	
	.PARAMETER Items
		The object or objects you wish to load into the ComboBox's Items collection.
	
	.PARAMETER DisplayMember
		Indicates the property to display for the items in this control.
		
	.PARAMETER ValueMember
		Indicates the property to use for the value of the control.
	
	.PARAMETER Append
		Adds the item(s) to the ComboBox without clearing the Items collection.
	
	.EXAMPLE
		Update-ComboBox $combobox1 "Red", "White", "Blue"
	
	.EXAMPLE
		Update-ComboBox $combobox1 "Red" -Append
		Update-ComboBox $combobox1 "White" -Append
		Update-ComboBox $combobox1 "Blue" -Append
	
	.EXAMPLE
		Update-ComboBox $combobox1 (Get-Process) "ProcessName"
	
	.NOTES
		Additional information about the function.
#>
	
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[System.Windows.Forms.ComboBox]$ComboBox,
		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		$Items,
		[Parameter(Mandatory = $false)]
		[string]$DisplayMember,
		[Parameter(Mandatory = $false)]
		[string]$ValueMember,
		[switch]$Append
	)
	
	if (-not $Append)
	{
		$ComboBox.Items.Clear()
	}
	
	if ($Items -is [Object[]])
	{
		$ComboBox.Items.AddRange($Items)
	}
	elseif ($Items -is [System.Collections.IEnumerable])
	{
		$ComboBox.BeginUpdate()
		foreach ($obj in $Items)
		{
			$ComboBox.Items.Add($obj)
		}
		$ComboBox.EndUpdate()
	}
	else
	{
		$ComboBox.Items.Add($Items)
	}
	
	if ($DisplayMember)
	{
		$ComboBox.DisplayMember = $DisplayMember
	}
	
	if ($ValueMember)
	{
		$ComboBox.ValueMember = $ValueMember
	}
}



function Update-ListBox
{
<#
	.SYNOPSIS
		This functions helps you load items into a ListBox or CheckedListBox.
	
	.DESCRIPTION
		Use this function to dynamically load items into the ListBox control.
	
	.PARAMETER ListBox
		The ListBox control you want to add items to.
	
	.PARAMETER Items
		The object or objects you wish to load into the ListBox's Items collection.
	
	.PARAMETER DisplayMember
		Indicates the property to display for the items in this control.
		
	.PARAMETER ValueMember
		Indicates the property to use for the value of the control.
	
	.PARAMETER Append
		Adds the item(s) to the ListBox without clearing the Items collection.
	
	.EXAMPLE
		Update-ListBox $ListBox1 "Red", "White", "Blue"
	
	.EXAMPLE
		Update-ListBox $listBox1 "Red" -Append
		Update-ListBox $listBox1 "White" -Append
		Update-ListBox $listBox1 "Blue" -Append
	
	.EXAMPLE
		Update-ListBox $listBox1 (Get-Process) "ProcessName"
	
	.NOTES
		Additional information about the function.
#>
	
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[System.Windows.Forms.ListBox]$ListBox,
		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		$Items,
		[Parameter(Mandatory = $false)]
		[string]$DisplayMember,
		[Parameter(Mandatory = $false)]
		[string]$ValueMember,
		[switch]$Append
	)
	
	if (-not $Append)
	{
		$ListBox.Items.Clear()
	}
	
	if ($Items -is [System.Windows.Forms.ListBox+ObjectCollection] -or $Items -is [System.Collections.ICollection])
	{
		$ListBox.Items.AddRange($Items)
	}
	elseif ($Items -is [System.Collections.IEnumerable])
	{
		$ListBox.BeginUpdate()
		foreach ($obj in $Items)
		{
			$ListBox.Items.Add($obj)
		}
		$ListBox.EndUpdate()
	}
	else
	{
		$ListBox.Items.Add($Items)
	}
	
	if ($DisplayMember)
	{
		$ListBox.DisplayMember = $DisplayMember
	}
	if ($ValueMember)
	{
		$ListBox.ValueMember = $ValueMember
	}
}



function Test-IPaddress
{
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0)]
		[ValidateScript({ $_ -match [IPAddress]$_ })]
		[string]$IPAddress
	)
	
	Begin
	{
	}
	Process
	{
		[ipaddress]$IPAddress
	}
	End
	{
	}
}


#endregion
