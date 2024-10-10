#start-osd cloud
#used command: Edit-OSDCloudWinPE -Add7Zip -PSModuleInstall AzureAD, WindowsAutopilotIntune -Starturl "https://raw.githubusercontent.com/MikeFeith/Interstellar-OSD/refs/heads/main/Emergis/starturl.ps1" -wallpaper "C:\temp\emergis.jpg" -clouddriver HP,IntelNet

#=======================================================================
#   OSDCLOUD Definitions
#=======================================================================
$Product = (Get-MyComputerProduct)
$Model = (Get-MyComputerModel)
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '23H2' #Used to Determine Driver Pack
$OSName = 'Windows 11 23H2 x64'
$OSEdition = 'Enterprise'
$OSActivation = 'Volume'
$OSLanguage = 'nl-nl'

#=======================================================================
#   OSDCLOUD VARS
#=======================================================================
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

#=======================================================================
#   Specific Driver Pack
#=======================================================================
$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}
$UseHPIA = $true
if ($Manufacturer -match "HP" -and $UseHPIA -eq $true) {
    #$Global:MyOSDCloud.DevMode = [bool]$True
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
    {$Global:MyOSDCloud.HPIAALL = [bool]$true}
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true
}

#=======================================================================
#   Write OSDCloud VARS to Console
#=======================================================================
Write-Output $Global:MyOSDCloud

#=======================================================================
#   Start OSDCloud installation
#=======================================================================
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

#=======================================================================
#   OSDCloud Specialize
#=======================================================================
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
                    <Description>Add to autopilot</Description>
                    <Path>powershell.exe -ExecutionPolicy Bypass -file "C:\Windows\Panther\fblocalscripts\Autopilot\Menu.ps1" -Verbose</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Description>Remove OSDCloud Temp Files</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Remove-Item -Path C:\OSDCloud -Recurse</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>4</Order>
                    <Description>Remove localscript Files</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Remove-Item -Path C:\Windows\Panther\fblocalscripts -Recurse</Path>
                </RunSynchronousCommand>             
            </RunSynchronous>
        </component>
    </settings>    
</unattend>
'@

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

#=======================================================================
#   OSDCLOUD Specialize Scripts and modules
#=======================================================================
$localscriptsosdfolder = "D:\fblocalscripts"
$localscriptfolderPath = "C:\Windows\Panther\fblocalscripts"
if (-NOT (Test-Path "$localscriptfolderPath")) {
    New-Item -Path "$localscriptfolderPath" -ItemType Directory -Force | Out-Null
}
Copy-Item -Path $localscriptsosdfolder\* -Destination $localscriptfolderPath\ -Recurse -Force
install-module -Name AzureAD -Force -AcceptLicense -Scope AllUsers -SkipPublisherCheck
install-module -Name WindowsAutopilotIntune -Force -AcceptLicense -Scope AllUsers -SkipPublisherCheck

#=======================================================================
#   DEVELOPER USER CONFIRMATION TO REBOOT
#=======================================================================
Start-Sleep -Seconds 15
#wait for user input to continue
Write-Host -ForegroundColor Yellow "Press any key to reboot the device"
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

#=======================================================================
#   REBOOT DEVICE
#=======================================================================
Write-Host  -ForegroundColor Green "Restarting now!"
Restart-Computer -Force