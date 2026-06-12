# Video Orientation Sorter

Automatically sort video files into **horizontal** and **vertical** folders based on their resolution metadata. This guide walks you through installing the required dependencies (NuGet Provider + FFmpeg/FFprobe) and then running the sorting script — all without needing administrator privileges.

---

## Table of Contents

1. [Prerequisites]
2. [Step 1 — Install NuGet Package Provider](
3. [Step 2 — Install FFmpeg / FFprobe]
4. [Step 3 — Sort Videos by Orientation]
5. [Quick Start (One-Click Script)]
6. [Supported Video Formats]
7. [How It Works]
8. [Troubleshooting]

---

## Prerequisites

- **Windows PowerShell 5.1+** or **PowerShell 7+** (cross-platform)
- **Internet connection** for downloading packages
- **No administrator rights required** — everything installs into your user profile

---

## Step 1 — Install NuGet Package Provider

This step ensures the NuGet provider is available for PowerShell's package management. It downloads the official Microsoft DLL directly into your user profile — no admin elevation needed.

```powershell
# 1. Force TLS 1.2 to secure the connection
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Use a safe, user-level directory that requires ZERO admin privileges
$baseDir = if ($IsLinux -or $IsMacOs) { "$HOME/.local/share/PackageManagement/ProviderAssemblies" } else { "$HOME\AppData\Local\PackageManagement\ProviderAssemblies" }
$providerDir = "$baseDir\NuGet\2.8.5.208"

# Create the folder structure safely inside your user profile
if (!(Test-Path $providerDir)) {
    New-Item -ItemType Directory -Path $providerDir -Force
}

# 3. Download the official Microsoft NuGet Provider DLL directly to your user folder
$sourceUrl = "https://onegetcdn.azureedge.net/providers/Microsoft.PackageManagement.NuGetProvider-2.8.5.208.dll"
$destFile = "$providerDir\Microsoft.PackageManagement.NuGetProvider.dll"

Write-Host "Downloading NuGet Package Provider to your user folder..."
Invoke-WebRequest -Uri $sourceUrl -OutFile $destFile

# 4. Unblock the file (Windows-specific safety requirement)
if (!$IsLinux -and !$IsMacOs) {
    Unblock-File -Path $destFile
}

# 5. Refresh and verify the installation
Write-Host "Verifying installation..."
Get-PackageProvider -ListAvailable
```

**What this does:**

| Step | Action |
|------|--------|
| TLS 1.2 | Enforces a secure connection for the download |
| User-level directory | Installs under `$HOME` — no admin rights needed |
| Download DLL | Fetches the official Microsoft NuGet provider |
| Unblock-File | Removes the "downloaded from internet" flag on Windows |
| Verify | Lists available providers to confirm NuGet is registered |

---

## Step 2 — Install FFmpeg / FFprobe

Downloads the FFmpeg essentials build, extracts it to your user profile, and registers the `bin` folder in your **User PATH** so `ffprobe` (and `ffmpeg`) are available globally from any terminal.

```powershell
# 1. Define paths explicitly inside your personal User Profile
$installDir = Join-Path $HOME "FFmpeg"
$zipPath = Join-Path $HOME "ffmpeg.zip"
$downloadUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"

Write-Host "1. Downloading FFmpeg/FFprobe source package..." -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# This will now download safely to your user directory
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath

Write-Host "2. Extracting files to $installDir..." -ForegroundColor Cyan
if (!(Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force }
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force

# 2. Locate the executable directory automatically
$binFolder = Get-ChildItem -Path $installDir -Recurse -Directory -Filter "bin" | Select-Object -First 1

if ($binFolder) {
    $ffpath = $binFolder.FullName
    Write-Host "Found binaries at: $ffpath" -ForegroundColor Green

    # 3. Permanently write this path into your Windows Environment variables
    Write-Host "3. Registering FFprobe globally across your operating system..." -ForegroundColor Cyan
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$ffpath*") {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$ffpath", "User")
        $env:Path += ";$ffpath" # Inject into current running console window immediately
        Write-Host "SUCCESS: FFprobe is now fully installed and registered!" -ForegroundColor Green
    } else {
        Write-Host "FFprobe is already configured in your system path." -ForegroundColor Yellow
    }
} else {
    Write-Host "ERROR: Structural mismatch inside the downloaded archive." -ForegroundColor Red
}

# Clean up temporal files
Remove-Item $zipPath -ErrorAction SilentlyContinue
```

**What this does:**

| Step | Action |
|------|--------|
| Download | Fetches the FFmpeg essentials build from gyan.dev |
| Extract | Unzips to `$HOME/FFmpeg/` |
| Locate bin | Auto-finds the `bin` folder containing `ffmpeg.exe` and `ffprobe.exe` |
| Register PATH | Adds the bin folder to your permanent User PATH variable |
| Clean up | Deletes the downloaded `.zip` file |

> **Note:** After this step, **restart your terminal** or open a new PowerShell window to ensure the PATH change takes effect.

---

## Step 3 — Sort Videos by Orientation

Navigate to the folder containing your video files, then run the sorting script. It will create `horizontal/` and `vertical/` subdirectories and move each video into the correct one based on its resolution.

```powershell
# Navigate to your video folder
cd "C:\Path\To\Your\Videos"

# 1. Define target folders dynamically based on your current location
$horizontalDir = Join-Path $PWD "horizontal"
$verticalDir = Join-Path $PWD "vertical"

# 2. Ensure the sorting folders exist
if (!(Test-Path $horizontalDir)) { New-Item -ItemType Directory -Path $horizontalDir -Force | Out-Null }
if (!(Test-Path $verticalDir)) { New-Item -ItemType Directory -Path $verticalDir -Force | Out-Null }

# 3. Gather target media files
$extensions = @('.mp4', '.mkv', '.mov', '.avi', '.wmv', '.flv', '.m4v')
$videos = Get-ChildItem -File | Where-Object { $extensions -contains $_.Extension.ToLower() }

Write-Host "Found $($videos.Count) video files to analyze in $PWD`n" -ForegroundColor Cyan

# 4. Loop through each file and sort based on metadata
foreach ($video in $videos) {
    Write-Host "Analyzing: $($video.Name)... " -NoNewline

    # Query resolution via global ffprobe registration
    $res = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$($video.FullName)" 2>$null

    # Ensure metadata was read successfully and matches expected format (e.g., 1920x1080)
    if ($res -and $res -match '^\d+x\d+$') {
        $dimensions = $res -split 'x'
        $width = [int]$dimensions[0]
        $height = [int]$dimensions[1]

        if ($width -gt $height) {
            Move-Item -Path $video.FullName -Destination $horizontalDir -Force
            Write-Host "[Horizontal] -> Moved" -ForegroundColor Green
        } elseif ($height -gt $width) {
            Move-Item -Path $video.FullName -Destination $verticalDir -Force
            Write-Host "[Vertical] -> Moved" -ForegroundColor Yellow
        } else {
            Write-Host "[Square] -> Skipped" -ForegroundColor Gray
        }
    } else {
        Write-Host "[Failed] -> Unable to parse video streams" -ForegroundColor Red
    }
}

Write-Host "`nAll files successfully processed!" -ForegroundColor Green
```

---

## Quick Start (One-Click Script)

Instead of running each step manually, you can download the `video_sorter.ps1` script, place it in your video folder, and run it:

```powershell
# Download the script (update the URL to wherever you host it)
Invoke-WebRequest -Uri "https://example.com/video_sorter.ps1" -OutFile "video_sorter.ps1"

# Copy it into the folder with your videos, then run:
cd "C:\Path\To\Your\Videos"
.\video_sorter.ps1
```

Or, if you already have the script file locally, simply copy it into the target folder and execute:

```powershell
.\video_sorter.ps1
```

---

## Supported Video Formats

| Extension | Format |
|-----------|--------|
| `.mp4` | MPEG-4 |
| `.mkv` | Matroska |
| `.mov` | QuickTime |
| `.avi` | Audio Video Interleave |
| `.wmv` | Windows Media Video |
| `.flv` | Flash Video |
| `.m4v` | MPEG-4 (Apple variant) |

---

## How It Works

```
┌─────────────────────────────────────┐
│         Video Folder                │
│                                     │
│  video1.mp4   (1920×1080)          │
│  video2.mp4   (1080×1920)          │
│  video3.mov   (3840×2160)          │
│  video4.mkv   (720×1280)          │
│  video5.avi   (800×800)            │
│                                     │
└──────────────┬──────────────────────┘
               │
               ▼  ffprobe reads width×height
               │
     ┌─────────┴──────────┐
     │                    │
     ▼                    ▼
┌──────────┐       ┌──────────┐
│horizontal│       │ vertical │
│          │       │          │
│ video1   │       │ video2   │
│ video3   │       │ video4   │
└──────────┘       └──────────┘

  video5 → Skipped (square: width = height)
```

The script uses **ffprobe** to read the `width` and `height` of the first video stream in each file:

- **width > height** → moved to `horizontal/`
- **height > width** → moved to `vertical/`
- **width = height** → **skipped** (square aspect ratio, left in place)
- **unreadable metadata** → **skipped** with an error message, left in place

---

## Troubleshooting

### `ffprobe is not recognized`

FFprobe is not in your PATH. Fixes:

1. **Restart your terminal** — the PATH change from Step 2 only takes effect in new sessions.
2. **Verify manually** — check that `$HOME/FFmpeg/` contains a folder with a `bin` subdirectory holding `ffprobe.exe`.
3. **Add PATH manually** — press `Win + R`, type `sysdm.cpl`, go to **Advanced → Environment Variables**, and add the `bin` folder path to your **User PATH**.

### `Unable to parse video streams` error

This can happen when:

- The file is **corrupted** or not a valid video.
- The video uses a codec that your ffprobe build doesn't support (rare with the essentials build).
- The file is **locked** by another process.

### NuGet provider not found after Step 1

- Make sure you ran PowerShell **as your normal user** (not as admin unless required by policy).
- Run `Get-PackageProvider -ListAvailable` and look for `NuGet` in the output.
- If missing, re-run Step 1 and check for download errors.

### Want to undo the sorting?

To move all files back out of the subdirectories:

```powershell
Get-ChildItem -Path ".\horizontal", ".\vertical" -File | Move-Item -Destination $PWD -Force
```
