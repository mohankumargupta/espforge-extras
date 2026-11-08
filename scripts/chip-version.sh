#!/usr/bin/env bash
# scripts/chip-version.sh — single source of truth for chip part types and release tags.
#
# Chip tags look like:  chip-<example>-<major>.<minor>.<patch>
# First release is 0.0.1; every later release bumps the patch of the highest existing tag.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_SLUG="${GITHUB_REPO:-mohankumargupta/espforge-extras}"

# Dependency key used in diagram.json for the chip part.
#   part-type -> "chip-chip"   (what third-party Wokwi chips do: key == part type)
#   name      -> "chip"        (legacy behaviour of the old scripts; fallback only)
CHIP_KEY_MODE="${CHIP_KEY_MODE:-part-type}"

die() { printf 'chip-version: %s\n' "$*" >&2; exit 1; }

validate_example() {
    case "${1:-}" in
        '' | *[!a-z0-9_]*) die "invalid example name '${1:-}'" ;;
    esac
}

# wokwi/ wins because that is the copy the viewer actually reads.
diagram_path() {
    local ex="$1"
    if [ -f "$ROOT_DIR/wokwi/$ex/diagram.json" ]; then
        printf '%s\n' "$ROOT_DIR/wokwi/$ex/diagram.json"
    elif [ -f "$ROOT_DIR/espforge-examples-generated/$ex/diagram.json" ]; then
        printf '%s\n' "$ROOT_DIR/espforge-examples-generated/$ex/diagram.json"
    else
        die "no diagram.json for '$ex' in wokwi/ or espforge-examples-generated/"
    fi
}

# Prints "chip-<name>" from the first chip part in the diagram, empty if none.
part_type() {
    python3 - "$1" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    diagram = json.load(f)
for part in diagram.get("parts", []):
    kind = part.get("type", "")
    if kind.startswith("chip-"):
        print(kind)
        break
PY
}

chip_key() {
    local kind="$1"
    if [ "$CHIP_KEY_MODE" = "name" ]; then
        printf '%s\n' "${kind#chip-}"
    else
        printf '%s\n' "$kind"
    fi
}

cmd_name() {
    local ex="${1:-}"
    validate_example "$ex"
    local kind
    kind="$(part_type "$(diagram_path "$ex")")"
    [ -n "$kind" ] || die "'$ex' has no chip-* part in diagram.json"
    chip_key "$kind"
}

cmd_fetch() {
    git -C "$ROOT_DIR" fetch --tags --force --quiet
}

# Highest released version ("0.0.10"), empty when the chip has never been released.
cmd_latest() {
    local ex="${1:-}"
    validate_example "$ex"
    local prefix="chip-$ex-"
    # Strict on purpose: only chip-<example>-<major>.<minor>.<patch>.
    # Legacy 'v'-prefixed tags are ignored so the series cannot jump 0.0.N -> 1.0.N.
    git -C "$ROOT_DIR" tag -l "${prefix}*" \
        | sed -E "s/^${prefix}//" \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -V \
        | tail -n 1 \
        || true
}

cmd_latest_tag() {
    local ex="${1:-}" version
    version="$(cmd_latest "$ex")"
    [ -n "$version" ] || return 0
    printf 'chip-%s-%s\n' "$ex" "$version"
}

# Next version to publish: 0.0.1 when none exists, otherwise patch + 1.
cmd_next() {
    local ex="${1:-}" latest major minor patch
    latest="$(cmd_latest "$ex")"
    if [ -z "$latest" ]; then
        printf '0.0.1\n'
        return 0
    fi
    IFS=. read -r major minor patch <<< "$latest"
    printf '%s.%s.%s\n' "$major" "$minor" "$((patch + 1))"
}

cmd_next_tag() {
    printf 'chip-%s-%s\n' "${1:-}" "$(cmd_next "${1:-}")"
}

cmd_exists() {
    git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/${1:-}" >/dev/null 2>&1
}

# Tag currently pinned in the diagram, empty when dependencies is empty.
cmd_pinned() {
    local ex="${1:-}" key
    validate_example "$ex"
    key="$(cmd_name "$ex")"
    python3 - "$(diagram_path "$ex")" "$key" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    deps = json.load(f).get("dependencies") or {}
value = deps.get(sys.argv[2], "") if isinstance(deps, dict) else ""
print(value.split("@", 1)[1] if "@" in value else "")
PY
}

cmd="${1:-}"
shift || true
case "$cmd" in
    fetch)      cmd_fetch ;;
    latest)     cmd_latest "$@" ;;
    latest-tag) cmd_latest_tag "$@" ;;
    next)       cmd_next "$@" ;;
    next-tag)   cmd_next_tag "$@" ;;
    name)       cmd_name "$@" ;;
    pinned)     cmd_pinned "$@" ;;
    exists)     cmd_exists "$@" ;;
    *)
        cat >&2 <<'USAGE'
usage: scripts/chip-version.sh <command> [example|tag]

  fetch                  fetch all tags from origin
  latest <ex>            highest released version, empty if never released
  latest-tag <ex>        "chip-<ex>-<version>", empty if never released
  next <ex>              version the next release must use
  next-tag <ex>          full tag the next release must use
  name <ex>              dependency key for the example's chip part
  pinned <ex>            tag pinned in the example's diagram, empty if none
  exists <tag>           exit 0 if the tag exists locally

  env: CHIP_KEY_MODE=part-type|name (default part-type), GITHUB_REPO=owner/repo
USAGE
        exit 2
        ;;
esac
