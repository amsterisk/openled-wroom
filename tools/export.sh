#!/usr/bin/env bash
# Build fabrication + documentation outputs for the OpenLED WROOM host board.
#
#   tools/export.sh [--allow-violations] [VERSION]
#
# VERSION defaults to `git describe --tags --always --dirty`.
# Output: production/<VERSION>/
#   <name>-<ver>-gerbers.zip   Gerbers + Excellon drill, ready for JLCPCB/PCBWay (stencil uses F.Paste)
#   bom.csv                    grouped BOM (all parts, DNP column)
#   bom-jlcpcb.csv             JLCPCB-format BOM (fitted parts only)
#   cpl-jlcpcb.csv             JLCPCB-format placement file (top-side SMD, fitted parts only)
#   schematic.pdf              full schematic
#   render-top.png / render-bottom.png   3D renders (skipped if rendering is unavailable)
#   erc.rpt / drc.rpt          check reports
#
# ERC, and DRC with schematic parity, must pass unless --allow-violations is given.
set -euo pipefail

ALLOW=0
if [[ "${1:-}" == "--allow-violations" ]]; then ALLOW=1; shift; fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HW="$ROOT/hardware"
NAME="openled-wroom"
PCB="$HW/$NAME.kicad_pcb"
SCH="$HW/$NAME.kicad_sch"
VER="${1:-$(git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || echo v1.1)}"
OUT="$ROOT/production/$VER"

# kicad-cli is `kicad.kicad-cli` in the snap package. The snap can only write inside $HOME,
# which is why everything is staged under production/ rather than a temp dir.
KCLI="$(command -v kicad-cli || command -v kicad.kicad-cli || true)"
[[ -n "$KCLI" ]] || { echo "kicad-cli not found (install KiCad 9)"; exit 1; }
# wrapper: run kicad-cli, dropping the snap build's harmless image-handler debug spam
kc() { "$KCLI" "$@" 2> >(grep -v 'Debug: Adding duplicate image handler' >&2); }

rm -rf "$OUT"; mkdir -p "$OUT/gerbers"
echo "== $NAME $VER -> ${OUT#$ROOT/}"

check() {  # name, then the command; honours --allow-violations
  local what="$1"; shift
  if "$@" >/dev/null; then echo "   $what: clean"
  elif (( ALLOW )); then echo "   $what: VIOLATIONS (continuing, --allow-violations) - see $what.rpt"
  else echo "   $what: VIOLATIONS - see ${OUT#$ROOT/}/$what.rpt (or rerun with --allow-violations)"; exit 1; fi
}
echo "-- checks"
check erc kc sch erc --exit-code-violations -o "$OUT/erc.rpt" "$SCH"
check drc kc pcb drc --schematic-parity --exit-code-violations -o "$OUT/drc.rpt" "$PCB"

echo "-- gerbers + drill"
kc pcb export gerbers -o "$OUT/gerbers/" --no-x2 --subtract-soldermask \
  -l F.Cu,B.Cu,F.Paste,F.Silkscreen,B.Silkscreen,F.Mask,B.Mask,Edge.Cuts "$PCB" >/dev/null
kc pcb export drill -o "$OUT/gerbers/" --format excellon -u mm \
  --excellon-zeros-format decimal --excellon-oval-format route \
  --generate-map --map-format gerberx2 "$PCB" >/dev/null
( cd "$OUT/gerbers" && zip -q -r "../$NAME-$VER-gerbers.zip" . )

echo "-- BOM + placement"
kc sch export bom -o "$OUT/bom.csv" \
  --fields 'Reference,Value,Footprint,${QUANTITY},${DNP},LCSC' \
  --labels 'Refs,Value,Footprint,Qty,DNP,LCSC' \
  --group-by 'Value,Footprint,${DNP}' "$SCH" >/dev/null
kc sch export bom -o "$OUT/bom-jlcpcb.csv" --exclude-dnp \
  --fields 'Value,Reference,Footprint,LCSC' \
  --labels 'Comment,Designator,Footprint,LCSC Part #' \
  --group-by 'Value,Footprint' --ref-range-delimiter '' "$SCH" >/dev/null
kc pcb export pos -o "$OUT/cpl-raw.csv" --format csv --units mm --side front \
  --smd-only --exclude-dnp "$PCB" >/dev/null
sed '1s/.*/Designator,Val,Package,Mid X,Mid Y,Rotation,Layer/' "$OUT/cpl-raw.csv" > "$OUT/cpl-jlcpcb.csv"
rm "$OUT/cpl-raw.csv"
# note: JLCPCB may need per-part rotation corrections in cpl-jlcpcb.csv; check their preview.

echo "-- docs"
kc sch export pdf -o "$OUT/schematic.pdf" "$SCH" >/dev/null
for side in top bottom; do
  if ! kc pcb render -o "$OUT/render-$side.png" --side "$side" --quality high \
       -w 1600 -h 1200 "$PCB" >/dev/null 2>&1; then
    echo "   render-$side: skipped (3D rendering unavailable here)"
  fi
done

echo "== done:"
( cd "$OUT" && ls -1 | sed 's/^/   /' )
