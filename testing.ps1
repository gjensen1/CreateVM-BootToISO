Connect-VIServer -Server ctsbikdcapmdw09.cihs.ad.gov.on.ca
$HostTargets = @(
                "142.145.180.11")

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
        Write-Host "ISO not found where we expected it searching all DataStores" -ForegroundColor Yellow
        ForEach ($datastore in $datastores){
            new-psdrive -location $datastore -Name DS -PSProvider VimDatastore -Root "\" > $null
            $isoFound = dir ds:\ -Recurse -Include WinPE_x86.iso
            #check if isoFound is not null then capture the DatastoreFullPath
            If ($isoFound -ne $null){
                $ISOPath = $isoFound.DatastoreFullPath
            }
            Remove-PSDrive -Name ds -Confirm:$false
        }
        
    }
    Return $ISOPath
}
#***************************
# End-Function Find-WinPEISO
#***************************

ForEach ($VMhost in $HostTargets){
    #$TargetDataStores = Get-TargetDataStore $VMhost
    #"Target datastores for $VMhost is $TargetDataStores"
    #Generate random name for VM
    #$vmName = "USBManager" + (Get-Random -Minimum 1000 -Maximum 9999)
    #Create-VM $VMhost  $vmName $TargetDataStore
    "Checking $VMHost for required ISO file"
    $IsoDS = Find-WinPEISO $VMhost
    $IsoDS
    "----------------------------------------------------------"
}


