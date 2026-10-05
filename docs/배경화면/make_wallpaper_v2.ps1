# Field Helper tablet wallpaper v2 (GDI+): tubes with cylinder shading, offset bends, 90-degree bends and a union fitting.
# Run: powershell -File make_wallpaper_v2.ps1   (file names are ASCII on purpose: PowerShell 5.1 reads scripts as ANSI)
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
public static class Dither2 {
    public static void Apply(Bitmap bmp, int amp) {
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var d = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int n = Math.Abs(d.Stride) * bmp.Height;
        byte[] px = new byte[n];
        System.Runtime.InteropServices.Marshal.Copy(d.Scan0, px, 0, n);
        var rnd = new Random(11);
        for (int i = 0; i < n; i += 4) {
            int v = rnd.Next(-amp, amp + 1);
            for (int c = 0; c < 3; c++) {
                int x = px[i + c] + v;
                px[i + c] = (byte)(x < 0 ? 0 : (x > 255 ? 255 : x));
            }
        }
        System.Runtime.InteropServices.Marshal.Copy(px, 0, d.Scan0, n);
        bmp.UnlockBits(d);
    }
}
'@ -ReferencedAssemblies System.Drawing

function C([string]$hex, [int]$a = 255) {
    $r = [Convert]::ToInt32($hex.Substring(1, 2), 16)
    $g = [Convert]::ToInt32($hex.Substring(3, 2), 16)
    $b = [Convert]::ToInt32($hex.Substring(5, 2), 16)
    return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

# One tube = shadow + body + soft light band + thin highlight (shifted up-left) => looks like a cylinder.
function Draw-Tube($g, $path, [single]$tw, $dark) {
    $bodyHex = if ($dark) { '#1B9FAB' } else { '#2A9AA5' }
    $lightHex = if ($dark) { '#6FE3EC' } else { '#BDEFF3' }
    $aBody = if ($dark) { 150 } else { 130 }
    $shadow = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(($(if ($dark) { 70 } else { 36 })), 0, 20, 24)), ($tw * 1.18)
    $st = $g.Save()
    $g.TranslateTransform([single]($tw * 0.10), [single]($tw * 0.22))
    $g.DrawPath($shadow, $path)
    $g.Restore($st)
    $body = New-Object System.Drawing.Pen (C $bodyHex $aBody), $tw
    $g.DrawPath($body, $path)
    $mid = New-Object System.Drawing.Pen (C $lightHex ($(if ($dark) { 70 } else { 90 }))), ($tw * 0.50)
    $st = $g.Save()
    $g.TranslateTransform([single](-$tw * 0.10), [single](-$tw * 0.12))
    $g.DrawPath($mid, $path)
    $g.Restore($st)
    $hl = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(110, 255, 255, 255)), ($tw * 0.13)
    $st = $g.Save()
    $g.TranslateTransform([single](-$tw * 0.22), [single](-$tw * 0.26))
    $g.DrawPath($hl, $path)
    $g.Restore($st)
    $shadow.Dispose(); $body.Dispose(); $mid.Dispose(); $hl.Dispose()
}

function New-RoundRect([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

# Union fitting on a horizontal run: nut - body - nut (metal-like gradient across the height).
function Draw-Fitting($g, [single]$x, [single]$cy, [single]$tw, $dark) {
    $top = if ($dark) { C '#9FEAF0' 190 } else { C '#E6FAFC' 220 }
    $bot = if ($dark) { C '#137D88' 200 } else { C '#4BA9B3' 210 }
    $parts = @(
        @(0.0, 1.5, 0.86),
        @(1.65, 2.3, 0.62),
        @(4.1, 1.5, 0.86)
    )
    foreach ($pt in $parts) {
        $px = $x + $pt[0] * $tw
        $pw = $pt[1] * $tw
        $ph = $tw * 2.0 * $pt[2]
        $rp = New-RoundRect $px ($cy - $ph / 2) $pw $ph ([single]($tw * 0.30))
        $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush ((New-Object System.Drawing.PointF $px, ($cy - $ph / 2)), (New-Object System.Drawing.PointF $px, ($cy + $ph / 2)), $top, $bot)
        $g.FillPath($br, $rp)
        $edge = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(70, 255, 255, 255)), ([single]([Math]::Max(1.5, $tw * 0.05)))
        $g.DrawPath($edge, $rp)
        if ($pt[1] -lt 2.0) {
            $fl = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(55, 255, 255, 255)), ([single]([Math]::Max(1.2, $tw * 0.04)))
            foreach ($f in @(0.33, 0.66)) { $g.DrawLine($fl, [single]($px + $pw * $f), [single]($cy - $ph / 2 + $tw * 0.18), [single]($px + $pw * $f), [single]($cy + $ph / 2 - $tw * 0.18)) }
            $fl.Dispose()
        }
        $br.Dispose(); $edge.Dispose(); $rp.Dispose()
    }
}

function New-Wallpaper([int]$w, [int]$h, [bool]$dark, [string]$path) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $g.CompositingQuality = 'HighQuality'
    $m = [Math]::Min($w, $h)

    # background
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (C '#000000'), (C '#000000'), 70.0
    $cb = New-Object System.Drawing.Drawing2D.ColorBlend 3
    if ($dark) { $cb.Colors = @((C '#0E2A30'), (C '#0A3138'), (C '#061519')) }
    else { $cb.Colors = @((C '#F7FCFC'), (C '#E4F2F3'), (C '#C9E3E6')) }
    $cb.Positions = @(0.0, 0.5, 1.0)
    $lg.InterpolationColors = $cb
    $g.FillRectangle($lg, $rect)

    # soft glows
    $glow = if ($dark) { C '#1CC0CC' } else { C '#62CBD3' }
    foreach ($spot in @(@(0.90, 0.06, 1.00, 62), @(0.06, 0.96, 0.90, 50))) {
        $cx = $w * $spot[0]; $cy = $h * $spot[1]; $rad = $m * $spot[2]
        $pp = New-Object System.Drawing.Drawing2D.GraphicsPath
        $pp.AddEllipse([single]($cx - $rad), [single]($cy - $rad), [single](2 * $rad), [single](2 * $rad))
        $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $pp
        $pg.CenterColor = [System.Drawing.Color]::FromArgb([int]$spot[3], $glow)
        $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $glow))
        $g.FillPath($pg, $pp)
        $pg.Dispose(); $pp.Dispose()
    }

    # faint dot grid (sparser than v1)
    $step = [int]($m / 24)
    $dotColor = if ($dark) { [System.Drawing.Color]::FromArgb(16, 255, 255, 255) } else { [System.Drawing.Color]::FromArgb(26, 0, 90, 100) }
    $dotBrush = New-Object System.Drawing.SolidBrush $dotColor
    $dr = [Math]::Max(1.8, $m / 800.0)
    for ($y = $step; $y -lt $h; $y += $step) {
        for ($x = $step; $x -lt $w; $x += $step) {
            $g.FillEllipse($dotBrush, [single]($x - $dr), [single]($y - $dr), [single](2 * $dr), [single](2 * $dr))
        }
    }

    # big faint logo L (center)
    $tw = $m * 0.15
    $lx = $w * 0.5 - $m * 0.15
    $top = $h * 0.5 - $m * 0.25
    $bot = $h * 0.5 + $m * 0.19
    $rr = $m * 0.18
    $right = $w * 0.5 + $m * 0.22
    $lp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $lp.AddLine([single]$lx, [single]$top, [single]$lx, [single]($bot - $rr))
    $lp.AddArc([single]$lx, [single]($bot - 2 * $rr), [single](2 * $rr), [single](2 * $rr), 180.0, -90.0)
    $lp.AddLine([single]($lx + $rr), [single]$bot, [single]$right, [single]$bot)
    $logoColor = if ($dark) { [System.Drawing.Color]::FromArgb(9, 120, 235, 245) } else { [System.Drawing.Color]::FromArgb(18, 0, 117, 128) }
    $lpen = New-Object System.Drawing.Pen $logoColor, ([single]$tw)
    $lpen.StartCap = 'Round'; $lpen.EndCap = 'Round'; $lpen.LineJoin = 'Round'
    $g.DrawPath($lpen, $lp)
    $lpen.Dispose(); $lp.Dispose()

    # --- tubes ---
    # A) bottom: three tubes of different sizes, each with an offset bend (S-curve), staggered
    $widths = @(($m * 0.034), ($m * 0.026), ($m * 0.019))
    $gap = $m * 0.052
    $y0 = $h * 0.765
    $dOff = $m * 0.075
    for ($i = 0; $i -lt 3; $i++) {
        $yy = $y0 + $i * $gap
        $xs = $w * (0.30 + 0.05 * $i)
        $len = $m * (0.30 + 0.03 * $i)
        $k = $len * 0.55
        $p = New-Object System.Drawing.Drawing2D.GraphicsPath
        $p.AddLine([single](-$m * 0.1), [single]$yy, [single]$xs, [single]$yy)
        $p.AddBezier([single]$xs, [single]$yy, [single]($xs + $k), [single]$yy, [single]($xs + $len - $k), [single]($yy - $dOff), [single]($xs + $len), [single]($yy - $dOff))
        $p.AddLine([single]($xs + $len), [single]($yy - $dOff), [single]($w + $m * 0.1), [single]($yy - $dOff))
        Draw-Tube $g $p ([single]$widths[$i]) $dark
        $p.Dispose()
    }
    # union fitting on the biggest bottom tube
    Draw-Fitting $g ([single]($w * 0.10)) ([single]$y0) ([single]$widths[0]) $dark

    # B) top right: two tubes making a 90-degree bend (come from the right edge, leave through the top)
    $st = $g.Save()
    $g.TranslateTransform([single]($w / 2.0), [single]($h / 2.0))
    $g.RotateTransform(180.0)
    $g.TranslateTransform([single](-$w / 2.0), [single](-$h / 2.0))
    $cx = $w * 0.26
    $cy = $h * 0.22 + $h * 0.60 - $h * 0.60   # center of bend (before rotation: lower-left area)
    $cy = $h * 0.84
    $bw = @(($m * 0.030), ($m * 0.022))
    $rad0 = $m * 0.10
    for ($i = 0; $i -lt 2; $i++) {
        $r = $rad0 + $i * ($m * 0.058)
        $p = New-Object System.Drawing.Drawing2D.GraphicsPath
        $p.AddLine([single](-$m * 0.1), [single]($cy - $r), [single]$cx, [single]($cy - $r))
        $p.AddArc([single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r), 270.0, 90.0)
        $p.AddLine([single]($cx + $r), [single]$cy, [single]($cx + $r), [single]($h + $m * 0.1))
        Draw-Tube $g $p ([single]$bw[$i]) $dark
        $p.Dispose()
    }
    $g.Restore($st)

    $g.Dispose()
    [Dither2]::Apply($bmp, 2)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "saved: $path"
}

$out = $PSScriptRoot
New-Wallpaper 1600 2560 $true  (Join-Path $out 'fieldhelper_v2_dark_portrait_1600x2560.png')
New-Wallpaper 2560 1600 $true  (Join-Path $out 'fieldhelper_v2_dark_landscape_2560x1600.png')
New-Wallpaper 1600 2560 $false (Join-Path $out 'fieldhelper_v2_light_portrait_1600x2560.png')
New-Wallpaper 2560 1600 $false (Join-Path $out 'fieldhelper_v2_light_landscape_2560x1600.png')
