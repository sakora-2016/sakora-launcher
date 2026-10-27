Unicode true
!define NAME "Sakora"
!define SITE "http://sakorarevival.duckdns.org:8080"
!define ZIPURL "${SITE}/setup/SakoraClient.zip"
!define STUDIOURL "${SITE}/setup/SakoraStudio.zip"

Name "${NAME}"
OutFile "SakoraSetup.exe"
InstallDir "$LOCALAPPDATA\Sakora"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
ShowInstDetails show
BrandingText "Sakora"

VIProductVersion "1.0.0.0"
VIFileVersion "1.0.0.0"
VIAddVersionKey "ProductName" "Sakora"
VIAddVersionKey "FileDescription" "Sakora Setup"
VIAddVersionKey "CompanyName" "Sakora"
VIAddVersionKey "LegalCopyright" "Sakora fan project"
VIAddVersionKey "FileVersion" "1.0.0.0"
VIAddVersionKey "ProductVersion" "1.0.0.0"

Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Install"
  SetOutPath "$INSTDIR"
  File "launcher.ps1"
  File "network.ps1"
  File "launcher.vbs"
  File "download.ps1"

  DetailPrint "Downloading Sakora (this can take a few minutes)..."
  Delete "$TEMP\SakoraClient.zip"
  nsExec::ExecToLog 'powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$INSTDIR\download.ps1" "${ZIPURL}" "$TEMP\SakoraClient.zip"'
  Pop $0
  StrCmp $0 "0" +3
    MessageBox MB_ICONSTOP "Could not download Sakora. Check that the Sakora server is online and try again. (Details are in the list above.)"
    Abort

  DetailPrint "Installing (unpacking files)..."
  RMDir /r "$INSTDIR\Client"
  nsExec::ExecToLog 'powershell -NoProfile -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory($\'$TEMP\SakoraClient.zip$\', $\'$INSTDIR\Client$\')"'
  Pop $0
  Delete "$TEMP\SakoraClient.zip"
  IfFileExists "$INSTDIR\Client\RobloxPlayerBeta.exe" +3
    MessageBox MB_ICONSTOP "Unpacking Sakora failed. Try running the installer again."
    Abort
  nsExec::ExecToLog 'powershell -NoProfile -Command "try { ([string](Invoke-WebRequest -UseBasicParsing -Uri $\'${SITE}/setup/client-version.txt$\' -TimeoutSec 20).Content).Trim() | Set-Content -Path $\'$INSTDIR\client-version.txt$\' } catch {}"'
  Pop $0

  DetailPrint "Downloading Sakora Studio..."
  Delete "$TEMP\SakoraStudio.zip"
  nsExec::ExecToLog 'powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$INSTDIR\download.ps1" "${STUDIOURL}" "$TEMP\SakoraStudio.zip"'
  Pop $0
  StrCmp $0 "0" 0 studio_done
    DetailPrint "Installing Sakora Studio..."
    RMDir /r "$INSTDIR\Studio"
    nsExec::ExecToLog 'powershell -NoProfile -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory($\'$TEMP\SakoraStudio.zip$\', $\'$INSTDIR\Studio$\')"'
    Pop $0
    nsExec::ExecToLog 'powershell -NoProfile -Command "try { ([string](Invoke-WebRequest -UseBasicParsing -Uri $\'${SITE}/setup/studio-version.txt$\' -TimeoutSec 20).Content).Trim() | Set-Content -Path $\'$INSTDIR\studio-version.txt$\' } catch {}"'
    Pop $0
  studio_done:
  Delete "$TEMP\SakoraStudio.zip"

  DetailPrint "Setting up the connection..."
  nsExec::ExecToLog 'powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$INSTDIR\network.ps1" install'
  Pop $0

  WriteRegStr HKLM "Software\Classes\sakora" "" "URL:Sakora Protocol"
  WriteRegStr HKLM "Software\Classes\sakora" "URL Protocol" ""
  WriteRegStr HKLM "Software\Classes\sakora\DefaultIcon" "" "$INSTDIR\Client\RobloxPlayerBeta.exe,0"
  WriteRegStr HKLM "Software\Classes\sakora\shell\open\command" "" 'wscript.exe "$INSTDIR\launcher.vbs" "%1"'

  WriteRegStr HKLM "Software\Classes\sakora-studio" "" "URL:Sakora Studio Protocol"
  WriteRegStr HKLM "Software\Classes\sakora-studio" "URL Protocol" ""
  WriteRegStr HKLM "Software\Classes\sakora-studio\DefaultIcon" "" "$INSTDIR\Studio\RobloxStudioBeta.exe,0"
  WriteRegStr HKLM "Software\Classes\sakora-studio\shell\open\command" "" 'wscript.exe "$INSTDIR\launcher.vbs" "%1"'

  Delete "$DESKTOP\Sakora.url"
  CreateShortCut "$DESKTOP\Sakora Studio.lnk" "$INSTDIR\Studio\RobloxStudioBeta.exe" "" "$INSTDIR\Studio\RobloxStudioBeta.exe" 0

  DetailPrint "Keeping the connection fixed after restarts..."
  nsExec::ExecToLog 'schtasks /Create /TN "Sakora Connection" /TR "powershell -NoProfile -ExecutionPolicy RemoteSigned -File \"$INSTDIR\network.ps1\" install" /SC ONSTART /DELAY 0000:30 /RU SYSTEM /RL HIGHEST /F'
  Pop $0

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Sakora" "DisplayName" "Sakora"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Sakora" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Sakora" "DisplayIcon" "$INSTDIR\Client\RobloxPlayerBeta.exe"

  MessageBox MB_YESNO "Sakora is installed! Open the website now?" IDNO +2
    ExecShell "open" "${SITE}/"
SectionEnd

Section "Uninstall"
  nsExec::ExecToLog 'schtasks /Delete /TN "Sakora Connection" /F'
  Pop $0
  nsExec::ExecToLog 'powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$INSTDIR\network.ps1" uninstall'
  Pop $0
  DeleteRegKey HKLM "Software\Classes\sakora"
  DeleteRegKey HKLM "Software\Classes\sakora-studio"
  DeleteRegKey HKCU "Software\Classes\sakora-studio"
  Delete "$DESKTOP\Sakora Studio.lnk"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Sakora"
  Delete "$DESKTOP\Sakora.url"
  RMDir /r "$INSTDIR"
SectionEnd
