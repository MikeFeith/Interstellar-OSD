#start-osd cloud

#Thanks to Michiel from interstellar for helping me with this script
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
if ($Manufacturer -match "HP") {
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

$PantherUnattendPath = 'C:\Windows\Panther\Unattend\'
if (-NOT (Test-Path $PantherUnattendPath)) {
    New-Item -Path $PantherUnattendPath -ItemType Directory -Force | Out-Null
}
$SpecUnattendPath = Join-Path $PantherUnattendPath 'unattend.xml'


Write-Host -ForegroundColor Cyan "Set Unattend.xml at $SpecUnattendPath"
$UnattendXml | Out-File -FilePath $SpecUnattendPath -Encoding utf8

Write-Host -ForegroundColor Cyan 'Use-WindowsUnattend'
Use-WindowsUnattend -Path 'C:\' -UnattendPath $SpecUnattendPath -Verbose

#copy the local scripts to the panther folder
$localscriptsosdfolder = "D:\fblocalscripts"
$localscriptfolderPath = "C:\Windows\Panther\fblocalscripts"
if (-NOT (Test-Path "$localscriptfolderPath")) {
    New-Item -Path "$localscriptfolderPath" -ItemType Directory -Force | Out-Null
}
Copy-Item -Path $localscriptsosdfolder\* -Destination $localscriptfolderPath\ -Recurse -Force
Install-Script -Name Get-WindowsAutoPilotInfo -Force -AcceptLicense -Scope AllUsers -SkipPublisherCheck
install-module -Name AzureAD -Force -AcceptLicense -Scope AllUsers -SkipPublisherCheck
install-module -Name WindowsAutopilotIntune -Force -AcceptLicense -Scope AllUsers -SkipPublisherCheck
Start-Sleep -Seconds 15
#wait for user input to continue
Write-Host -ForegroundColor Yellow "Press any key to continue"
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

#=======================================================================
#   Restart-Computer
#=======================================================================
Write-Host  -ForegroundColor Green "Restarting in 15 seconds!"
Start-Sleep -Seconds 15
# powershell gui to reboot pc once the button is clicked