# Field Helper tablet wallpapers v3: several styles (blueprint, rings, aurora, iso pipe run, minimal logo).
# Run: powershell -File make_wallpaper_v3.ps1   (ASCII file names on purpose: PowerShell 5.1 reads scripts as ANSI)
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
public static class Dither3 {
    public static void Apply(Bitmap bmp, int amp) {
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var d = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int n = Math.Abs(d.Stride) * bmp.Height;
        byte[] px = new byte[n];
        System.Runtime.InteropServices.Marshal.Copy(d.Scan0, px, 0, n);
        var rnd = new Random(13);
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

$global:BPX = 0.62; $global:BPY = 0.74; $global:BPL = 1.0
$global:CS = 1.0   # content scale (1.0 = normal; <1 shrinks logo/tube so the center survives zoom-crops)
function C([string]$hex, [int]$a = 255) {
    $r = [Convert]::ToInt32($hex.Substring(1, 2), 16)
    $g = [Convert]::ToInt32($hex.Substring(3, 2), 16)
    $b = [Convert]::ToInt32($hex.Substring(5, 2), 16)
    return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

function New-Canvas([int]$w, [int]$h) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $g.CompositingQuality = 'HighQuality'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    return @($bmp, $g)
}

function Fill-Gradient($g, [int]$w, [int]$h, $c1, $c2, $c3, [single]$angle = 80.0) {
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (C '#000000'), (C '#000000'), $angle
    $cb = New-Object System.Drawing.Drawing2D.ColorBlend 3
    $cb.Colors = @($c1, $c2, $c3)
    $cb.Positions = @(0.0, 0.5, 1.0)
    $lg.InterpolationColors = $cb
    $g.FillRectangle($lg, $rect)
    $lg.Dispose()
}

function Add-Glow($g, [single]$cx, [single]$cy, [single]$rad, $color, [int]$alpha) {
    $pp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $pp.AddEllipse([single]($cx - $rad), [single]($cy - $rad), [single](2 * $rad), [single](2 * $rad))
    $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $pp
    $pg.CenterColor = [System.Drawing.Color]::FromArgb($alpha, $color)
    $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $color))
    $g.FillPath($pg, $pp)
    $pg.Dispose(); $pp.Dispose()
}

function Save-Canvas($bmp, $g, [string]$path) {
    $g.Dispose()
    [Dither3]::Apply($bmp, 2)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "saved: $path"
}

# cylinder-shaded tube (shadow + body + soft band + highlight)
function Draw-Tube($g, $path, [single]$tw, $dark) {
    $bodyHex = if ($dark) { '#1B9FAB' } else { '#2A9AA5' }
    $lightHex = if ($dark) { '#6FE3EC' } else { '#BDEFF3' }
    $aBody = if ($dark) { 150 } else { 130 }
    $shA = if ($dark) { 70 } else { 36 }
    $shadow = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($shA, 0, 20, 24)), ($tw * 1.18)
    $shadow.LineJoin = 'Round'
    $st = $g.Save(); $g.TranslateTransform([single]($tw * 0.10), [single]($tw * 0.22)); $g.DrawPath($shadow, $path); $g.Restore($st)
    $body = New-Object System.Drawing.Pen (C $bodyHex $aBody), $tw
    $body.LineJoin = 'Round'
    $g.DrawPath($body, $path)
    $midA = if ($dark) { 70 } else { 90 }
    $mid = New-Object System.Drawing.Pen (C $lightHex $midA), ($tw * 0.50)
    $mid.LineJoin = 'Round'
    $st = $g.Save(); $g.TranslateTransform([single](-$tw * 0.10), [single](-$tw * 0.12)); $g.DrawPath($mid, $path); $g.Restore($st)
    $hl = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(110, 255, 255, 255)), ($tw * 0.13)
    $hl.LineJoin = 'Round'
    $st = $g.Save(); $g.TranslateTransform([single](-$tw * 0.22), [single](-$tw * 0.26)); $g.DrawPath($hl, $path); $g.Restore($st)
    $shadow.Dispose(); $body.Dispose(); $mid.Dispose(); $hl.Dispose()
}

function Draw-LogoL($g, [single]$cx, [single]$cy, [single]$size, $color) {
    # logo "L": vertical bar + round corner + horizontal bar, round ends. $size = bar length of the vertical part
    $tw = $size * 0.36
    $lx = $cx - $size * 0.40
    $top = $cy - $size * 0.52
    $bot = $cy + $size * 0.40
    $rr = $size * 0.34
    $right = $cx + $size * 0.44
    $lp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $lp.AddLine([single]$lx, [single]$top, [single]$lx, [single]($bot - $rr))
    $lp.AddArc([single]$lx, [single]($bot - 2 * $rr), [single](2 * $rr), [single](2 * $rr), 180.0, -90.0)
    $lp.AddLine([single]($lx + $rr), [single]$bot, [single]$right, [single]$bot)
    $pen = New-Object System.Drawing.Pen $color, ([single]$tw)
    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    $g.DrawPath($pen, $lp)
    $pen.Dispose(); $lp.Dispose()
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

# ---------- style A: blueprint (grid + bent tube centerline + dimensions) ----------
function Style-Blueprint([int]$w, [int]$h, [string]$path) {
    $cv = New-Canvas $w $h; $bmp = $cv[0]; $g = $cv[1]; $m = [Math]::Min($w, $h) * $global:CS
    Fill-Gradient $g $w $h (C '#0A2230') (C '#0B3340') (C '#061821') 75.0
    Add-Glow $g ($w * 0.85) ($h * 0.10) ($m * 0.9) (C '#22C3D0') 40
    # grid
    $st = [single]($m / 28.0)
    $minor = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(16, 150, 230, 240)), 1.0
    $major = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(30, 150, 230, 240)), 1.6
    $i = 0
    for ($x = 0.0; $x -lt $w; $x += $st) { $pen = if (($i % 5) -eq 0) { $major } else { $minor }; $g.DrawLine($pen, [single]$x, 0.0, [single]$x, [single]$h); $i++ }
    $i = 0
    for ($y = 0.0; $y -lt $h; $y += $st) { $pen = if (($i % 5) -eq 0) { $major } else { $minor }; $g.DrawLine($pen, 0.0, [single]$y, [single]$w, [single]$y); $i++ }
    # tube: from left edge, horizontal, 90-degree bend (radius R), up to top edge
    $cy = $h * $global:BPY; $cx = $w * $global:BPX; $r = $m * 0.16
    $tw = $m * 0.045
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddLine([single](-$m * 0.1), [single]$cy, [single]($cx - $r), [single]$cy)
    $p.AddArc([single]($cx - 2 * $r), [single]($cy - 2 * $r), [single](2 * $r), [single](2 * $r), 90.0, -90.0)
    $p.AddLine([single]$cx, [single]($cy - $r), [single]$cx, [single](-$m * 0.1))
    $wide = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(34, 120, 225, 235)), $tw
    $g.DrawPath($wide, $p)
    $edge1 = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(120, 140, 235, 245)), 2.0
    $edge1.LineJoin = 'Round'
    $g.DrawPath($edge1, $p)
    $cl = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(150, 255, 255, 255)), 2.2
    $cl.DashStyle = 'DashDot'
    $g.DrawPath($cl, $p)
    # dimension: bend radius R (from arc center to the arc), angle mark, run length
    $ctrX = $cx - $r; $ctrY = $cy - $r  # arc center
    $dim = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 255, 214, 120)), 2.2
    $g.DrawLine($dim, [single]$ctrX, [single]$ctrY, [single]($ctrX + $r * 0.7071), [single]($ctrY + $r * 0.7071))
    $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 255, 214, 120))), [single]($ctrX - 7), [single]($ctrY - 7), 14.0, 14.0)
    $fnt = New-Object System.Drawing.Font 'Consolas', ([single]($m * 0.022)), 'Bold', 'Pixel'
    $txt = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(225, 255, 226, 150))
    $g.DrawString('R 76', $fnt, $txt, [single]($ctrX + $r * 0.28), [single]($ctrY + $r * 0.52))
    $arcPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 255, 214, 120)), 2.2
    $ar = $r * 0.38
    $g.DrawArc($arcPen, [single]($ctrX - $ar), [single]($ctrY - $ar), [single](2 * $ar), [single](2 * $ar), 0.0, 90.0)
    $g.DrawString('90 deg', $fnt, $txt, [single]($ctrX + $r * 0.40), [single]($ctrY + $r * 0.04))
    # horizontal run dimension line with arrow ticks
    $ly = $cy + $tw * 1.5
    $x1 = $cx - $m * 0.52 * $global:BPL; $x2 = $cx
    $g.DrawLine($dim, [single]$x1, [single]$ly, [single]$x2, [single]$ly)
    foreach ($xx in @($x1, $x2)) { $g.DrawLine($dim, [single]$xx, [single]($ly - 14), [single]$xx, [single]($ly + 14)) }
    $g.DrawString('L 420', $fnt, $txt, [single](($x1 + $x2) / 2.0 - $m * 0.04), [single]($ly + 12))
    # second small drawing, top-left: label block
    $g.DrawString('FIELD HELPER', $fnt, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70, 200, 245, 250))), [single]($x1), [single]($ly + $m * 0.075))
    Save-Canvas $bmp $g $path
}

# ---------- style B: quarter-circle rings (bend radius rings) ----------
function Style-Rings([int]$w, [int]$h, [bool]$dark, [string]$path) {
    $cv = New-Canvas $w $h; $bmp = $cv[0]; $g = $cv[1]; $m = [Math]::Min($w, $h)
    if ($dark) { Fill-Gradient $g $w $h (C '#0C2A30') (C '#09333A') (C '#05161B') 60.0; $ring = C '#34D0DC'; $glow = C '#1CC0CC' }
    else { Fill-Gradient $g $w $h (C '#F6FCFC') (C '#E0F1F3') (C '#C6E2E5') 60.0; $ring = C '#0B8C98'; $glow = C '#62CBD3' }
    Add-Glow $g ($w * 0.0) ($h * 1.0) ($m * 1.3) $glow 70
    Add-Glow $g ($w * 1.0) ($h * 0.0) ($m * 1.1) $glow 55
    for ($pass = 0; $pass -lt 2; $pass++) {
        $st = $g.Save()
        if ($pass -eq 1) { $g.TranslateTransform([single]($w / 2.0), [single]($h / 2.0)); $g.RotateTransform(180.0); $g.TranslateTransform([single](-$w / 2.0), [single](-$h / 2.0)) }
        $n = 14
        for ($i = 0; $i -lt $n; $i++) {
            $r = $m * (0.16 + 0.095 * $i)
            $a = [int](($(if ($dark) { 95 } else { 80 })) * [Math]::Pow(1.0 - $i / [double]$n, 1.4)) + 6
            $pw = [single]($m * (0.0016 + 0.0009 * (($i % 3) -eq 0)))
            if (($i % 3) -eq 0) { $pw = [single]($m * 0.004) }
            $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($a, $ring)), $pw
            # quarter circle centered on the bottom-left corner: from the left edge up to the bottom edge
            $g.DrawArc($pen, [single](-$r), [single]($h - $r), [single](2 * $r), [single](2 * $r), 270.0, 90.0)
            $pen.Dispose()
        }
        $g.Restore($st)
    }
    # calm center: small logo mark
    $logo = if ($dark) { [System.Drawing.Color]::FromArgb(16, 140, 235, 245) } else { [System.Drawing.Color]::FromArgb(22, 0, 117, 128) }
    Draw-LogoL $g ([single]($w * 0.5)) ([single]($h * 0.46)) ([single]($m * 0.34)) $logo
    Save-Canvas $bmp $g $path
}

# ---------- style C: aurora mesh (soft color fields) + small logo tile ----------
function Style-Aurora([int]$w, [int]$h, [bool]$dark, [string]$path) {
    $cv = New-Canvas $w $h; $bmp = $cv[0]; $g = $cv[1]; $m = [Math]::Min($w, $h)
    if ($dark) { Fill-Gradient $g $w $h (C '#071A1F') (C '#08242B') (C '#050F13') 65.0 }
    else { Fill-Gradient $g $w $h (C '#F4FBFB') (C '#EAF6F6') (C '#DCEEF0') 65.0 }
    $spots = if ($dark) {
        @(@(0.15, 0.12, 0.95, '#0FA3B1', 120), @(0.92, 0.30, 0.85, '#2563EB', 70), @(0.55, 0.62, 0.90, '#10B9A5', 80), @(0.10, 0.92, 0.85, '#0EA5E9', 70), @(0.95, 0.95, 0.75, '#0B7A86', 90))
    } else {
        @(@(0.15, 0.12, 0.95, '#6FD6DE', 130), @(0.92, 0.30, 0.85, '#9DB8F5', 90), @(0.55, 0.62, 0.90, '#7ADBC9', 90), @(0.10, 0.92, 0.85, '#8AD0F0', 90), @(0.95, 0.95, 0.75, '#5BC0CB', 100))
    }
    foreach ($s in $spots) { Add-Glow $g ($w * $s[0]) ($h * $s[1]) ($m * $s[2]) (C $s[3]) $s[4] }
    # logo tile (app icon) with soft glow, lower center
    $ts = $m * 0.13
    $tx = $w / 2.0 - $ts / 2.0
    $ty = $h * 0.74
    Add-Glow $g ($w / 2.0) ($ty + $ts / 2.0) ($ts * 2.2) (C '#19B8C4') ($(if ($dark) { 70 } else { 50 }))
    $rp = New-RoundRect ([single]$tx) ([single]$ty) ([single]$ts) ([single]$ts) ([single]($ts * 0.24))
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush ((New-Object System.Drawing.PointF $tx, $ty), (New-Object System.Drawing.PointF $tx, ($ty + $ts)), (C '#0A8E9B'), (C '#005F69'))
    $g.FillPath($br, $rp)
    Draw-LogoL $g ([single]($tx + $ts * 0.50)) ([single]($ty + $ts * 0.50)) ([single]($ts * 0.60)) ([System.Drawing.Color]::FromArgb(250, 255, 255, 255))
    $br.Dispose(); $rp.Dispose()
    Save-Canvas $bmp $g $path
}

# ---------- style D: isometric pipe run ----------
function Style-Iso([int]$w, [int]$h, [bool]$dark, [string]$path) {
    $cv = New-Canvas $w $h; $bmp = $cv[0]; $g = $cv[1]; $m = [Math]::Min($w, $h)
    if ($dark) { Fill-Gradient $g $w $h (C '#0D2429') (C '#0A3036') (C '#061418') 70.0 }
    else { Fill-Gradient $g $w $h (C '#F6FCFC') (C '#E3F2F3') (C '#CAE3E6') 70.0 }
    Add-Glow $g ($w * 0.8) ($h * 0.15) ($m * 0.9) $(if ($dark) { C '#1CC0CC' } else { C '#62CBD3' }) 55
    # faint isometric grid (30 degree lines)
    $gp = New-Object System.Drawing.Pen ($(if ($dark) { [System.Drawing.Color]::FromArgb(14, 255, 255, 255) } else { [System.Drawing.Color]::FromArgb(24, 0, 90, 100) })), 1.2
    $sp = $m * 0.07
    $t = [Math]::Tan([Math]::PI / 6.0)
    for ($x = -$h; $x -lt $w + $h; $x += $sp) {
        $g.DrawLine($gp, [single]$x, [single]$h, [single]($x + $h / $t), 0.0)
        $g.DrawLine($gp, [single]$x, 0.0, [single]($x + $h / $t), [single]$h)
    }
    $c30 = [Math]::Cos([Math]::PI / 6.0); $s30 = 0.5
    # route: points in "units" of m
    $u = $m * 0.001
    $pts = @(
        @(-60, 0), @(0, 0)
    )
    $x0 = -0.06 * $w; $y0 = $h * 0.80
    $segs = @(@('a', 520), @('v', -150), @('a', 380), @('v', 170), @('a', 420), @('v', -190), @('a', 700))
    $pp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $pts2 = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    $cx = $x0; $cy = $y0
    $pts2.Add((New-Object System.Drawing.PointF ([single]$cx), ([single]$cy)))
    foreach ($s in $segs) {
        if ($s[0] -eq 'a') { $cx += $c30 * $s[1] * $u * 1.0; $cy -= $s30 * $s[1] * $u * 1.0 } else { $cy += $s[1] * $u }
        $pts2.Add((New-Object System.Drawing.PointF ([single]$cx), ([single]$cy)))
    }
    $pp.AddLines($pts2.ToArray())
    Draw-Tube $g $pp ([single]($m * 0.032)) $dark
    # small flange rings at the elbows
    $ringPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(120, 255, 255, 255)), ([single]($m * 0.0035))
    for ($i = 1; $i -lt $pts2.Count - 1; $i++) {
        $pt = $pts2[$i]
        $rad = $m * 0.030
        $g.DrawEllipse($ringPen, [single]($pt.X - $rad), [single]($pt.Y - $rad), [single](2 * $rad), [single](2 * $rad))
    }
    $logo = if ($dark) { [System.Drawing.Color]::FromArgb(14, 140, 235, 245) } else { [System.Drawing.Color]::FromArgb(20, 0, 117, 128) }
    Draw-LogoL $g ([single]($w * 0.5)) ([single]($h * 0.27)) ([single]($m * 0.26)) $logo
    Save-Canvas $bmp $g $path
}

# ---------- style E: minimal logo + wordmark ----------
function Style-Minimal([int]$w, [int]$h, [bool]$dark, [string]$path) {
    $cv = New-Canvas $w $h; $bmp = $cv[0]; $g = $cv[1]; $m = [Math]::Min($w, $h) * $global:CS
    if ($dark) { Fill-Gradient $g $w $h (C '#16191C') (C '#13191C') (C '#0E1113') 90.0; $gl = C '#0E8C97' }
    else { Fill-Gradient $g $w $h (C '#FAFCFC') (C '#F0F6F7') (C '#E3EEF0') 90.0; $gl = C '#7FD0D8' }
    Add-Glow $g ($w / 2.0) ($h * 0.46) ($m * 0.75) $gl ($(if ($dark) { 90 } else { 80 }))
    # thin concentric rings around the logo
    for ($i = 1; $i -le 3; $i++) {
        $r = $m * (0.20 + 0.11 * $i)
        $ra = [int](($(if ($dark) { 46 } else { 40 })) / $i)
        $rp = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($ra, 40, 200, 212)), 2.0
        $g.DrawEllipse($rp, [single]($w / 2.0 - $r), [single]($h * 0.46 - $r), [single](2 * $r), [single](2 * $r))
        $rp.Dispose()
    }
    $ts = $m * 0.24
    $tx = $w / 2.0 - $ts / 2.0
    $ty = $h * 0.46 - $ts / 2.0
    Add-Glow $g ($w / 2.0) ($h * 0.46) ($ts * 1.5) (C '#19B8C4') 60
    $rp2 = New-RoundRect ([single]$tx) ([single]$ty) ([single]$ts) ([single]$ts) ([single]($ts * 0.24))
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush ((New-Object System.Drawing.PointF $tx, $ty), (New-Object System.Drawing.PointF $tx, ($ty + $ts)), (C '#0A8E9B'), (C '#005F69'))
    $g.FillPath($br, $rp2)
    Draw-LogoL $g ([single]($tx + $ts * 0.50)) ([single]($ty + $ts * 0.50)) ([single]($ts * 0.60)) ([System.Drawing.Color]::FromArgb(250, 255, 255, 255))
    $br.Dispose(); $rp2.Dispose()
    # wordmark (Pacifico from the app assets)
    $fontFile = Join-Path $PSScriptRoot '..\..\assets\fonts\Pacifico-Regular.ttf'
    if (Test-Path $fontFile) {
        $pfc = New-Object System.Drawing.Text.PrivateFontCollection
        $pfc.AddFontFile((Resolve-Path $fontFile).Path)
        $fnt = New-Object System.Drawing.Font $pfc.Families[0], ([single]($m * 0.075)), 'Regular', 'Pixel'
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = 'Center'
        $tb = New-Object System.Drawing.SolidBrush ($(if ($dark) { [System.Drawing.Color]::FromArgb(150, 255, 255, 255) } else { [System.Drawing.Color]::FromArgb(150, 0, 80, 88) }))
        $g.DrawString('Field Helper', $fnt, $tb, [single]($w / 2.0), [single]($ty + $ts + $m * 0.07), $sf)
    }
    Save-Canvas $bmp $g $path
}

if ($MyInvocation.InvocationName -ne '.') {
$out = $PSScriptRoot
    $P = '1600x2560'; $L = '2560x1600'
    Style-Blueprint 1600 2560 (Join-Path $out "fieldhelper_blueprint_dark_portrait_$P.png")
    Style-Blueprint 2560 1600 (Join-Path $out "fieldhelper_blueprint_dark_landscape_$L.png")
    Style-Rings 1600 2560 $true  (Join-Path $out "fieldhelper_rings_dark_portrait_$P.png")
    Style-Rings 2560 1600 $true  (Join-Path $out "fieldhelper_rings_dark_landscape_$L.png")
    Style-Rings 1600 2560 $false (Join-Path $out "fieldhelper_rings_light_portrait_$P.png")
    Style-Rings 2560 1600 $false (Join-Path $out "fieldhelper_rings_light_landscape_$L.png")
    Style-Aurora 1600 2560 $true  (Join-Path $out "fieldhelper_aurora_dark_portrait_$P.png")
    Style-Aurora 2560 1600 $true  (Join-Path $out "fieldhelper_aurora_dark_landscape_$L.png")
    Style-Aurora 1600 2560 $false (Join-Path $out "fieldhelper_aurora_light_portrait_$P.png")
    Style-Aurora 2560 1600 $false (Join-Path $out "fieldhelper_aurora_light_landscape_$L.png")
    Style-Iso 1600 2560 $true  (Join-Path $out "fieldhelper_iso_dark_portrait_$P.png")
    Style-Iso 2560 1600 $true  (Join-Path $out "fieldhelper_iso_dark_landscape_$L.png")
    Style-Iso 1600 2560 $false (Join-Path $out "fieldhelper_iso_light_portrait_$P.png")
    Style-Iso 2560 1600 $false (Join-Path $out "fieldhelper_iso_light_landscape_$L.png")
    Style-Minimal 1600 2560 $true  (Join-Path $out "fieldhelper_minimal_dark_portrait_$P.png")
    Style-Minimal 2560 1600 $true  (Join-Path $out "fieldhelper_minimal_dark_landscape_$L.png")
    Style-Minimal 1600 2560 $false (Join-Path $out "fieldhelper_minimal_light_portrait_$P.png")
    Style-Minimal 2560 1600 $false (Join-Path $out "fieldhelper_minimal_light_landscape_$L.png")
    
    # Galaxy Tab A11 (8.7 inch, 800x1340 screen => ratio 1 : 1.675): exact-ratio versions at 2x so nothing is cropped
    Style-Blueprint 1600 2680 (Join-Path $out 'fieldhelper_blueprint_dark_A11_1600x2680.png')
    Style-Minimal 1600 2680 $true (Join-Path $out 'fieldhelper_minimal_dark_A11_1600x2680.png')
    
    # A11 4K: short side 2160, ratio 1 : 1.675 => 2160 x 3618
    Style-Blueprint 2160 3618 (Join-Path $out 'fieldhelper_blueprint_dark_A11_4K_2160x3618.png')
    Style-Minimal 2160 3618 $true (Join-Path $out 'fieldhelper_minimal_dark_A11_4K_2160x3618.png')
    
    # Galaxy Tab A9+ (11 inch, 1200x1920 => ratio 1 : 1.6), 4K: 2160 x 3456
    Style-Blueprint 2160 3456 (Join-Path $out 'fieldhelper_blueprint_dark_A9plus_4K_2160x3456.png')
    Style-Minimal 2160 3456 $true (Join-Path $out 'fieldhelper_minimal_dark_A9plus_4K_2160x3456.png')
    
}
