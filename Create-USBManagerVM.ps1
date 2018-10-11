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

#*****************************
# Function Get-TargetDataStore
#*****************************
Function Get-TargetDataStore{
    [CmdletBinding()]
    Param($TgtHost)
    $Datastores = Get-VMHost -name $TgtHost | Get-Datastore
    $CustomDatastore = @()
    ForEach ($vmstore in $Datastores){
        $vmstores = New-Object PSObject
        $vmstores | Add-Member -MemberType NoteProperty -Name StoreName -Value $vmstore.Name
        $vmstores | Add-Member -MemberType NoteProperty -Name PercentFree -Value (($vmstore.FreeSpaceGB/$vmstore.CapacityGB)*100)
        $CustomDatastore += $vmstores
    }
    $MostFreeSpace = $CustomDatastore | Sort-Object -Property PercentFree -Descending
    $TargetDataStore = $MostFreeSpace[0].StoreName
    Return $TargetDataStore    
}
#*********************************
# End-Function Get-TargetDataStore
#*********************************

#***********************
# Function Find-WinPEISO
#***********************
Function Find-WinPEISO{
    [CmdletBinding()]
    Param($TgtHost)
    $isoFound = $Null
    $datastores = Get-VMHost $TgtHost | Get-Datastore
    If ($datastores.Count -eq 1){
        new-psdrive -location $datastores[0] -Name DS -PSProvider VimDatastore -Root "\" > $null    
        If (Test-Path DS:\ISO){
            $isoFound = dir ds:\ISO -Recurse -Include WinPE_x86.iso
            #check if isoFound is not null then capture the DatastoreFullPath
            If ($isoFound -ne $null){
                $ISOPath = $isoFound.DatastoreFullPath
            }
        }        
        Remove-PSDrive -Name ds -Confirm:$false
        #Return $ISOPath    
    }
    If ($datastores.Count -gt 1){
        new-psdrive -location $datastores[1] -Name DS -PSProvider VimDatastore -Root "\" > $null    
        If (Test-Path DS:\ISO){
            $isoFound = dir ds:\ISO -Recurse -Include WinPE_x86.iso
            #check if isoFound is not null then capture the DatastoreFullPath
            If ($isoFound -ne $null){
                $ISOPath = $isoFound.DatastoreFullPath
            }
        }        
        Remove-PSDrive -Name ds -Confirm:$false
        #Return $ISOPath    
    }
    If($isoFound -eq $Null){
        Write-Host "ISO not found where we expected it searching all Datastores" -ForegroundColor Yellow
        Write-Host "                 -- Please be patient --                   " -ForegroundColor Yellow
        ForEach ($datastore in $datastores){
            new-psdrive -location $datastore -Name DS -PSProvider VimDatastore -Root "\" > $null
            $isoFound = dir ds:\ -Recurse -Include WinPE_x86.iso
            #check if isoFound is not null then capture the DatastoreFullPath
            If ($isoFound -ne $null){
                $ISOPath = $isoFound.DatastoreFullPath
            }
            Remove-PSDrive -Name ds -Confirm:$false
        }
        If ($ISOPath -eq $Null){
            Write-Host " " 
            Write-Host "*********************************" -ForegroundColor Red
            Write-Host "* ISO was not found on Host !!! *" -ForegroundColor Red
            Write-Host "*********************************" -ForegroundColor Red
        }
    }
    Return $ISOPath
}
#***************************
# End-Function Find-WinPEISO
#***************************


#*******************
# Function Create-VM
#*******************
Function Create-VM{
    [CmdletBinding()]
    Param($TgtHost,$TgtVMName,$TgtDataStore)
    "Creating $TgtVMName on $TgtHost"
    New-VM -VMHost $TgtHost -Name $TgtVMName -Datastore $TgtDataStore -MemoryMB 1024 -NumCpu 1 >$Null
    "Setting NIC Type on $TgtVMName to E1000"
    Get-VM $TgtVMName | Get-NetworkAdapter | Set-NetworkAdapter -Type e1000 -Confirm:$false >$null
}
#***********************
# End-Function Create-VM
#***********************

#***************
# Execute Script
#***************
CLS
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference="Continue"
Start-Transcript -path $Global:Folder\Create-USBManagerVM-Log-$(Get-Date -Format yyyy-MM-dd-hh-mm-tt).txt
"=========================================================="
#Verify all require software is installed
"Checking for required Software on your system"
"=========================================================="
Check-PowerCLI10
#Check-Putty
#Check-WinSCP
#$ErrorActionPreference="SilentlyContinue"
$ErrorActionPreference="Continue"
"=========================================================="
" "
Write-Host "Get CIHS credentials" -ForegroundColor Yellow
$Global:Creds = Get-Credential -Credential $null

#Get-VCenter
$Global:VCName = $vCenter
Connect-VC
"----------------------------------------------------------"
"Get Target List"
$inputFile = Get-FileName $Global:WorkingFolder
"----------------------------------------------------------"
"Reading Target List"
$VMHostList = Read-TargetList $inputFile
"----------------------------------------------------------"
"Processing Target List"
ForEach ($VMhost in $VMHostList){
    $TargetDataStore = Get-TargetDataStore $VMhost
    "Target datastore for $VMhost is $TargetDataStore"
    #Generate random name for VM
    $vmName = "USBManager" + (Get-Random -Minimum 1000 -Maximum 9999)
    Create-VM $VMhost  $vmName $TargetDataStore
    "----------------------------------------------------------"    
    "Searching $VMHost for required ISO file"
    $IsoDS = Find-WinPEISO $VMhost
    "----------------------------------------------------------"
    If ($IsoDS -ne $Null){
        "Adding CD/DVD Drive to $vmName and mounting ISO"
        $cd = New-CDDrive -VM $vmName -IsoPath $IsoDS
        Set-CDDrive -CD $cd -StartConnected $True -Confirm:$False >$Null
    }
    Else {
        Write-Host "WinPE_x86.iso was not found on $VMHost" -ForegroundColor Red
        Write-Host "ISO will have to be manually uploaded to" -ForegroundColor Red
        Write-Host "the host $VMHost and mounted to $vmName" -ForegroundColor Red
    }
    "=========================================================="
}
Disconnect-VC
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null