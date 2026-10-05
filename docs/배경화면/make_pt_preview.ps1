# Widget picker preview image for the pressure timer ring (GDI+). Run: powershell -File make_pt_preview.ps1
Add-Type -AssemblyName System.Drawing
$px = 512
$bmp = New-Object System.Drawing.Bitmap $px, $px
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$r = $px / 2.0
function C($a, $r2, $g2, $b) { [System.Drawing.Color]::FromArgb($a, $r2, $g2, $b) }
$tick = New-Object System.Drawing.Pen (C 255 138 144 153), 3
$tick.StartCap = 'Round'; $tick.EndCap = 'Round'
for ($i = 0; $i -lt 60; $i++) {
  $maj = ($i % 5) -eq 0
  $a = ($i * 6 - 90) * [Math]::PI / 180
  $outer = $r * 0.97; $inner = $outer - $r * $(if ($maj) { 0.09 } else { 0.045 })
  $tick.Width = $px * $(if ($maj) { 0.013 } else { 0.007 })
  $g.DrawLine($tick, [single]($r + [Math]::Cos($a) * $inner), [single]($r + [Math]::Sin($a) * $inner), [single]($r + [Math]::Cos($a) * $outer), [single]($r + [Math]::Sin($a) * $outer))
}
$ar = $r * 0.76; $sw = $px * 0.075
$rect = New-Object System.Drawing.RectangleF ([single]($r - $ar)), ([single]($r - $ar)), ([single](2 * $ar)), ([single](2 * $ar))
$trackPen = New-Object System.Drawing.Pen (C 255 43 49 56), ([single]$sw)
$g.DrawEllipse($trackPen, $rect)
$disc = New-Object System.Drawing.SolidBrush (C 255 28 33 39)
$g.FillEllipse($disc, [single]($r - $r * 0.60), [single]($r - $r * 0.60), [single]($r * 1.2), [single]($r * 1.2))
$rim = New-Object System.Drawing.Pen (C 255 52 60 69), ([single]($px * 0.012))
$g.DrawEllipse($rim, [single]($r - $r * 0.60), [single]($r - $r * 0.60), [single]($r * 1.2), [single]($r * 1.2))
$glow = New-Object System.Drawing.Pen (C 90 59 130 246), ([single]($sw * 1.5))
$glow.StartCap = 'Round'; $glow.EndCap = 'Round'
$sweep = 360 * 0.82
$g.DrawArc($glow, $rect, -90, [single]$sweep)
$arc = New-Object System.Drawing.Pen (C 255 59 130 246), ([single]$sw)
$arc.StartCap = 'Round'; $arc.EndCap = 'Round'
$g.DrawArc($arc, $rect, -90, [single]$sweep)
$a = (-90 + $sweep) * [Math]::PI / 180
$needle = New-Object System.Drawing.Pen (C 255 147 197 253), ([single]($px * 0.014))
$needle.StartCap = 'Round'; $needle.EndCap = 'Round'
$g.DrawLine($needle, [single]($r + [Math]::Cos($a) * $r * 0.5), [single]($r + [Math]::Sin($a) * $r * 0.5), [single]($r + [Math]::Cos($a) * $r * 0.98), [single]($r + [Math]::Sin($a) * $r * 0.98))
$g.FillEllipse([System.Drawing.Brushes]::White, [single]($r + [Math]::Cos($a) * $ar - $sw * 0.28), [single]($r + [Math]::Sin($a) * $ar - $sw * 0.28), [single]($sw * 0.56), [single]($sw * 0.56))
$g.Dispose()
$out = Join-Path $PSScriptRoot '..\..\android\app\src\main\res\drawable-nodpi\pt_ring_preview.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "saved"
