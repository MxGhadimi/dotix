#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 BASE_DIR CAND_DIR HOST [HOST ...]" >&2
  exit 1
fi

base_dir="$1"; shift
cand_dir="$1"; shift
hosts=("$@")

base_nd="$(mktemp)"
cand_nd="$(mktemp)"
trap 'rm -f "${base_nd}" "${cand_nd}"' EXIT

collect() {
  local dir="$1"; shift
  local out="$1"; shift
  : > "${out}"
  local h f
  for h in "$@"; do
    f="${dir}/${h}.json"
    [[ -s "${f}" ]] || continue
    jq -e 'type == "array"' "${f}" >/dev/null 2>&1 || continue
    jq -c --arg host "${h}" '
      .[]
      | .name as $pkg
      | ((.cvssv3_basescore // {}) + (.cvssv4_basescore // {})) as $sc
      | (.affected_by // [])[] as $cve
      | { host: $host, package: $pkg, cve: $cve, score: ($sc[$cve] // null) }
    ' "${f}" >> "${out}"
  done
}

collect "${base_dir}" "${base_nd}" "${hosts[@]}"
collect "${cand_dir}" "${cand_nd}" "${hosts[@]}"

jq -n \
  --slurpfile base "${base_nd}" \
  --slurpfile cand "${cand_nd}" \
  '
    def severity($s):
      if   $s == null then "unknown"
      elif $s >= 9.0  then "critical"
      elif $s >= 7.0  then "high"
      elif $s >= 4.0  then "medium"
      else "low"
      end;

    def summarize(arr):
      arr
      | group_by(.cve)
      | map(
          ([.[].score] | map(select(. != null)) | (if length > 0 then max else null end)) as $score
          | {
              cve: .[0].cve,
              score: $score,
              severity: severity($score),
              packages: ([.[].package] | unique),
              hosts: ([.[].host] | unique)
            }
        );

    ($base | map(.cve) | unique) as $bcves |
    ($cand | map(.cve) | unique) as $ccves |

    (summarize($cand) | map(select(.cve as $c | ($bcves | index($c)) | not))) as $introduced |
    (summarize($base) | map(select(.cve as $c | ($ccves | index($c)) | not))) as $resolved |

    {
      introduced: ($introduced | sort_by(-(.score // 0))),
      resolved:   ($resolved   | sort_by(-(.score // 0))),
      introduced_count: ($introduced | length),
      resolved_count:   ($resolved   | length)
    }
  '