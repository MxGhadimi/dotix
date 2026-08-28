#!/usr/bin/env bash
# ci.sh              check only (default)
# ci.sh --fix        autofix first, then check
# ci.sh --build      also build every CI host
# ci.sh --quick      skip `nix flake check`
# ci.sh --fix --build --quick

set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1

command -v nix >/dev/null 2>&1 || {
  echo "error: nix not found on PATH" >&2
  exit 127
}

STATIX_CONFIG=".github/statix.toml"

do_fix=0
do_build=0
do_flake=1

for arg in "$@"; do
  case "$arg" in
  --fix) do_fix=1 ;;
  --build) do_build=1 ;;
  --quick) do_flake=0 ;;
  -h | --help)
    awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
    exit 0
    ;;
  *)
    echo "unknown option: $arg (try --help)" >&2
    exit 2
    ;;
  esac
done

# output -

if [[ -t 1 ]]; then
  BOLD=$'\e[1m' RED=$'\e[31m' GREEN=$'\e[32m' BLUE=$'\e[34m' DIM=$'\e[2m' OFF=$'\e[0m'
else
  BOLD='' RED='' GREEN='' BLUE='' DIM='' OFF=''
fi

step() { printf '\n%s==>%s %s%s%s\n' "$BLUE" "$OFF" "$BOLD" "$1" "$OFF"; }
note() { printf '%s    %s%s\n' "$DIM" "$1" "$OFF"; }

results=()
failed=0

record() { # record <name> <status>
  results+=("$2 $1")
  [[ $2 == fail ]] && failed=1
  return 0
}

# tools -

tool() {
  local name="$1"
  shift
  if command -v "$name" >/dev/null 2>&1; then
    "$name" "$@"
  else
    nix run "nixpkgs#$name" -- "$@"
  fi
}

nix_files() { git ls-files -z '*.nix'; }

alejandra_on() {
  if command -v alejandra >/dev/null 2>&1; then
    nix_files | xargs -0 -r alejandra "$@"
  else
    nix_files | xargs -0 -r nix run nixpkgs#alejandra -- "$@"
  fi
}

statix_args=(check . --config "$STATIX_CONFIG")
[[ -f $STATIX_CONFIG ]] || {
  note "no $STATIX_CONFIG, using statix defaults"
  statix_args=(check .)
}

# fix -

if ((do_fix)); then
  step "fix: statix"
  if [[ -f $STATIX_CONFIG ]]; then
    tool statix fix . --config "$STATIX_CONFIG"
  else
    tool statix fix .
  fi

  step "fix: deadnix"
  tool deadnix --edit .

  step "fix: alejandra"
  alejandra_on --quiet
  note "fixers done, now verifying"
fi

# check -

step "formatting (alejandra --check)"
if alejandra_on --check; then
  record formatting pass
else
  record formatting fail
  note "fix with: ./scripts/ci.sh --fix"
fi

step "statix"
statix_out=$(tool statix "${statix_args[@]}" 2>&1)
statix_rc=$?
[[ -n $statix_out ]] && printf '%s\n' "$statix_out"
if ((statix_rc == 0)); then
  record statix pass
else
  record statix fail
fi

step "deadnix"
if tool deadnix --fail .; then
  record deadnix pass
else
  record deadnix fail
fi

if ((do_flake)); then
  step "nix flake check"
  if nix flake check --show-trace; then
    record "flake check" pass
  else
    record "flake check" fail
  fi
else
  note "skipped nix flake check (--quick)"
fi

if ((do_build)); then
  hosts=$(nix eval .#nixosConfigurations --apply '
    configs:
      builtins.filter
        (h: configs.${h}.config.custom.ci.buildable)
        (builtins.attrNames configs)
  ' --json 2>/dev/null | tr -d '[]"' | tr ',' ' ')

  if [[ -z ${hosts// /} ]]; then
    step "host builds"
    note "could not evaluate the CI host list, skipping"
  fi

  for host in $hosts; do
    step "build $host"
    if nix build -L --keep-going ".#nixosConfigurations.$host.config.system.build.toplevel"; then
      record "build $host" pass
    else
      record "build $host" fail
    fi
  done
fi

# summary -

printf '\n%s summary %s\n' "$BOLD" "$OFF"
for entry in "${results[@]}"; do
  status=${entry%% *}
  name=${entry#* }
  if [[ $status == pass ]]; then
    printf '  %s✓%s %s\n' "$GREEN" "$OFF" "$name"
  else
    printf '  %s✗%s %s\n' "$RED" "$OFF" "$name"
  fi
done

echo
if ((failed)); then
  printf '%sCI would fail.%s\n' "$RED$BOLD" "$OFF"
  exit 1
fi
printf '%sAll green — safe to push.%s\n' "$GREEN$BOLD" "$OFF"
