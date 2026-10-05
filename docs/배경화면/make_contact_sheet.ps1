# Contact sheet of all portrait wallpapers (labels are ASCII). Run: powershell -File make_contact_sheet.ps1
Add-Type -AssemblyName System.Drawing
$dir = $PSScriptRoot
$files = Get-ChildItem $dir -Filter 'fieldhelper_*portrait*.png' | Sort-Object Name
$th = 560; $tw = 350; $pad = 24; $cols = 6
$rows = [Math]::Ceiling($files.Count / $cols)
$W = $cols * ($tw + $pad) + $pad
$H = $rows * ($th + $pad + 30) + $pad
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255, 32, 34, 38))
$g.InterpolationMode = 'HighQualityBicubic'
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'AntiAliasGridFit'
$font = New-Object System.Drawing.Font 'Segoe UI', 15, 'Regular', 'Pixel'
$br = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235, 235, 235))
$i = 0
foreach ($f in $files) {
    $col = $i % $cols; $row = [Math]::Floor($i / $cols)
    $x = $pad + $col * ($tw + $pad); $y = $pad + $row * ($th + $pad + 30)
    $img = [System.Drawing.Image]::FromFile($f.FullName)
    $g.DrawImage($img, [System.Drawing.Rectangle]::new($x, $y, $tw, $th))
    $img.Dispose()
    $label = $f.BaseName -replace '^fieldhelper_', '' -replace '_portrait_1600x2560$', '' -replace '_', ' '
    $g.DrawString($label, $font, $br, [single]$x, [single]($y + $th + 6))
    $i++
}
$g.Dispose()
$out = Join-Path $dir 'contact_sheet.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "saved: $out ($($files.Count) images)"
