#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly SCRIPT="$REPO_ROOT/dot_local/bin/runcat-machine-temp.sh"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin"
export PATH="$test_dir/bin:$PATH"
export RUNCAT_TEMP_OUTPUT="$test_dir/machine-temp.json"
export MACMON_TEST_SAMPLE="$test_dir/sample.json"

cat >"$test_dir/bin/macmon" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${MACMON_TEST_MODE:-ok}" == fail ]]; then
  printf 'macmon: failed to read sensors\n' >&2
  exit 1
fi
cat "$MACMON_TEST_SAMPLE"
EOF
chmod +x "$test_dir/bin/macmon"

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

set_sample() {
  local cpu="$1"
  local gpu="$2"
  local fans="$3"

  # macmon writes one sample per line, so keep the fixture compact too.
  jq -cn \
    --argjson cpu "$cpu" \
    --argjson gpu "$gpu" \
    --argjson fans "$fans" \
    '{temp: {cpu_temp_avg: $cpu, gpu_temp_avg: $gpu}, fans: $fans}' \
    >"$MACMON_TEST_SAMPLE"
}

assert_json() {
  local name="$1"
  local filter="$2"
  local expected="$3"
  local actual

  actual="$(jq -r "$filter" "$RUNCAT_TEMP_OUTPUT")"
  [[ "$actual" == "$expected" ]] ||
    fail "$name: expected '$expected' for '$filter', got '$actual'"
}

export MACMON_TEST_MODE=ok
set_sample 62.14 65.3 '[{"name": "fan0", "rpm": 2586, "max_rpm": 7450}]'
"$SCRIPT" || fail "a healthy sample should succeed"
assert_json 'healthy sample' '.title' 'マシン温度'
assert_json 'healthy sample' '.metricsBarValue' '62°C'
assert_json 'healthy sample' '.metrics | length' '4'
assert_json 'healthy sample' '.metrics[0].formattedValue' '62.1°C'
assert_json 'healthy sample' '.metrics[2].formattedValue' '2586 rpm'
assert_json 'healthy sample' '.metrics[3].formattedValue' '適正'
assert_json 'healthy sample' '.lastUpdatedDate | test("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")' 'true'
printf 'ok - a healthy sample is formatted for RunCat\n'

set_sample 78.0 60.0 '[{"name": "fan0", "rpm": 4000, "max_rpm": 8000}]'
"$SCRIPT" || fail "a warm sample should succeed"
assert_json 'warm sample' '.metrics[3].formattedValue' 'やや高温'
assert_json 'warm sample' '.metrics[2].normalizedValue' '0.5'
printf 'ok - a warm sample is labelled やや高温\n'

set_sample 55.0 54.0 \
  '[{"name": "fan0", "rpm": 2431, "max_rpm": 6898}, {"name": "fan1", "rpm": 2632, "max_rpm": 7450}]'
"$SCRIPT" || fail "a two-fan sample should succeed"
assert_json 'two-fan sample' '.metrics[2].title' 'ファン (fan1)'
assert_json 'two-fan sample' '.metrics[2].formattedValue' '2632 rpm'
printf 'ok - the busiest fan is the one reported\n'

set_sample 120.0 88.0 '[]'
"$SCRIPT" || fail "a hot sample should succeed"
assert_json 'hot sample' '.metrics | length' '3'
assert_json 'hot sample' '.metrics[0].normalizedValue' '1'
assert_json 'hot sample' '.metrics[2].formattedValue' '⚠︎ 高温（スロットリングの恐れ）'
printf 'ok - a hot sample is clamped and flagged\n'

set_sample 45.0 44.0 '[{"name": "fan0", "rpm": 0, "max_rpm": 7450}]'
"$SCRIPT" || fail "a fanless sample should succeed"
assert_json 'fanless sample' '.metrics | map(.title) | join(",")' 'CPU,GPU,状態'
printf 'ok - machines without a running fan omit the fan row\n'

previous="$(cat "$RUNCAT_TEMP_OUTPUT")"
printf '{"fans": [], "memory": {"ram_total": 1}}\n' >"$MACMON_TEST_SAMPLE"
"$SCRIPT" 2>/dev/null &&
  fail "a sample without temperatures should return non-zero"
[[ "$(cat "$RUNCAT_TEMP_OUTPUT")" == "$previous" ]] ||
  fail "a sample without temperatures should leave the previous file in place"
printf 'ok - a sample without temperatures is refused\n'

MACMON_TEST_MODE=fail "$SCRIPT" 2>/dev/null &&
  fail "a macmon failure should return non-zero"
[[ "$(cat "$RUNCAT_TEMP_OUTPUT")" == "$previous" ]] ||
  fail "a macmon failure should leave the previous file in place"
[[ -z "$(find "$(dirname "$RUNCAT_TEMP_OUTPUT")" -name '.machine-temp.json.*')" ]] ||
  fail "a macmon failure should leave no temporary file behind"
printf 'ok - a macmon failure keeps the last good file\n'

set_sample 62.0 60.0 '[]'
RUNCAT_TEMP_WARN=90 RUNCAT_TEMP_HOT=85 "$SCRIPT" 2>/dev/null &&
  fail "inverted thresholds should return non-zero"
printf 'ok - inverted thresholds are rejected\n'
