# Square 4K wallpapers for tablets that rotate (Galaxy Tab A9+): Samsung zooms a portrait image ~1.8x so it also covers landscape,
# so the content is kept small and centered. Run: powershell -File make_wallpaper_square.ps1
. (Join-Path $PSScriptRoot 'make_wallpaper_v3.ps1')
$out = $PSScriptRoot
$global:CS = 0.60
Style-Minimal 3840 3840 $true (Join-Path $out 'fieldhelper_minimal_dark_square_4K_3840.png')
$global:CS = 0.62; $global:BPX = 0.62; $global:BPY = 0.60; $global:BPL = 0.78   # the visible crop starts ~29% from the left, so keep the dimension line and label inside it
Style-Blueprint 3840 3840 (Join-Path $out 'fieldhelper_blueprint_dark_square_4K_3840.png')
