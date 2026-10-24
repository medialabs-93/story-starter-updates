# Story Starter: first install on Windows, from one line, with no browser.
#
#   Public version (once one is published):
#     iex "& { $(irm https://medialabs-93.github.io/story-starter-updates/install.ps1) }"
#   Developer version:
#     iex "& { $(irm https://medialabs-93.github.io/story-starter-updates/install.ps1) } -Channel developer"
#
# What it does: reads the update feed over HTTPS, downloads the installer for the channel straight
# from the Story Starter updates releases with PowerShell (so Edge and SmartScreen are not involved),
# checks its size and SHA-256 against the feed, and starts it. After that one install the app updates
# itself, inside the app, with no browser. Nothing is installed without the installer's own wizard.
#
# Honest limits: the checksum comes from the same GitHub account as the file, so this protects against
# a damaged or swapped download, not against a compromised account. (The app's own updater also checks
# an Ed25519 signature made with a key that is not on GitHub.)
param(
  [ValidateSet('stable', 'developer')][string]$Channel = 'stable',
  [switch]$NoStart,                    # download and check only; do not start the installer
  [string]$FeedUrl = 'https://medialabs-93.github.io/story-starter-updates/latest.json',
  [string]$AllowedPrefix = 'https://github.com/medialabs-93/story-starter-updates/releases/download/'
)
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

# Not `exit`: run through `iex` in a person's own window, exit would close the window before the message can be read.
function Fail([string]$message) { throw "Story Starter installer: $message" }

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { Fail 'this installer is for Windows. On a Mac use install.sh.' }

Write-Host "Looking up the newest Story Starter ($Channel) ..."
$stamp = [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() / 60)
$separator = if ($FeedUrl.Contains('?')) { '&' } else { '?' }
try {
  $feed = Invoke-RestMethod -Uri ($FeedUrl + $separator + 't=' + $stamp) -UseBasicParsing
} catch {
  Fail "could not read the update information ($($_.Exception.Message)). Check your internet connection."
}
$entry = $feed.channels.$Channel
if ($null -eq $entry) { Fail "no '$Channel' version has been published yet." }
$download = $entry.downloads.windows
if ($null -eq $download -or [string]::IsNullOrEmpty($download.url)) { Fail "the '$Channel' release has no Windows installer." }

$url = [string]$download.url
$sha = ([string]$download.sha256).ToLower()
$size = [int64]$download.size
if (-not $url.StartsWith($AllowedPrefix)) { Fail 'the download address is not one of the Story Starter releases, so it was not used.' }
if ($url -match '\.\.' -or $url.Contains('?') -or $url.Contains('#')) { Fail 'the download address looks wrong, so it was not used.' }
if ($sha -notmatch '^[0-9a-f]{64}$') { Fail 'the update information has no checksum for the installer, so it was not used.' }

$name = [IO.Path]::GetFileName(([Uri]$url).AbsolutePath)
$folder = Join-Path $env:TEMP 'StoryStarterInstall'
New-Item -ItemType Directory -Force $folder | Out-Null
$file = Join-Path $folder $name

Write-Host ("Downloading Story Starter {0} build {1} ({2:N0} MB) ..." -f $entry.version, $entry.build, ($size / 1MB))
try {
  Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
} catch {
  Remove-Item $file -Force -ErrorAction SilentlyContinue
  Fail "the download failed ($($_.Exception.Message))."
}

$got = (Get-FileHash $file -Algorithm SHA256).Hash.ToLower()
if ((Get-Item $file).Length -ne $size -or $got -ne $sha) {
  Remove-Item $file -Force -ErrorAction SilentlyContinue
  Fail 'the downloaded file did not match its checksum, so it was deleted and nothing was installed.'
}
Write-Host 'Checked: the file matches the published checksum.'

if ($NoStart) {
  Write-Host "Downloaded and checked: $file  (not started: -NoStart)"
  return
}
Write-Host 'Starting the installer. Windows may ask for permission; choose "Install for me only" to avoid that for updates.'
Start-Process -FilePath $file
