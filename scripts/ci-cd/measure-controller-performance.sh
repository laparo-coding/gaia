#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
COURSE_ID="${COURSE_ID:-course-123}"
ITERATIONS="${ITERATIONS:-5}"
OUT_FILE="${OUT_FILE:-specs/007-controller-design/performance-results.md}"

INITIAL_TARGET_SECONDS="${INITIAL_TARGET_SECONDS:-2.0}"
NAV_TARGET_SECONDS="${NAV_TARGET_SECONDS:-0.150}"
CURL_TIMEOUT_SECONDS="${CURL_TIMEOUT_SECONDS:-10}"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

json_escape() {
  printf '%s' "$1" | sed 's/"/\\"/g'
}

curl_timed() {
  local method="$1"
  local url="$2"
  local body_file="${3:-}"
  local out_file="$4"

  local hdr_file="$work_dir/headers.tmp"
  local metrics_file="$work_dir/metrics.tmp"

  if [[ -n "$body_file" ]]; then
    curl -sS -D "$hdr_file" -o "$out_file" -w '%{http_code} %{time_total}' \
      --max-time "$CURL_TIMEOUT_SECONDS" \
      -H 'Content-Type: application/json' \
      -X "$method" --data-binary "@$body_file" "$url" > "$metrics_file"
  else
    curl -sS -D "$hdr_file" -o "$out_file" -w '%{http_code} %{time_total}' \
      --max-time "$CURL_TIMEOUT_SECONDS" \
      -X "$method" "$url" > "$metrics_file"
  fi

  local status
  local time_total
  status="$(awk '{print $1}' "$metrics_file")"
  time_total="$(awk '{print $2}' "$metrics_file")"

  printf '%s %s\n' "$status" "$time_total"
}

parse_json_field() {
  local file="$1"
  local key="$2"
  sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" | head -n 1 | sed 's#\\/#/#g'
}

parse_json_field_number() {
  local file="$1"
  local key="$2"
  sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p" "$file" | head -n 1
}

resolve_url() {
  local path_or_url="$1"
  if [[ "$path_or_url" =~ ^https?:// ]]; then
    printf '%s\n' "$path_or_url"
  else
    printf '%s%s\n' "$BASE_URL" "$path_or_url"
  fi
}

compare_leq() {
  local actual="$1"
  local target="$2"
  awk -v a="$actual" -v b="$target" 'BEGIN {
    if (a !~ /^[0-9]+(\.[0-9]+)?$/ || b !~ /^[0-9]+(\.[0-9]+)?$/) exit 1
    exit !(a <= b)
  }'
}

mean_seconds() {
  awk '{ sum += $1; n += 1 } END { if (n == 0) { print "nan" } else { printf "%.3f", sum / n } }'
}

mkdir -p "$(dirname "$OUT_FILE")"

request_id="perf-$(date +%s)"
presentation_file="$work_dir/presentation.json"

echo "Running controller performance probe against $BASE_URL for course $COURSE_ID"

read -r presentation_status presentation_time <<< "$(curl_timed "GET" "$BASE_URL/api/controller/presentation?courseId=$COURSE_ID" "" "$presentation_file")"
if [[ "$presentation_status" != "200" ]]; then
  echo "Presentation request failed with status $presentation_status"
  exit 1
fi

presentation_id="$(parse_json_field "$presentation_file" "presentationId")"
active_index="$(parse_json_field_number "$presentation_file" "activeSlideIndex")"
first_slide_url="$(parse_json_field "$presentation_file" "htmlURL")"

if [[ -z "$presentation_id" || -z "$active_index" || -z "$first_slide_url" ]]; then
  echo "Unable to parse presentation payload for required fields"
  exit 1
fi

slide_url="$(resolve_url "$first_slide_url")"
slide_file="$work_dir/slide.html"
read -r slide_status slide_time <<< "$(curl_timed "GET" "$slide_url" "" "$slide_file")"
if [[ "$slide_status" != "200" ]]; then
  echo "Slide request failed with status $slide_status"
  exit 1
fi

initial_total="$(awk -v a="$presentation_time" -v b="$slide_time" 'BEGIN { printf "%.3f", a + b }')"

nav_times_file="$work_dir/nav_times.txt"
: > "$nav_times_file"

index="$active_index"
for i in $(seq 1 "$ITERATIONS"); do
  nav_body="$work_dir/nav-next-$i.json"
  printf '{"presentationId":"%s","command":"next","fromIndex":%s,"requestId":"%s-next-%s"}' \
    "$(json_escape "$presentation_id")" "$index" "$request_id" "$i" > "$nav_body"

  nav_resp="$work_dir/nav-next-$i.response.json"
  read -r nav_status nav_time <<< "$(curl_timed "POST" "$BASE_URL/api/controller/navigation" "$nav_body" "$nav_resp")"
  if [[ "$nav_status" != "200" ]]; then
    echo "Navigation request (next) failed in iteration $i with status $nav_status"
    exit 1
  fi

  printf '%s\n' "$nav_time" >> "$nav_times_file"
  index="$(parse_json_field_number "$nav_resp" "activeSlideIndex")"
  if [[ -z "$index" ]]; then
    echo "Unable to parse activeSlideIndex after next command"
    exit 1
  fi

  back_body="$work_dir/nav-prev-$i.json"
  printf '{"presentationId":"%s","command":"previous","fromIndex":%s,"requestId":"%s-prev-%s"}' \
    "$(json_escape "$presentation_id")" "$index" "$request_id" "$i" > "$back_body"

  back_resp="$work_dir/nav-prev-$i.response.json"
  read -r back_status _ <<< "$(curl_timed "POST" "$BASE_URL/api/controller/navigation" "$back_body" "$back_body.tmp")"
  if [[ "$back_status" != "200" ]]; then
    echo "Navigation request (previous) failed in iteration $i with status $back_status"
    exit 1
  fi

  cp "$back_body.tmp" "$back_resp"
  index="$(parse_json_field_number "$back_resp" "activeSlideIndex")"
  if [[ -z "$index" ]]; then
    echo "Unable to parse activeSlideIndex after previous command"
    exit 1
  fi

done

nav_mean="$(mean_seconds < "$nav_times_file")"
nav_max="$(awk 'BEGIN { max = 0 } { if ($1 > max) max = $1 } END { printf "%.3f", max }' "$nav_times_file")"

if [[ ! -s "$nav_times_file" ]]; then
  echo "No navigation samples were collected"
  exit 1
fi

initial_pass="FAIL"
if compare_leq "$initial_total" "$INITIAL_TARGET_SECONDS"; then
  initial_pass="PASS"
fi

nav_pass="FAIL"
if compare_leq "$nav_mean" "$NAV_TARGET_SECONDS"; then
  nav_pass="PASS"
fi

run_time_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > "$OUT_FILE" <<EOF
# Controller Performance Results

- Run timestamp (UTC): $run_time_utc
- Base URL: $BASE_URL
- Course ID: $COURSE_ID
- Iterations (next/previous pairs): $ITERATIONS
- Initial target: <= ${INITIAL_TARGET_SECONDS}s
- Navigation target (mean next): <= ${NAV_TARGET_SECONDS}s

## Measurements

- Presentation fetch: ${presentation_time}s
- First slide fetch: ${slide_time}s
- Initial total (presentation + first slide): ${initial_total}s -> ${initial_pass}
- Next navigation mean: ${nav_mean}s -> ${nav_pass}
- Next navigation max: ${nav_max}s

## Raw Next Navigation Times (s)

\
$(tr '\n' ' ' < "$nav_times_file")

EOF

echo "Performance report written to $OUT_FILE"
