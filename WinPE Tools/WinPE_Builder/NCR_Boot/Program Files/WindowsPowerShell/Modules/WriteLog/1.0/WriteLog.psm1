
<#PSScriptInfo

.VERSION 1.0.0.1

.GUID 3e570dcf-f71b-47e3-98ff-05a790971660

.AUTHOR RP230049

.COMPANYNAME NCR Atleos Corp

.COPYRIGHT 2020

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
 Called Function to add Write-Log option to Powershell Scripts 

#> 

Param()


<#######################################################################################################################
#					
Powershell function that will add a Write-Log function to other scripts
#						
#
#									Copyright 2020 NCR Corporation
#										All Rights Reserved
#
#########################################################################################################################>


function Write-Log 
<#
.PARAMETER Message 
   Message is the content that you wish to add to the log file.  
.PARAMETER Path 
   The path to the log file to which you would like to write. By default the function will  
   create the path and file if it does not exist. The default logfile is C:\Install\Logs\PowerShellLog.txt  
.PARAMETER Level 
   Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational) 
.PARAMETER NoClobber 
   Use NoClobber if you do not wish to overwrite an existing file. Not needed if all you want to do is Append and
   existing file.
#>
{ 
    [CmdletBinding()] 
    Param 
    ( 
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 
 
        [Parameter(Mandatory=$false)] 
        [Alias('LogPath')] 
        [string]$Path='C:\Install\Logs\PowerShellLog.txt', 
         
        [Parameter(Mandatory=$false)] 
        [ValidateSet("Error","Warn","Info")] 
        [string]$Level="Info", 
         
        [Parameter(Mandatory=$false)] 
        [switch]$NoClobber 
    ) 
 
    Begin 
    { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue' 
    } 
    Process 
    { 
         
        # If the file already exists and NoClobber was specified, do not write to the log. 
        if ((Test-Path $Path) -AND $NoClobber) { 
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name." 
            Return 
            } 
 
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path. 
        elseif (!(Test-Path $Path)) { 
            Write-Verbose "Creating $Path." 
            $NewLogFile = New-Item $Path -Force -ItemType File 
            } 
 
        # Format Date and Script name for Log File 
        $FormattedDate = Get-Date -Format "MM-dd-yyyy HH:mm:ss" 
        $Script = $MyInvocation.ScriptName -creplace '(?s)^.*\\', ''

        # Write message to error, warning, or verbose pipeline and specify $LevelText 
        switch ($Level) { 
            'Error' { 
                Write-Error $Message 
                $LevelText = 'ERROR:' 
                } 
            'Warn' { 
                Write-Warning $Message 
                $LevelText = 'WARNING:' 
                } 
            'Info' { 
                Write-Verbose $Message 
                $LevelText = 'INFO:' 
                } 
            } 
         
        # Write log entry to $Path 
        "[$FormattedDate - $Script] $LevelText $Message" | Out-File -FilePath $Path -Append 
    } 
    End 
    { 
    } 
}
