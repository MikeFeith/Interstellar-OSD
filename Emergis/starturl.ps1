#start-osd cloud

#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$Product = (Get-MyComputerProduct)
$Model = (Get-MyComputerModel)
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '24H2' #Used to Determine Driver Pack
$OSName = 'Windows 11 24H2 x64'
$OSEdition = 'Enterprise'
$OSActivation = 'Volume'
$OSLanguage = 'en-us'


#Set OSDCloud Vars
$Global:MyOSDCloud = [ordered]@{
    Restart = [bool]$False
    RecoveryPartition = [bool]$true
    OEMActivation = [bool]$true
    WindowsUpdate = [bool]$true
    WindowsUpdateDrivers = [bool]$true
    WindowsDefenderUpdate = [bool]$true
    SetTimeZone = [bool]$true
    SkipClearDisk = [bool]$false
    ClearDiskConfirm = [bool]$false
    ShutdownSetupComplete = [bool]$false
    SyncMSUpCatDriverUSB = [bool]$true
    CheckSHA1 = [bool]$true
}

#Used to Determine Driver Pack
$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}
$UseHPIA = $false
$UseMSDriverPack = $false
if ($Manufacturer -match "HP" -and $UseHPIA -eq $true) {
    #$Global:MyOSDCloud.DevMode = [bool]$True
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
    {$Global:MyOSDCloud.HPIAALL = [bool]$true}
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true
}
if ($Manufacturer -match "Microsoft" -and $UseMSDriverPack -eq $true) {
    #Updating Microsoft Surface Driver catalog
    Write-Host "Updating Microsoft Surface Driver catalog"
    Invoke-RestMethod "https://raw.githubusercontent.com/chield/OSDCloud/main/Update-OSDCloudSurfaceDriverCatalogJustInTime.ps1" | Invoke-Expression
    Update-OSDCloudSurfaceDriverCatalogJustInTime.ps1 -UpdateDriverPacksJson
}

#write variables to console
Write-Output $Global:MyOSDCloud

#download answer file from github https://raw.githubusercontent.com/MikeFeith/Interstellar-OSD/refs/heads/main/Emergis/Autounattend.xml -outfile "C:\Windows\panther\unattend\unattend.xml"
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

Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

#////////////////////////////////////////////////////////////////////////
Set-OSDCloudUnattendSpecialize


$UnattendXml = @'
<?xml version='1.0' encoding='utf-8'?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>OSDCloud Specialize</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Invoke-OSDSpecialize -Verbose</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                  <Order>2</Order>
                  <Description>Pop up to confirm unattend is working</Description>
                  <Path>powershell.exe -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Unattend is working')"</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                  <Order>3</Order>
                  <Description>Add to autopilot</Description>
                  <Path>powershell.exe -ExecutionPolicy Bypass -file "C:\Windows\Panther\fblocalscripts\Autopilot\Menu.ps1"</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>4</Order>
                    <Description>Remove OSDCloud Temp Files</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Remove-Item -Path C:\OSDCloud -Recurse</Path>
                </RunSynchronousCommand>          
            </RunSynchronous>
        </component>
    </settings>    
</unattend>
'@
#================================================================================================
#   Set Unattend.xml
#================================================================================================
$PantherUnattendPath = 'C:\Windows\Panther'
if (-NOT (Test-Path $PantherUnattendPath)) {
    New-Item -Path $PantherUnattendPath -ItemType Directory -Force | Out-Null
}
$UnattendPath = Join-Path $PantherUnattendPath 'Invoke-OSDSpecialize.xml'
$UnattendXml | Out-File -FilePath $UnattendPath -Encoding utf8

Write-Verbose "Setting Unattend in Offline Registry"
Invoke-Exe reg load HKLM\TempSYSTEM "C:\Windows\System32\Config\SYSTEM"
Invoke-Exe reg add HKLM\TempSYSTEM\Setup /v UnattendFile /d "C:\Windows\Panther\Invoke-OSDSpecialize.xml" /f
Invoke-Exe reg unload HKLM\TempSYSTEM

#////////////////////////////////////////////////////////////////////////


exit

#copy the local scripts to the panther folder
$localscriptsosdfolder = "D:\fblocalscripts"
$localscriptfolderPath = "C:\Windows\Panther\fblocalscripts"
if (-NOT (Test-Path "$localscriptfolderPath")) {
    New-Item -Path "$localscriptfolderPath" -ItemType Directory -Force | Out-Null
}
Copy-Item -Path $localscriptsosdfolder\* -Destination $localscriptfolderPath\ -Recurse -Force
Install-Script -Name Get-WindowsAutoPilotInfo -Force -AcceptLicense -Scope AllUsers
install-module -Name AzureAD -Force -AcceptLicense -Scope AllUsers -SkipPublisherCheck
install-module -Name WindowsAutopilotIntune -Force -AcceptLicense -Scope AllUsers -SkipPublisherCheck
Start-Sleep -Seconds 15
#wait for user input to continue
Write-Host -ForegroundColor Yellow "Press any key to reboot the device"
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

#=======================================================================
#   Restart-Computer
#=======================================================================
Write-Host  -ForegroundColor Green "Restarting now!"
Restart-Computer -Force