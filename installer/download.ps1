param([string]$Url, [string]$Dest)
$ErrorActionPreference = 'Stop'
try {
  $req = [System.Net.HttpWebRequest]::Create($Url)
  $req.Timeout = 60000
  $req.ReadWriteTimeout = 600000
  $req.UserAgent = 'SakoraSetup'
  $resp = $req.GetResponse()
  $total = $resp.ContentLength
  $in = $resp.GetResponseStream()
  $out = [System.IO.File]::Create($Dest)
  $buf = New-Object byte[] 65536
  $read = 0
  $last = -5
  while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
    $out.Write($buf, 0, $n)
    $read += $n
    if ($total -gt 0) {
      $p = [int](($read * 100) / $total)
      if ($p -ge $last + 2) { Write-Output ("Downloading... " + $p + "%"); $last = $p }
    }
  }
  $out.Close(); $in.Close(); $resp.Close()
  Write-Output "Downloading... 100%"
  exit 0
} catch {
  Write-Output $_.Exception.Message
  exit 1
}
