#start-osd cloud

#Thanks to Michiel from interstellar for these variables
#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$Product = (Get-MyComputerProduct)
$Model = (Get-MyComputerModel)
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '24H2' #Used to Determine Driver Pack
$OSName = 'Windows 11 24H2 x64'
$OSEdition = 'Enterprise'
$OSActivation = 'Retail'
$OSLanguage = 'en-us'


#Set OSDCloud Vars
$Global:MyOSDCloud = [ordered]@{
    Restart = [bool]$False
    RecoveryPartition = [bool]$true
    OEMActivation = [bool]$True
    WindowsUpdate = [bool]$true
    WindowsUpdateDrivers = [bool]$true
    WindowsDefenderUpdate = [bool]$true
    SetTimeZone = [bool]$true
    SkipClearDisk = [bool]$False
    ClearDiskConfirm = [bool]$False
    ShutdownSetupComplete = [bool]$false
    SyncMSUpCatDriverUSB = [bool]$true
    CheckSHA1 = [bool]$true
}

#Used to Determine Driver Pack
$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}
$testHPIASupport = $true
if (TestHPIASupport){
    #$Global:MyOSDCloud.DevMode = [bool]$True
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
    {$Global:MyOSDCloud.HPIAALL = [bool]$true}
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true
}
if ($Manufacturer -match "Microsoft") {
    #Updating Microsoft Surface Driver catalog
    Write-Host "Updating Microsoft Surface Driver catalog"
    Invoke-RestMethod "https://raw.githubusercontent.com/chield/OSDCloud/main/Update-OSDCloudSurfaceDriverCatalogJustInTime.ps1" | Invoke-Expression
    Update-OSDCloudSurfaceDriverCatalogJustInTime.ps1 -UpdateDriverPacksJson
}

#write variables to console
Write-Output $Global:MyOSDCloud

#download answer file from github https://raw.githubusercontent.com/MikeFeith/Interstellar-OSD/refs/heads/main/Emergis/Autounattend.xml -outfile "C:\Windows\panther\unattend\unattend.xml"

Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

$UnattendXml = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MikeFeith/Interstellar-OSD/refs/heads/main/Emergis/Autounattend.xml" -UseBasicParsing | Select-Object -ExpandProperty Content

$PantherUnattendPath = 'C:\Windows\Panther\'
if (-NOT (Test-Path $PantherUnattendPath)) {
    New-Item -Path $PantherUnattendPath -ItemType Directory -Force | Out-Null
}
$SpecUnattendPath = Join-Path $PantherUnattendPath 'Invoke-OSDSpecialize.xml'


Write-Host -ForegroundColor Cyan "Set Unattend.xml at $SpecUnattendPath"
$UnattendXml | Out-File -FilePath $SpecUnattendPath -Encoding utf8

Write-Host -ForegroundColor Cyan 'Use-WindowsUnattend'
Use-WindowsUnattend -Path 'C:\' -UnattendPath $SpecUnattendPath -Verbose

#=======================================================================
#   Restart-Computer
#=======================================================================
Write-Host  -ForegroundColor Green "Restarting in 15 seconds!"
Start-Sleep -Seconds 600