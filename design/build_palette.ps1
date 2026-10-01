# Regenerates palette.html from palette.json and prints contrast checks.
# Run from anywhere:  powershell -ExecutionPolicy Bypass -File design\build_palette.ps1
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$pal  = Get-Content (Join-Path $here "palette.json") -Raw -Encoding UTF8 | ConvertFrom-Json

function Lum($hex) {
  $c = $hex.TrimStart('#')
  $ch = @([Convert]::ToInt32($c.Substring(0,2),16), [Convert]::ToInt32($c.Substring(2,2),16), [Convert]::ToInt32($c.Substring(4,2),16)) | ForEach-Object {
    $v = $_ / 255.0
    if ($v -le 0.03928) { $v / 12.92 } else { [Math]::Pow(($v + 0.055) / 1.055, 2.4) }
  }
  return 0.2126*$ch[0] + 0.7152*$ch[1] + 0.0722*$ch[2]
}
function Contrast($a, $b) {
  $la = Lum $a; $lb = Lum $b
  $hi = [Math]::Max($la,$lb); $lo = [Math]::Min($la,$lb)
  return [Math]::Round(($hi + 0.05) / ($lo + 0.05), 2)
}

# ---------- contrast report ----------
Write-Output "Contrast (WCAG): text needs >= 4.5, graphics >= 3.0"
$ui = @{}; foreach ($u in $pal.ui) { $ui[$u.signal] = $u }
foreach ($s in @("day","fog")) {
  $panel = $ui["panel"].$s
  foreach ($sig in @("text","highlight","health","stamina")) {
    $c = Contrast $ui[$sig].$s $panel
    Write-Output ("  {0,-4} {1,-10} on panel  {2,5}" -f $s, $sig, $c)
  }
  $bright = ($pal.ramp | Where-Object role -eq "bright").$s
  $deep   = ($pal.ramp | Where-Object role -eq "deepest").$s
  Write-Output ("  {0,-4} {1,-10} on bright {2,5}" -f $s, "deepest", (Contrast $deep $bright))
}

# ---------- html ----------
function Enc($s) { [System.Net.WebUtility]::HtmlEncode($s) }
function Swatch($hex, $label, $sub) {
  $em = ''
  if ($sub) { $em = '<em>' + (Enc $sub) + '</em>' }
  return ('<div class="sw"><div class="chip" style="background:{0}"></div><div class="lbl"><b>{1}</b><span>{2}</span>{3}</div></div>' -f $hex, (Enc $label), $hex.ToUpper(), $em)
}
Add-Type -AssemblyName System.Drawing
function Thumb64($path, $width) {
  # small JPEG thumbnail as a data URI so palette.html is self-contained
  $src = [System.Drawing.Image]::FromFile($path)
  try {
    $h = [int][Math]::Round($src.Height * $width / $src.Width)
    $bmp = New-Object System.Drawing.Bitmap $width, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($src, 0, 0, $width, $h)
    $g.Dispose()
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq "image/jpeg"
    $prm = New-Object System.Drawing.Imaging.EncoderParameters 1
    $prm.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [long]80)
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, $codec, $prm)
    $bmp.Dispose()
    return "data:image/jpeg;base64," + [Convert]::ToBase64String($ms.ToArray())
  } finally { $src.Dispose() }
}
function Thumbs($dir) {
  $out = ""
  Get-ChildItem (Join-Path $here "..\ref_imgs\$dir") -Filter *.png | ForEach-Object {
    $out += ('<img src="{0}" alt="{1}">' -f (Thumb64 $_.FullName 384), (Enc $_.Name))
  }
  return $out
}

$sb = New-Object System.Text.StringBuilder
$head = @'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Forest Palette</title>
<style>
  :root { --bg:#1b1c1f; --fg:#e6e6e6; --mut:#9a9aa0; --line:#2c2d32; }
  * { box-sizing:border-box }
  body { margin:0; background:var(--bg); color:var(--fg); font:14px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; padding:24px 16px 64px; }
  main { max-width:1180px; margin:0 auto }
  h1 { font-size:22px; margin:0 0 4px } h2 { font-size:15px; text-transform:uppercase; letter-spacing:.08em; color:var(--mut); margin:36px 0 12px; border-bottom:1px solid var(--line); padding-bottom:6px }
  h3 { font-size:14px; margin:14px 0 8px }
  p { max-width:70ch; color:#c9c9cf }
  .two { display:grid; grid-template-columns:1fr 1fr; gap:24px } @media (max-width:820px){ .two{ grid-template-columns:1fr } }
  .thumbs { display:grid; grid-template-columns:repeat(4,1fr); gap:6px } .thumbs img { width:100%; aspect-ratio:3/2; object-fit:cover; border-radius:4px; background:#000 }
  .strip { display:flex; height:56px; border-radius:6px; overflow:hidden; margin:8px 0 4px } .strip div { flex:1 }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(150px,1fr)); gap:10px }
  .sw { min-width:0 } .chip { height:64px; border-radius:6px; border:1px solid rgba(255,255,255,.06) }
  .lbl { padding:6px 2px 0; font-size:12px; line-height:1.3 } .lbl b { display:block } .lbl span { color:var(--mut); font-family:ui-monospace,Consolas,monospace; font-size:11px } .lbl em { display:block; color:var(--mut); font-style:normal; font-size:11px; margin-top:2px }
  table.pair { width:100%; border-collapse:collapse; font-size:13px } table.pair th, table.pair td { text-align:left; padding:6px 8px; border-bottom:1px solid var(--line); vertical-align:top }
  table.pair th { color:var(--mut); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:.06em }
  .cell { display:flex; align-items:center; gap:8px; white-space:nowrap } .dot { width:34px; height:34px; border-radius:5px; flex:none; border:1px solid rgba(255,255,255,.06) } .hex { font-family:ui-monospace,Consolas,monospace; font-size:11px; color:var(--mut) }
  .use { color:#b9b9c0; font-size:12px }
  .ui { display:grid; grid-template-columns:repeat(auto-fill,minmax(230px,1fr)); gap:10px }
  .card { border:1px solid var(--line); border-radius:8px; padding:12px } .card .bar { height:10px; border-radius:5px; margin-top:6px }
  .bar { height:10px; border-radius:5px; margin-top:6px }
</style></head><body><main>
'@
[void]$sb.Append($head)
[void]$sb.AppendLine(('<h1>{0}</h1><p>Two states of the same forest. Every new colour in the game is picked from these by <b>role</b>. Source of truth: <code>palette.json</code>.</p>' -f (Enc $pal.name)))

# references
[void]$sb.AppendLine('<h2>Reference</h2><div class="two">')
foreach ($s in @("day","fog")) {
  $st = $pal.states.$s
  $dir = "act1_foggy"; if ($s -eq "day") { $dir = "act1_daytime" }
  [void]$sb.AppendLine(('<div><h3>{0} <span class="hex">{1}</span></h3><div class="thumbs">{2}</div><p style="font-size:12px;margin:8px 0 0">{3}</p></div>' -f (Enc $st.title), (Enc $st.swedish), (Thumbs $dir), (Enc $st.description)))
}
[void]$sb.AppendLine('</div>')

# at a glance strips
[void]$sb.AppendLine('<h2>At a glance</h2><div class="two">')
foreach ($s in @("day","fog")) {
  $all = @($pal.ramp | ForEach-Object { $_.$s }) + @($pal.environment | ForEach-Object { $_.$s }) + @($pal.accents.$s | ForEach-Object { $_.hex })
  $cells = ($all | ForEach-Object { '<div style="background:' + $_ + '"></div>' }) -join ''
  [void]$sb.AppendLine(('<div><h3>{0}</h3><div class="strip">{1}</div><div class="hex">{2} colours: ramp, environment, accents</div></div>' -f (Enc $pal.states.$s.title), $cells, $all.Count))
}
[void]$sb.AppendLine('</div>')

# ramp
[void]$sb.AppendLine('<h2>Value ramp (paired)</h2><p>Six steps from deepest shadow to brightest light. Shade anything without a strong hue along this ramp.</p><div class="two">')
foreach ($s in @("day","fog")) {
  [void]$sb.AppendLine(('<div><h3>{0}</h3><div class="grid">' -f (Enc $pal.states.$s.title)))
  foreach ($r in $pal.ramp) { [void]$sb.AppendLine((Swatch $r.$s $r.role $null)) }
  [void]$sb.AppendLine('</div></div>')
}
[void]$sb.AppendLine('</div>')

# environment table
[void]$sb.AppendLine('<h2>Environment (paired by role)</h2><p>The same object keeps its role in both states; only the value changes. Author once by role and the fog version follows.</p>')
[void]$sb.AppendLine('<table class="pair"><tr><th>Role</th><th>Day</th><th>Fog</th><th>Used for</th></tr>')
foreach ($r in $pal.environment) {
  [void]$sb.AppendLine(('<tr><td><b>{0}</b></td><td><div class="cell"><div class="dot" style="background:{1}"></div><span class="hex">{1}</span></div></td><td><div class="cell"><div class="dot" style="background:{2}"></div><span class="hex">{2}</span></div></td><td class="use">{3}</td></tr>' -f (Enc $r.role), $r.day.ToUpper(), $r.fog.ToUpper(), (Enc $r.use)))
}
[void]$sb.AppendLine('</table>')

# accents
[void]$sb.AppendLine('<h2>Accents (per state)</h2><p>What is special about each state. In fog these are the only saturated colours on screen.</p><div class="two">')
foreach ($s in @("day","fog")) {
  [void]$sb.AppendLine(('<div><h3>{0}</h3><div class="grid">' -f (Enc $pal.states.$s.title)))
  foreach ($a in $pal.accents.$s) { [void]$sb.AppendLine((Swatch $a.hex $a.role $a.use)) }
  [void]$sb.AppendLine('</div></div>')
}
[void]$sb.AppendLine('</div>')

# ui
[void]$sb.AppendLine('<h2>UI signals</h2><p>Drawn from the palette above, not new colours. Health and stamina keep their day values in fog so they stay readable.</p><div class="ui">')
foreach ($u in $pal.ui) {
  [void]$sb.AppendLine(('<div class="card"><b>{0}</b><div class="hex">day {1} / fog {2}</div><div class="bar" style="background:{1}"></div><div class="bar" style="background:{2}"></div><div class="use" style="margin-top:6px">{3}</div></div>' -f (Enc $u.signal), $u.day.ToUpper(), $u.fog.ToUpper(), (Enc $u.note)))
}
[void]$sb.AppendLine('</div>')

# sample panels
[void]$sb.AppendLine('<h2>Sample HUD text on panel</h2><div class="two">')
foreach ($s in @("day","fog")) {
  $p = $ui["panel"].$s; $t = $ui["text"].$s; $h = $ui["highlight"].$s; $hp = $ui["health"].$s; $stm = $ui["stamina"].$s
  [void]$sb.AppendLine(('<div style="background:{0};color:{1};padding:16px;border-radius:8px"><div style="color:{2};font-weight:600">[E] &Ouml;ppna d&ouml;rren</div><div style="margin-top:6px">Byn sover. Dimman ligger &ouml;ver sj&ouml;n.</div><div class="bar" style="background:{3};width:70%"></div><div class="bar" style="background:{4};width:45%"></div></div>' -f $p, $t, $h, $hp, $stm))
}
[void]$sb.AppendLine('</div>')

[void]$sb.AppendLine('</main></body></html>')
$outPath = Join-Path $here "palette.html"
[IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
Write-Output ("wrote " + $outPath)

# ---------- how close is a simple derivation rule to the hand-picked fog values? ----------
function Hex2($hex) { $c = $hex.TrimStart('#'); ,@([Convert]::ToInt32($c.Substring(0,2),16), [Convert]::ToInt32($c.Substring(2,2),16), [Convert]::ToInt32($c.Substring(4,2),16)) }
$fogMid = Hex2 (($pal.ramp | Where-Object role -eq "mid").fog)
Write-Output ""
Write-Output "Derivation check: fog ~ lerp(day, fogMid, 0.6) * 0.6   (delta = max channel diff vs hand-picked)"
foreach ($r in $pal.environment) {
  $d = Hex2 $r.day; $f = Hex2 $r.fog
  $est = 0..2 | ForEach-Object { [int][Math]::Round((($d[$_] * 0.4) + ($fogMid[$_] * 0.6)) * 0.6) }
  $delta = ($(0..2 | ForEach-Object { [Math]::Abs($est[$_] - $f[$_]) }) | Measure-Object -Maximum).Maximum
  Write-Output ("  {0,-10} est #{1:X2}{2:X2}{3:X2}  picked {4}  delta {5}" -f $r.role, $est[0], $est[1], $est[2], $r.fog, $delta)
}
