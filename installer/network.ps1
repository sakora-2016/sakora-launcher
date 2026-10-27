param([string]$Mode = 'install')
$site = 'sakorarevival.duckdns.org'
$webPort = 8080
$names = @('local.roblox.com', 'versioncompatibility.api.roblox.com', 'clientsettings.api.roblox.com', 'sak.roblox.com', 'api.roblox.com')
$hosts = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'

$lines = @(Get-Content $hosts -ErrorAction SilentlyContinue | Where-Object {
  $l = $_
  -not ($names | Where-Object { $l -match [regex]::Escape($_) })
})
if ($Mode -eq 'install') { $lines += ('127.0.0.2 ' + ($names -join ' ') + ' # sakora') }
$current = @(Get-Content $hosts -ErrorAction SilentlyContinue)
if (($current -join "`n") -ne ($lines -join "`n")) {
  $ok = $false
  for ($i = 0; $i -lt 5 -and -not $ok; $i++) {
    try {
      $f = Get-Item $hosts -ErrorAction SilentlyContinue
      if ($f -and $f.IsReadOnly) { $f.IsReadOnly = $false }
      [System.IO.File]::WriteAllLines($hosts, [string[]]$lines, [System.Text.Encoding]::ASCII)
      $ok = $true
    } catch { Start-Sleep -Milliseconds 500 }
  }
  if (-not $ok) { Write-Output 'Could not update the hosts file (it may be locked by antivirus).' }
}

netsh interface portproxy delete v4tov4 listenaddress=127.0.0.2 listenport=80 2>&1 | Out-Null
if ($Mode -eq 'install') {
  # Windows' own web listener (HTTP.sys) can grab port 80 on every address and block 127.0.0.2:80.
  # Keep it on 127.0.0.1 only, so Sakora's 127.0.0.2:80 forward always works.
  $httpSysAll = Get-NetTCPConnection -LocalPort 80 -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.OwningProcess -eq 4 -and ($_.LocalAddress -eq '0.0.0.0' -or $_.LocalAddress -eq '::') }
  if ($httpSysAll) {
    $listen = (netsh http show iplisten) -join ' '
    if ($listen -notmatch '127\.0\.0\.1') { netsh http add iplisten ipaddress=127.0.0.1 | Out-Null }
  }
  Set-Service iphlpsvc -StartupType Automatic
  netsh interface portproxy add v4tov4 listenaddress=127.0.0.2 listenport=80 connectaddress=$site connectport=$webPort | Out-Null
  # Restart the forwarding service so it looks up the server address fresh instead of using a stale one.
  Restart-Service iphlpsvc -Force -ErrorAction SilentlyContinue
  Start-Service iphlpsvc -ErrorAction SilentlyContinue
}
ipconfig /flushdns | Out-Null
