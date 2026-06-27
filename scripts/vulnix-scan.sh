#!/usr/bin/env bash

set -euo pipefail

for cmd in nix jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: $cmd is required" >&2
    exit 1
  fi
done

if command -v vulnix >/dev/null 2>&1; then
  vulnix_cmd="vulnix"
else
  store_path="$(nix build --no-link --print-out-paths 'nixpkgs#vulnix^out')"
  vulnix_cmd="${store_path}/bin/vulnix"
fi

timestamp="${VULNIX_TIMESTAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"
generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
output_dir="${VULNIX_OUTPUT_DIR:-reports/vulnix/${timestamp}}"
cache_dir="${VULNIX_CACHE_DIR:-${HOME}/.cache/vulnix}"
mkdir -p "${output_dir}" "${cache_dir}"

# build before scanning only if requested since vulnix needs just the .drv
build_system="${VULNIX_BUILD:-0}"

whitelist_args=()
if [[ -n "${VULNIX_WHITELIST:-}" ]]; then
  if [[ -f "${VULNIX_WHITELIST}" ]]; then
    whitelist_args=(-w "${VULNIX_WHITELIST}")
  else
    echo "warning: VULNIX_WHITELIST set but not found: ${VULNIX_WHITELIST}" >&2
  fi
fi

summary_json="${output_dir}/summary.json"
summary_md="${output_dir}/summary.md"
tmp_records="$(mktemp)"
trap 'rm -f "${tmp_records}"' EXIT

if [[ -n "${VULNIX_HOSTS:-}" ]]; then
  mapfile -t hosts < <(
    printf '%s' "${VULNIX_HOSTS}" \
      | tr ',' '\n' \
      | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
      | grep -v '^$'
  )
else
  mapfile -t hosts < <(
    nix eval --json .#nixosConfigurations --apply 'x: builtins.attrNames x' \
      | jq -r '.[]' \
      | sort
  )
fi

scan_failed=0

for host in "${hosts[@]}"; do
  [[ -z "$host" ]] && continue
  host_report="${output_dir}/${host}.json"

  if ! drv_path="$(nix eval --raw \
      ".#nixosConfigurations.${host}.config.system.build.toplevel.drvPath" \
      2>"${output_dir}/${host}.drv.err")"; then
    cat "${output_dir}/${host}.drv.err" >&2
    jq -cn \
      --arg host "$host" \
      --arg error "failed to evaluate drvPath" \
      '{
        host: $host, status: "error", report_file: null,
        total_findings: 0, critical: 0, high: 0, medium: 0, low: 0,
        error: $error
      }' >> "${tmp_records}"
    scan_failed=1
    continue
  fi

  nix build --no-link "${drv_path}" 2>/dev/null || true

  vulnix_scan_mode="--requisites"

  if [[ "${build_system}" == "1" ]]; then
    if ! nix build --no-link \
        ".#nixosConfigurations.${host}.config.system.build.toplevel" \
        2>"${output_dir}/${host}.build.err"; then
      cat "${output_dir}/${host}.build.err" >&2
      jq -cn \
        --arg host "$host" \
        --arg error "failed to build" \
        '{
          host: $host, status: "error", report_file: null,
          total_findings: 0, critical: 0, high: 0, medium: 0, low: 0,
          error: $error
        }' >> "${tmp_records}"
      scan_failed=1
      continue
    fi
    vulnix_scan_mode="--closure"
  fi

  set +e
  "$vulnix_cmd" \
    --json \
    "${vulnix_scan_mode}" \
    --mirror "https://mirror.cveb.in/nvd/json/cve/2.0/" \
    --cache-dir "${cache_dir}" \
    "${whitelist_args[@]}" \
    "${drv_path}" \
    > "${host_report}" \
    2>"${output_dir}/${host}.scan.err"
  scan_rc=$?
  set -e

  if [[ "${scan_rc}" -ne 0 ]] && ! jq -e 'type == "array"' "${host_report}" >/dev/null 2>&1; then
    cat "${output_dir}/${host}.scan.err" >&2
    jq -cn \
      --arg host "$host" \
      --arg error "vulnix scan failed" \
      '{
        host: $host, status: "error", report_file: null,
        total_findings: 0, critical: 0, high: 0, medium: 0, low: 0,
        error: $error
      }' >> "${tmp_records}"
    scan_failed=1
    continue
  fi

  jq -c \
    --arg host "$host" \
    --arg report_file "$(basename "${host_report}")" \
    '
      def scored:
        [ .[]
          | ((.cvssv3_basescore // {}) + (.cvssv4_basescore // {}))
          | to_entries[]
          | { id: .key, score: (.value | tonumber) } ]
        | unique_by(.id);
      {
        host: $host,
        status: "ok",
        report_file: $report_file,
        total_findings: length,
        critical: (scored | map(select(.score >= 9.0)) | length),
        high:     (scored | map(select(.score >= 7.0 and .score < 9.0)) | length),
        medium:   (scored | map(select(.score >= 4.0 and .score < 7.0)) | length),
        low:      (scored | map(select(.score < 4.0)) | length),
        error: null
      }
    ' "${host_report}" >> "${tmp_records}"
done

jq -s \
  --arg timestamp "$timestamp" \
  --arg generated_at "$generated_at" \
  --arg repo "${GITHUB_REPOSITORY:-local}" \
  --arg ref "${GITHUB_REF_NAME:-local}" \
  '{
    timestamp: $timestamp,
    generated_at: $generated_at,
    repository: $repo,
    ref: $ref,
    hosts: .
  }' "${tmp_records}" > "${summary_json}"

{
  echo "# Vulnerability Report"
  echo ""
  echo "- **Generated:** ${generated_at}"
  echo "- **Repository:** ${GITHUB_REPOSITORY:-local}"
  echo "- **Ref:** ${GITHUB_REF_NAME:-local}"
  echo ""

  echo "## Host Overview"
  echo ""
  echo "| Host | Pkgs | Crit | High | Med | Low |"
  echo "| :--- | ---: | ---: | ---: | ---: | ---: |"
  jq -r '.hosts[] | "| \(.host) | \(.total_findings) | \(.critical) | \(.high) | \(.medium) | \(.low) |"' \
    "${summary_json}"
  echo ""

  echo "## Problematic Packages"
  echo ""

  for host in "${hosts[@]}"; do
    echo "### ${host}"
    echo ""
    host_json="${output_dir}/${host}.json"

    if [[ ! -s "$host_json" ]] || ! jq -e 'type == "array" and length > 0' "$host_json" >/dev/null 2>&1; then
      echo "No vulnerable packages found."
      echo ""
      continue
    fi

    echo "| Package | CVE Count | CVEs |"
    echo "| :--- | :---: | :--- |"

    jq -r '
      .[] |
      .name as $pkg |
      .affected_by as $cves |
      ((.cvssv3_basescore // {}) + (.cvssv4_basescore // {})) as $scores |
      ($cves | map(
        . as $cve |
        ($scores[$cve] // null) |
        if . then "\($cve) (\(.))"
        else $cve
        end
      )) as $cve_list |
      "| \($pkg) | \($cves | length) | \($cve_list | join(", ")) |"
    ' "$host_json"

    echo ""
  done
} > "${summary_md}"

if [[ "${scan_failed}" -ne 0 ]]; then
  echo "some hosts failed to scan — check *.err files in ${output_dir}" >&2
  exit 2
fi