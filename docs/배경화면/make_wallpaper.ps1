# 필드 헬퍼 갤럭시 탭 배경화면 만들기(GDI+). 실행: powershell -File make_wallpaper.ps1
# 색: 앱 청록 #007580(로고), 짙은 바탕 #141619(시작 화면). 위젯·아이콘이 올라가도 읽히게 가운데는 차분하게 둔다.
# 구성: 위아래 그라데이션 + 은은한 빛 + 점 격자 + 구석에서 꺾여 나가는 튜브 묶음(튜브 벤딩) + 가운데 큰 로고 "L"(아주 흐리게).
Add-Type -AssemblyName System.Drawing
# 그라데이션 줄무늬(밴딩)가 안 보이게 아주 가는 잡음(±2)을 섞는다.
Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
public static class Dither {
    public static void Apply(Bitmap bmp, int amp) {
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var d = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int n = Math.Abs(d.Stride) * bmp.Height;
        byte[] px = new byte[n];
        System.Runtime.InteropServices.Marshal.Copy(d.Scan0, px, 0, n);
        var rnd = new Random(7);
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

function New-Wallpaper([int]$w, [int]$h, [bool]$dark, [string]$path) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $g.CompositingQuality = 'HighQuality'
    $m = [Math]::Min($w, $h)

    # 1) 바탕 그라데이션(위 → 아래)
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (C '#000000'), (C '#000000'), 90.0
    $cb = New-Object System.Drawing.Drawing2D.ColorBlend 3
    if ($dark) {
        $cb.Colors = @((C '#0D2227'), (C '#0A3037'), (C '#071418'))
    } else {
        $cb.Colors = @((C '#F5FBFB'), (C '#E2F1F2'), (C '#CCE5E7'))
    }
    $cb.Positions = @(0.0, 0.55, 1.0)
    $lg.InterpolationColors = $cb
    $g.FillRectangle($lg, $rect)

    # 2) 은은한 빛(오른쪽 위, 왼쪽 아래)
    $glowColor = if ($dark) { C '#19B6C2' } else { C '#5CC6CF' }
    foreach ($spot in @(@(0.88, 0.08, 0.95, 70), @(0.10, 0.92, 0.85, 55))) {
        $cx = $w * $spot[0]; $cy = $h * $spot[1]; $rad = $m * $spot[2]
        $path2 = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path2.AddEllipse([single]($cx - $rad), [single]($cy - $rad), [single](2 * $rad), [single](2 * $rad))
        $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $path2
        $pg.CenterColor = [System.Drawing.Color]::FromArgb([int]$spot[3], $glowColor)
        $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $glowColor))
        $g.FillPath($pg, $path2)
        $pg.Dispose(); $path2.Dispose()
    }

    # 3) 점 격자(도면 모눈종이 느낌)
    $step = [int]($m / 34)
    $dotColor = if ($dark) { [System.Drawing.Color]::FromArgb(22, 255, 255, 255) } else { [System.Drawing.Color]::FromArgb(34, 0, 90, 100) }
    $dotBrush = New-Object System.Drawing.SolidBrush $dotColor
    $dr = [Math]::Max(1.6, $m / 900.0)
    for ($y = $step; $y -lt $h; $y += $step) {
        for ($x = $step; $x -lt $w; $x += $step) {
            $g.FillEllipse($dotBrush, [single]($x - $dr), [single]($y - $dr), [single](2 * $dr), [single](2 * $dr))
        }
    }

    # 4) 가운데 큰 로고 "L"(아주 흐리게). 앱 아이콘의 L: 세로 막대 + 둥글게 꺾인 모서리 + 가로 막대, 끝은 둥글다.
    $tw = $m * 0.17
    $lx = $w * 0.5 - $m * 0.17
    $top = $h * 0.5 - $m * 0.27
    $bot = $h * 0.5 + $m * 0.21
    $rr = $m * 0.20
    $right = $w * 0.5 + $m * 0.24
    $lpath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $lpath.AddLine([single]$lx, [single]$top, [single]$lx, [single]($bot - $rr))
    $lpath.AddArc([single]$lx, [single]($bot - 2 * $rr), [single](2 * $rr), [single](2 * $rr), 180.0, -90.0)
    $lpath.AddLine([single]($lx + $rr), [single]$bot, [single]$right, [single]$bot)
    $logoColor = if ($dark) { [System.Drawing.Color]::FromArgb(16, 40, 200, 212) } else { [System.Drawing.Color]::FromArgb(22, 0, 117, 128) }
    $lpen = New-Object System.Drawing.Pen $logoColor, ([single]$tw)
    $lpen.StartCap = 'Round'; $lpen.EndCap = 'Round'; $lpen.LineJoin = 'Round'
    $g.DrawPath($lpen, $lpath)
    $lpen.Dispose(); $lpath.Dispose()

    # 5) 구석에서 꺾여 나가는 튜브 묶음(왼쪽 아래: 왼쪽에서 와서 아래로 꺾임, 오른쪽 위: 180도 돌린 모양)
    $tube = if ($dark) { C '#1FB9C5' } else { C '#0A8A95' }
    $tubeA = if ($dark) { 78 } else { 70 }
    $count = 4
    $gap = $m * 0.040
    $tt = $m * 0.022
    $r0 = $m * 0.09
    for ($pass = 0; $pass -lt 2; $pass++) {
        $state = $g.Save()
        if ($pass -eq 1) {
            $g.TranslateTransform([single]($w / 2.0), [single]($h / 2.0))
            $g.RotateTransform(180.0)
            $g.TranslateTransform([single](-$w / 2.0), [single](-$h / 2.0))
        }
        $cx = $w * 0.24
        $cy = $h * 0.84
        for ($i = 0; $i -lt $count; $i++) {
            $r = $r0 + $i * $gap
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddLine([single](-$m * 0.1), [single]($cy - $r), [single]$cx, [single]($cy - $r))
            $p.AddArc([single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r), 270.0, 90.0)
            $p.AddLine([single]($cx + $r), [single]$cy, [single]($cx + $r), [single]($h + $m * 0.1))
            # 튜브 몸통
            $a = [int]($tubeA * (1.0 - 0.14 * $i))
            $body = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($a, $tube)), ([single]$tt)
            $g.DrawPath($body, $p)
            # 윗면 하이라이트(가늘게)
            $hl = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(38, 255, 255, 255)), ([single]($tt * 0.14))
            $g.DrawPath($hl, $p)
            $body.Dispose(); $hl.Dispose(); $p.Dispose()
        }
        $g.Restore($state)
    }

    $g.Dispose()
    [Dither]::Apply($bmp, 2)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "saved: $path"
}

$out = $PSScriptRoot
New-Wallpaper 1600 2560 $true  (Join-Path $out 'fieldhelper_dark_portrait_1600x2560.png')
New-Wallpaper 2560 1600 $true  (Join-Path $out 'fieldhelper_dark_landscape_2560x1600.png')
New-Wallpaper 1600 2560 $false (Join-Path $out 'fieldhelper_light_portrait_1600x2560.png')
New-Wallpaper 2560 1600 $false (Join-Path $out 'fieldhelper_light_landscape_2560x1600.png')
