#start-osd cloud



Start-OSDCloud -OSName 'Windows 11 24H2 x64' -OSActivation Volume -OSLanguage nl-nl -OSEdition Enterprise
#copy the unattend xml from the usb  to C:\Windows\panther\unattend\unattend.xml
#Copy-Item -Path '' -Destination 'C:\Windows\panther\unattend\unattend.xml' -Force

