$horizontalDir = Join-Path $PWD "horizontal"
$verticalDir = Join-Path $PWD "vertical"

if (!(Test-Path $horizontalDir)) { New-Item -ItemType Directory -Path $horizontalDir -Force | Out-Null }
if (!(Test-Path $verticalDir)) { New-Item -ItemType Directory -Path $verticalDir -Force | Out-Null }

$extensions = @('.mp4', '.mkv', '.mov', '.avi', '.wmv', '.flv', '.m4v')
$videos = Get-ChildItem -File | Where-Object { $extensions -contains $_.Extension.ToLower() }

Write-Host "Found $($videos.Count) video files to analyze in $PWD`n" -ForegroundColor Cyan

foreach ($video in $videos) {
    Write-Host "Analyzing: $($video.Name)... " -NoNewline

    $res = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$($video.FullName)" 2>$null

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
