param([string]$Link)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Client = Join-Path $Dir 'Client\RobloxPlayerBeta.exe'
$Studio = Join-Path $Dir 'Studio\RobloxStudioBeta.exe'
$Log = Join-Path $Dir 'launcher.log'
$AllowedHosts = @('local.roblox.com')

function Log($m) { try { Add-Content -Path $Log -Value ((Get-Date).ToString('s') + ' ' + $m) } catch {} }
function Fail($m) {
  Log ('ERROR ' + $m)
  [System.Windows.Forms.MessageBox]::Show($m, 'Sakora', 'OK', 'Error') | Out-Null
  exit 1
}

# Studio links (sakora-studio://) work without running the installer again: register them for this Windows user.
try {
  $k = 'HKCU:\Software\Classes\sakora-studio'
  if (-not (Test-Path "$k\shell\open\command")) {
    New-Item -Path "$k\shell\open\command" -Force | Out-Null
    Set-ItemProperty -Path $k -Name '(default)' -Value 'URL:Sakora Studio Protocol'
    Set-ItemProperty -Path $k -Name 'URL Protocol' -Value ''
    Set-ItemProperty -Path "$k\shell\open\command" -Name '(default)' -Value ('wscript.exe "' + (Join-Path $Dir 'launcher.vbs') + '" "%1"')
  }
} catch {}

$lower = ([string]$Link).ToLower()
if ($lower.StartsWith('sakora-studio:')) { $Mode = 'studio' }
elseif ($lower.StartsWith('sakora:')) { $Mode = 'play' }
else { Fail 'Press Play on the Sakora website to start a game.' }
if ($Mode -eq 'play' -and -not (Test-Path $Client)) { Fail 'Sakora is not installed correctly. Run SakoraSetup.exe again.' }

$query = ($Link -split '\?', 2)[1]
if (-not $query) { Fail 'Bad link.' }
$params = @{}
foreach ($pair in $query.Split('&')) {
  $kv = $pair.Split('=', 2)
  if ($kv.Count -eq 2) { $params[$kv[0]] = [System.Uri]::UnescapeDataString($kv[1]) }
}
$ticket = [string]$params['ticket']
$studioOpenOnly = ($Mode -eq 'studio' -and -not $ticket)
if (-not $studioOpenOnly -and $ticket -notmatch '^[A-Za-z0-9_-]{20,64}$') { Fail 'Invalid ticket. Go back to the site and try again.' }
try { $b = [System.Uri]$params['base'] } catch { Fail 'Invalid site address.' }
if ($b.Scheme -ne 'http' -and $b.Scheme -ne 'https') { Fail 'Invalid site address.' }
if ($AllowedHosts -notcontains $b.Authority) { Fail ('The site ' + $b.Authority + ' is not a Sakora server.') }
$base = $b.Scheme + '://' + $b.Authority

$Direct = 'http://sakorarevival.duckdns.org:8080'
function Test-Site($u) {
  try { Invoke-WebRequest -UseBasicParsing -Uri ($u + '/api/games') -TimeoutSec 8 | Out-Null; return $true } catch { return $false }
}
if (-not (Test-Site $base)) {
  if (Test-Site $Direct) {
    Log 'local connection broken, repairing'
    try {
      Start-Process powershell -Verb RunAs -Wait -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $Dir 'network.ps1') + '"'), 'install')
    } catch {
      Fail ('Sakora needs to fix its connection on this PC. Try again and click Yes when Windows asks.')
    }
    $fixed = $false
    for ($i = 0; $i -lt 5 -and -not $fixed; $i++) { Start-Sleep -Seconds 1; $fixed = Test-Site $base }
    if (-not $fixed) { Fail 'Sakora could not fix the connection on this PC. Run SakoraSetup.exe again.' }
    Log 'local connection repaired'
  } else {
    Fail 'The Sakora servers are offline right now. Try again in a few minutes.'
  }
}

# Keep the game (or Studio) up to date: when the server has a newer copy, download and swap it in first.
function Update-Part($what, $folder, $exeName, $zipName, $verName) {
  $VerFile = Join-Path $Dir $verName
  $target = Join-Path $Dir $folder
  $remoteVer = ''
  try { $remoteVer = ([string](Invoke-WebRequest -UseBasicParsing -Uri ($base + '/setup/' + $verName) -TimeoutSec 10).Content).Trim() } catch {}
  $localVer = ''
  if (Test-Path $VerFile) { try { $localVer = ([string](Get-Content $VerFile -Raw)).Trim() } catch {} }
  $missing = -not (Test-Path (Join-Path $target $exeName))
  if (-not $missing -and (-not $remoteVer -or $remoteVer -eq $localVer)) { return }
  Log ('updating ' + $folder + ' ' + $localVer + ' -> ' + $remoteVer)
  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'Sakora'; $form.Width = 360; $form.Height = 120; $form.StartPosition = 'CenterScreen'
  $form.FormBorderStyle = 'FixedDialog'; $form.ControlBox = $false; $form.TopMost = $true
  $label = New-Object System.Windows.Forms.Label
  $label.Text = ($(if ($missing) { 'Installing ' } else { 'Updating ' }) + $what + ', please wait...'); $label.AutoSize = $false; $label.Dock = 'Fill'; $label.TextAlign = 'MiddleCenter'
  $form.Controls.Add($label); $form.Show(); [System.Windows.Forms.Application]::DoEvents()
  $tmpZip = Join-Path $env:TEMP ($folder + '-update.zip')
  $newDir = Join-Path $Dir ($folder + '.new')
  try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -UseBasicParsing -Uri ($base + '/setup/' + $zipName) -OutFile $tmpZip -TimeoutSec 900
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path $newDir) { Remove-Item $newDir -Recurse -Force }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tmpZip, $newDir)
    if (-not (Test-Path (Join-Path $newDir $exeName))) { throw 'the download was incomplete' }
    $exeBase = [System.IO.Path]::GetFileNameWithoutExtension($exeName)
    Get-Process $exeBase -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($target) } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    Rename-Item $newDir $folder
    if ($remoteVer) { Set-Content -Path $VerFile -Value $remoteVer }
    Log ($folder + ' updated')
  } catch {
    Log ($folder + ' update failed: ' + $_.Exception.Message)
    if (Test-Path $newDir) { Remove-Item $newDir -Recurse -Force -ErrorAction SilentlyContinue }
  } finally {
    Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
    $form.Close()
  }
}

if ($Mode -eq 'studio') {
  Update-Part 'Sakora Studio' 'Studio' 'RobloxStudioBeta.exe' 'SakoraStudio.zip' 'studio-version.txt'
  if (-not (Test-Path $Studio)) { Fail 'Installing Sakora Studio failed. Check your connection and try again.' }
  if ($studioOpenOnly) {
    Log 'open studio'
    Start-Process -FilePath $Studio -WorkingDirectory (Split-Path -Parent $Studio)
    exit 0
  }
  try {
    $r = Invoke-RestMethod -Uri ($base + '/api/studio/redeem') -Method Post -ContentType 'application/json' -Body (@{ ticket = $ticket } | ConvertTo-Json) -TimeoutSec 15
  } catch {
    Fail ('Could not reach the Sakora server.' + [Environment]::NewLine + $_.Exception.Message)
  }
  if (-not $r.ok) { Fail ([string]$r.message) }
  $auth = [string]$r.authTicket
  if ($auth -notmatch '^[A-Za-z0-9_-]{20,64}$') { Fail 'The server sent an invalid login ticket.' }
  foreach ($u in @([string]$r.authUrl, [string]$r.scriptUrl)) {
    try { $x = [System.Uri]$u } catch { Fail 'The server sent a bad address.' }
    if ($x.Authority -ne $b.Authority) { Fail 'The server sent an address for a different site.' }
  }
  Log ('edit place=' + [int]$r.placeId)
  Start-Process -FilePath $Studio -ArgumentList @('-url', [string]$r.authUrl, '-ticket', $auth, '-script', ('"' + [string]$r.scriptUrl + '"')) -WorkingDirectory (Split-Path -Parent $Studio)
  exit 0
}

Update-Part 'Sakora' 'Client' 'RobloxPlayerBeta.exe' 'SakoraClient.zip' 'client-version.txt'
if (-not (Test-Path $Client)) { Fail 'Updating Sakora failed. Run SakoraSetup.exe again.' }

try {
  $r = Invoke-RestMethod -Uri ($base + '/api/launch/redeem') -Method Post -ContentType 'application/json' -Body (@{ ticket = $ticket } | ConvertTo-Json) -TimeoutSec 15
} catch {
  Fail ('Could not reach the Sakora server. Is it online, and did SakoraSetup finish?' + [Environment]::NewLine + $_.Exception.Message)
}
if (-not $r.ok) { Fail ([string]$r.message) }
$placeId = [int]$r.placeId
$auth = [string]$r.authTicket
if ($auth -notmatch '^[A-Za-z0-9_-]{20,64}$') { Fail 'The server sent an invalid login ticket.' }

try {
  $pl = Invoke-RestMethod -Uri ($base + '/game/placelauncher.ashx?request=RequestGame&placeId=' + $placeId + '&ticket=' + $auth) -TimeoutSec 90
} catch {
  Fail ('The game server did not answer.' + [Environment]::NewLine + $_.Exception.Message)
}
if ($pl.status -ne 2 -or -not $pl.joinScriptUrl) { Fail ('The game did not start: ' + [string]$pl.message) }
$j = [System.Uri]$pl.joinScriptUrl
if ($j.Authority -ne $b.Authority) { Fail 'The server sent a join address for a different site.' }

$clientArgs = @('--play', '-a', ($base + '/Login/Negotiate.ashx'), '-t', $auth, '-j', [string]$pl.joinScriptUrl, '-b', '0')
Log ('launch place=' + $placeId)
Start-Process -FilePath $Client -ArgumentList $clientArgs -WorkingDirectory (Split-Path -Parent $Client)
