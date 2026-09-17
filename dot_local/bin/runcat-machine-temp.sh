#!/usr/bin/env bash
# Publish machine temperature as a RunCat Neo custom metrics JSON file.
set -euo pipefail

readonly OUTPUT_PATH="${RUNCAT_TEMP_OUTPUT:-${XDG_DATA_HOME:-$HOME/.local/share}/runcat-neo/machine-temp.json}"
readonly SAMPLE_INTERVAL="${RUNCAT_TEMP_SAMPLE_INTERVAL:-500}"
# Floor is idle, ceiling is where the SoC starts throttling.
readonly TEMP_FLOOR="${RUNCAT_TEMP_FLOOR:-30}"
readonly TEMP_CEILING="${RUNCAT_TEMP_CEILING:-100}"
readonly TEMP_WARN="${RUNCAT_TEMP_WARN:-70}"
readonly TEMP_HOT="${RUNCAT_TEMP_HOT:-85}"

runcat_temp_validate_number() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    printf '%s must be a non-negative number: %s\n' "$name" "$value" >&2
    return 1
  fi
}

runcat_temp_validate_number RUNCAT_TEMP_SAMPLE_INTERVAL "$SAMPLE_INTERVAL"
runcat_temp_validate_number RUNCAT_TEMP_FLOOR "$TEMP_FLOOR"
runcat_temp_validate_number RUNCAT_TEMP_CEILING "$TEMP_CEILING"
runcat_temp_validate_number RUNCAT_TEMP_WARN "$TEMP_WARN"
runcat_temp_validate_number RUNCAT_TEMP_HOT "$TEMP_HOT"

if ! awk -v floor="$TEMP_FLOOR" -v ceiling="$TEMP_CEILING" \
  'BEGIN { exit(floor < ceiling ? 0 : 1) }'; then
  printf 'RUNCAT_TEMP_FLOOR must be below RUNCAT_TEMP_CEILING: %s >= %s\n' \
    "$TEMP_FLOOR" "$TEMP_CEILING" >&2
  exit 1
fi
if ! awk -v warn="$TEMP_WARN" -v hot="$TEMP_HOT" \
  'BEGIN { exit(warn < hot ? 0 : 1) }'; then
  printf 'RUNCAT_TEMP_WARN must be below RUNCAT_TEMP_HOT: %s >= %s\n' \
    "$TEMP_WARN" "$TEMP_HOT" >&2
  exit 1
fi

readonly OUTPUT_DIR="$(dirname "$OUTPUT_PATH")"
mkdir -p "$OUTPUT_DIR"

sample="$(macmon pipe --samples 1 --interval "$SAMPLE_INTERVAL" | tail -n 1)"
if [[ -z "$sample" ]]; then
  printf 'macmon produced no sample\n' >&2
  exit 1
fi

tmp_path="$(mktemp "$OUTPUT_DIR/.machine-temp.json.XXXXXX")"
trap 'rm -f "$tmp_path"' EXIT

# RunCat renders the strings verbatim, so all formatting happens here.
jq \
  --argjson floor "$TEMP_FLOOR" \
  --argjson ceiling "$TEMP_CEILING" \
  --argjson warn "$TEMP_WARN" \
  --argjson hot "$TEMP_HOT" \
  --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '
  def clamp01: if . < 0 then 0 elif . > 1 then 1 else . end;
  def normalize: (. - $floor) / ($ceiling - $floor) | clamp01;
  def celsius: (. * 10 | round) as $tenths
    | "\($tenths / 10 | floor).\($tenths % 10)°C";

  # Failing here keeps a stale card, which beats publishing a cool-looking 0°C.
  (.temp.cpu_temp_avg // error("macmon reported no CPU temperature")) as $cpu
  | (.temp.gpu_temp_avg // error("macmon reported no GPU temperature")) as $gpu
  | ([$cpu, $gpu] | max) as $peak
  | ([.fans[]? | select(.rpm > 0)] | max_by(.rpm)) as $fan
  | {
      title: "マシン温度",
      symbol: "thermometer.medium",
      metricsBarValue: "\($cpu | round)°C",
      metrics: (
        [
          {
            title: "CPU",
            formattedValue: ($cpu | celsius),
            normalizedValue: ($cpu | normalize)
          },
          {
            title: "GPU",
            formattedValue: ($gpu | celsius),
            normalizedValue: ($gpu | normalize)
          }
        ]
        # Fanless Macs report no fans, and idle ones sit at 0 rpm.
        + (if $fan == null then [] else [
            {
              title: "ファン (\($fan.name))",
              formattedValue: "\($fan.rpm) rpm",
              normalizedValue: (
                if ($fan.max_rpm // 0) > 0 then $fan.rpm / $fan.max_rpm else 0 end
              )
            }
          ] end)
        # The bar is drawn in the accent color whatever the value is.
        + [
          {
            title: "状態",
            formattedValue: (
              if $peak >= $hot then "⚠︎ 高温（スロットリングの恐れ）"
              elif $peak >= $warn then "やや高温"
              else "適正"
              end
            )
          }
        ]
      ),
      lastUpdatedDate: $now
    }
  ' <<<"$sample" >"$tmp_path"

# RunCat reads the file as soon as it changes.
mv "$tmp_path" "$OUTPUT_PATH"
trap - EXIT
