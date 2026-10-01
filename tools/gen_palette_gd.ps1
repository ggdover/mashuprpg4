# Generates game/core/palette.gd from design/palette.json.
# Run from anywhere:  powershell -ExecutionPolicy Bypass -File tools\gen_palette_gd.ps1
# Idempotent: the same JSON always produces a byte-identical palette.gd (UTF-8, no BOM, LF line endings).
$ErrorActionPreference = 'Stop'

$root     = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$jsonPath = Join-Path $root 'design\palette.json'
$outPath  = Join-Path $root 'game\core\palette.gd'
$pal      = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Hex([string]$h) {
  if ($h -notmatch '^#[0-9A-Fa-f]{6}$') { throw "palette.json: '$h' is not a #RRGGBB colour" }
  return $h.ToUpper()
}

# One dictionary entry: a role mapped to a Color, with the role's use as a trailing comment.
function Entry([string]$role, [string]$hex, [string]$use) {
  $line = "`t`"$role`": Color(`"$(Hex $hex)`"),"
  if ($use) { $line += " # $use" }
  return $line
}

# The body of the DAY or FOG dictionary: ramp, environment, that state's accents, UI signals.
function Table([string]$state) {
  $lines = @("`t# Ramp")
  foreach ($r in $pal.ramp)           { $lines += Entry $r.role $r.$state $r.use }
  $lines += "`t# Environment"
  foreach ($r in $pal.environment)    { $lines += Entry $r.role $r.$state $r.use }
  $lines += "`t# Accents ($state only)"
  foreach ($a in $pal.accents.$state) { $lines += Entry $a.role $a.hex $a.use }
  $lines += "`t# UI signals"
  foreach ($u in $pal.ui)             { $lines += Entry $u.signal $u.$state $u.note }
  return $lines
}

$out = @()
$out += '## generated, do not edit'
$out += "## Source: design/palette.json ($($pal.name), version $($pal.version))."
$out += '## Regenerate from the repo root with:'
$out += '##   powershell -ExecutionPolicy Bypass -File tools\gen_palette_gd.ps1'
$out += '##'
$out += '## Colours by role for the two forest states. Pick by role, never by eye;'
$out += '## design/palette.md has the rules. Keys are the role names from the JSON.'
$out += 'class_name Palette'
$out += 'extends RefCounted'
$out += ''
$out += '## Returned by [method role] for a role that exists in neither state.'
$out += 'const MISSING := Color.MAGENTA'
$out += ''
$out += "## $($pal.states.day.title) ($($pal.states.day.swedish)): $($pal.states.day.description)"
$out += 'const DAY: Dictionary = {'
$out += Table 'day'
$out += '}'
$out += ''
$out += "## $($pal.states.fog.title) ($($pal.states.fog.swedish)): $($pal.states.fog.description)"
$out += 'const FOG: Dictionary = {'
$out += Table 'fog'
$out += '}'
$out += ''
$out += ''
$out += '## The colour of role [param name] in [param state] (a WorldState.State value).'
$out += '## The accents are not paired: a role that only one state has is returned from that'
$out += '## state whichever one is asked for, so the fog accents can be read while it is day.'
$out += '## A role that neither state has returns MISSING and pushes an error.'
$out += 'static func role(name: StringName, state: int) -> Color:'
$out += "`tvar in_fog: bool = state == WorldState.State.FOG"
$out += "`tvar table: Dictionary = FOG if in_fog else DAY"
$out += "`tif table.has(name):"
$out += "`t`treturn table[name]"
$out += "`tvar other: Dictionary = DAY if in_fog else FOG"
$out += "`tif other.has(name):"
$out += "`t`treturn other[name]"
$out += "`tpush_error(`"Palette: unknown role '%s'`" % name)"
$out += "`treturn MISSING"

$text = ($out -join "`n") + "`n"
[IO.File]::WriteAllText($outPath, $text, (New-Object System.Text.UTF8Encoding $false))
$count = ($pal.ramp.Count + $pal.environment.Count) * 2 + $pal.accents.day.Count + $pal.accents.fog.Count
Write-Output "wrote $outPath ($count colour entries plus the UI signals)"
