# XyRDP-VN — Thư viện dùng chung (tiếng Việt)
$ErrorActionPreference = 'Continue'
$global:XyTag = 'XyRDP-VN'

function Log {
  param([string]$Msg)
  $ts = Get-Date -Format 'HH:mm:ss'
  Write-Host "[$ts][$XyTag] $Msg"
}

function Lay-CauHinh {
  $dir = 'C:\XyRDP\out'
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $f = Join-Path $dir 'trang-thai.json'
  if (Test-Path $f) {
    try { return Get-Content $f -Raw | ConvertFrom-Json } catch { }
  }
  return [pscustomobject]@{}
}

function CapNhat-TrangThai {
  param([hashtable]$Them)
  $dir = 'C:\XyRDP\out'
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  $f = Join-Path $dir 'trang-thai.json'
  $hienTai = Lay-CauHinh
  $hash = @{}
  if ($hienTai) {
    $hienTai.PSObject.Properties | ForEach-Object { $hash[$_.Name] = $_.Value }
  }
  foreach ($k in $Them.Keys) { $hash[$k] = $Them[$k] }
  $hash['cap_nhat'] = (Get-Date).ToUniversalTime().ToString('o')
  ($hash | ConvertTo-Json -Depth 8) | Set-Content -Path $f -Encoding UTF8
  return $hash
}

function Tai-Tep {
  param([string]$Url, [string]$Dich, [int]$TimeoutGiay = 120)
  try {
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add('User-Agent', 'XyRDP-VN/1.0')
    $wc.DownloadFile($Url, $Dich)
    return (Test-Path $Dich)
  } catch {
    Log "Tải thất bại: $Url — $($_.Exception.Message)"
    return $false
  }
}

function Chay-LenhGioiHan {
  param([string]$File, [string[]]$ArgsList, [int]$Giay = 90)
  $out = Join-Path $env:TEMP ([guid]::NewGuid().ToString('N') + '.out')
  $err = "$out.err"
  try {
    $p = Start-Process -FilePath $File -ArgumentList $ArgsList -PassThru -NoNewWindow `
      -RedirectStandardOutput $out -RedirectStandardError $err
    if (-not $p.WaitForExit($Giay * 1000)) {
      $p | Stop-Process -Force -ErrorAction SilentlyContinue
      throw "Lệnh vượt quá thời gian chờ (${Giay}s)"
    }
    $p.WaitForExit()
    return @{
      code  = $p.ExitCode
      text  = (Get-Content $out -Raw -ErrorAction SilentlyContinue)
      error = (Get-Content $err -Raw -ErrorAction SilentlyContinue)
    }
  } finally {
    Remove-Item $out, $err -Force -ErrorAction SilentlyContinue
  }
}
