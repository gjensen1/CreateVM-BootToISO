param(
    [Parameter(Mandatory=$true)][String]$vCenter
    )

# -----------------------
# Define Global Variables
# -----------------------
$Global:Folder = $env:USERPROFILE+"\Documents\Create-USBManager"
$Global:WorkingFolder = $Null
$Global:LogLocation = $Null

#**************************
# Function Check-PowerCLI10 
#**************************
Function Check-PowerCLI10 {
    [CmdletBinding()]
    Param()
    #Check for Prereqs for the script
    #This includes, PowerCLI 10, plink, and pscp

    #Check for PowerCLI 10
    $powercli = Get-Module -ListAvailable VMware.PowerCLI
    if (!($powercli.version.Major -eq "10")) {
        Throw "VMware PowerCLI 10 is not installed on your system!!!"
    }
    Else {
        Write-Host "PowerCLI 10 is Installed" -ForegroundColor Green
    } 
}
#*****************************
# EndFunction Check-PowerCLI10
#*****************************

#*******************
# Connect to vCenter
#*******************
Function Connect-VC {
    [CmdletBinding()]
    Param()
    "Connecting to $Global:VCName"
    Connect-VIServer $Global:VCName -Credential $Global:Creds -WarningAction SilentlyContinue
    #Connect-VIServer $Global:VCName -WarningAction SilentlyContinue
}
#***********************
# EndFunction Connect-VC
#***********************

#*******************
# Disconnect vCenter
#*******************
Function Disconnect-VC {
    [CmdletBinding()]
    Param()
    "Disconnecting $Global:VCName"
    Disconnect-VIServer -Server $Global:VCName -Confirm:$false
}
#**************************
# EndFunction Disconnect-VC
#**************************

#***************************
# Function Get-ISOToTransfer
#***************************
Function Get-ISOToTransfer{
    [CmdletBinding()]
    Param($initialDirectory)
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "ISO (*.iso)| *.iso"
    $OpenFileDialog.ShowDialog() | Out-Null
    Return $OpenFileDialog.filename
}
#******************************
# EndFunction Get-ISOToTransfer
#******************************

#**********************
# Function Get-FileName
#**********************
Function Get-FileName {
    [CmdletBinding()]
    Param($initialDirectory)
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "TXT (*.txt)| *.txt"
    $OpenFileDialog.ShowDialog() | Out-Null
    Return $OpenFileDialog.filename
}
#*************************
# EndFunction Get-FileName
#*************************

#*************************
# Function Read-TargetList
#*************************
Function Read-TargetList {
    [CmdletBinding()]
    Param($TargetFile)
    $Targets = Get-Content $TargetFile
    Return $Targets
}
#****************************
# EndFunction Read-TargetList
#****************************

#******************
# Function Copy-ISO
#******************
Function Copy-ISO{
    [CmdletBinding()]
    Param($TgtHost,$TgtDataStores)
    $DataStore = $TgtDataStores[($TgtDataStores.Count)-1]
    New-PSDrive -Location $DataStore -Name DS -PSProvider VimDatastore -Root "\" > $null  
        If(!(Test-Path "DS:\ISO")){
            "No ISO datastore found on $TgtHost Adding..."
            New-Item -ItemType Directory -Path "DS:/ISO" > $Null    
        }
    "Copying ISO to $TgtHost on DataStore $DataStore"
    Copy-DatastoreItem -Item $FileToTransfer -Destination "DS:\ISO"
    Remove-PSDrive -Name ds -Confirm:$false
}
#**********************
# End-Function Copy-ISO
#**********************

#***************
# Execute Script
#***************
CLS
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference="Continue"
Start-Transcript -path $Global:Folder\Deploy-Firmware-Log-$(Get-Date -Format yyyy-MM-dd-hh-mm-tt).txt
"=========================================================="
#Verify all require software is installed
"Checking for required Software on your system"
"=========================================================="
Check-PowerCLI10
#Check-Putty
#Check-WinSCP
$ErrorActionPreference="SilentlyContinue"
"=========================================================="
" "
Write-Host "Get CIHS credentials" -ForegroundColor Yellow
$Global:Creds = Get-Credential -Credential $null

#Get-VCenter
$Global:VCName = $vCenter
Connect-VC
"----------------------------------------------------------"
"Get ISO file to be transfered to host"
$FileToTransfer = Get-ISOToTransfer $Global:Folder
$Global:WorkingFolder = Split-Path -Path $FileToTransfer
"----------------------------------------------------------"
"Get Target List"
$inputFile = Get-FileName $Global:WorkingFolder
"----------------------------------------------------------"
"Reading Target List"
$VMHostList = Read-TargetList $inputFile
"----------------------------------------------------------"
"Processing Target List"
ForEach ($VMhost in $VMHostList){
    $DataStores = Get-VMHost -Name $VMHost |Get-Datastore
    Copy-ISO $VMHost $DataStores
    "----------------------------------------------------------"
}
Disconnect-VC
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null