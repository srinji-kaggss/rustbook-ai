#!/usr/bin/env bash
#
# keel-zero-gate.sh — every gated file scores clean, or nothing merges.
#
# ─── THE LAW ────────────────────────────────────────────────────────────────
#
# Director, 2026-07-27, verbatim:
#
#   "pls actually just add it as an unmergeable gate across repo. If each file
#    does not have the highest score, it cannot merge. no matter how much you
#    beg. I am sick and tired of you passing technical debt for later. No
#    matter how critical code is. it has to get the highest score on every atom
#    of every file."
#
# and, when it was tested the same day:
#
#   "unmerge, excellence law is immutable, you will wait."
#
# This gate is the mechanical form of that. It is installed in EVERY repo we
# own, and installing it is the FIRST action in any new one — before the first
# feature, while the count is still zero and staying at zero is free.
#
# ─── WHY NOT A RATCHET ──────────────────────────────────────────────────────
#
# logic-os-kernel ran one: compare the finding count to a stored baseline, pass
# while no rule ROSE. Its own header argued a zero gate "would be red for 913
# reasons on day one and switched off inside a week". What a ratchet actually
# produced, measured over one day:
#
#   - 165 findings merged to main as "at the ceiling" — no regression, and not
#     excellent. Debt merged because the gate permitted it.
#   - four stacked PRs verified against baselines that no longer reproduced,
#     because the scanner was rebuilt mid-drain and one rule went 9 -> 20.
#   - a planted CC-19 regression sitting at rc=0, because it fit inside the
#     headroom the drain had just created. Gate green, code worse.
#
# A ratchet does not prevent debt. It amortises it, and the schedule never ends.
#
# ─── WHAT THIS GATE WILL NOT DO ─────────────────────────────────────────────
#
# No --update. No baseline file. No allowlist, no per-rule budget, no "known
# issues" set, no environment variable that lowers the bar. If you are reading
# this because the gate is red and you want it green, the only supported action
# is to fix what it printed.
#
# `keel-allow:` / `keel-allow-file:` are REFUSED (exit 4). Those say "this
# finding is real and I am hiding it" — the begging the law names. Adding one
# does not make this pass; it makes it fail differently and more loudly.
#
# `keel-math-names:` is ALLOWED and reported. It declares that `t` in an easing
# function, or `n`/`e` in an RFC 7518 JWK, are the CORRECT domain names rather
# than lazy ones — renaming them would make the code worse. A declaration that
# improves correctness is not a suppression that hides a defect. That is the
# only line, and it is drawn on which direction the annotation moves the code.
#
# ─── EXCLUSIONS ─────────────────────────────────────────────────────────────
#
# Defaults are source this repo does not author: vendor/, node_modules/,
# target/, third_party/, .venv/. Anything else must be listed in
# `.keel/gate-exclusions`, one per line, as:
#
#     <path-prefix-or-glob>    # REASON, mandatory
#
# A line without a reason is refused (exit 5). Every exclusion is PRINTED on
# every run — an exclusion nobody sees is where the debt hides next.
#
# ─── EXIT CODES — each names a different action ─────────────────────────────
#
#   0  every gated file clean. The only passing state.
#   1  keel-scan could not read/parse an input. A PARTIAL scan is not green.
#   2  findings exist. Merge blocked. Fix them.
#   3  keel-scan absent or unrunnable. The gate cannot report.
#   4  a suppression annotation is present. Remove it, fix the finding.
#   5  an exclusion carries no reason.
#
set -uo pipefail

BOLD=$'\033[1m'; RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; OFF=$'\033[0m'
die()  { printf '%sFAIL%s keel-zero-gate: %s\n' "$RED" "$OFF" "$1" >&2; exit "${2:-1}"; }
note() { printf '     %s\n' "$1"; }

cd "$(git rev-parse --show-toplevel)" || die "not inside a git worktree" 3

DEFAULT_EXCLUDE='^vendor/|(^|/)node_modules/|(^|/)target/|(^|/)third_party/|(^|/)\.venv/'

# ── selftest: prove the gate can say YES as well as NO ──────────────────────
# //why: a gate that is red on every input is indistinguishable from a gate
# that is broken. Most repos are not at zero yet, so the only way to observe a
# PASS is against a synthetic clean fixture.
if [[ "${1:-}" == "--selftest" ]]; then
  command -v keel-scan >/dev/null 2>&1 || die "keel-scan not on PATH" 3
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  printf '//! A deliberately clean module.\n\n/// Add two numbers.\npub fn add(left: u64, right: u64) -> u64 {\n    left + right\n}\n' > "$tmp/clean.rs"
  printf '//! A deliberately dirty module.\n\npub fn f(n: i64) -> i64 {\n    let mut a = 0;\n    if n > 1 { a += 1; } if n > 2 { a += 2; } if n > 3 { a += 3; }\n    if n > 4 { a += 4; } if n > 5 { a += 5; } if n > 6 { a += 6; }\n    if n > 7 { a += 7; } if n > 8 { a += 8; } if n > 9 { a += 9; }\n    if n > 10 { a += 10; } if n > 11 { a += 11; } if n > 12 { a += 12; }\n    a\n}\n' > "$tmp/dirty.rs"
  crc=0; keel-scan "$tmp/clean.rs" >/dev/null 2>&1 || crc=$?
  drc=0; keel-scan "$tmp/dirty.rs" >/dev/null 2>&1 || drc=$?
  printf '%s── keel-zero-gate selftest%s\n' "$BOLD" "$OFF"
  note "clean fixture -> keel-scan rc=$crc (expect 0)"
  note "dirty fixture -> keel-scan rc=$drc (expect 2)"
  [[ "$crc" == "0" && "$drc" == "2" ]] \
    || die "selftest FAILED — this gate cannot tell clean from dirty, so its verdict means nothing" 3
  printf '%sOK%s   keel-zero-gate: selftest passed — the gate can report BOTH verdicts\n' "$GRN" "$OFF"
  exit 0
fi

command -v keel-scan >/dev/null 2>&1 || die "keel-scan is not on PATH. This gate reports NOTHING
     without it and must not be counted as coverage. Build it from the keel repo:
       cargo build --release -p keel-core --bin keel-scan
       ln -s \"\$PWD/keel-core/target/release/keel-scan\" ~/.local/bin/keel-scan" 3

# ── tool provenance ─────────────────────────────────────────────────────────
# //why printed every run: on 2026-07-27 keel-scan was rebuilt mid-drain and a
# rule went 9 -> 20 findings on an untouched branch. Four PRs had been verified
# against baselines measured with the older binary; none reproduced. A verdict
# is only meaningful next to the version that produced it.
bin="$(command -v keel-scan)"; real="$(readlink -f "$bin" 2>/dev/null || echo "$bin")"
printf '%s── keel-zero-gate%s  (threshold: ZERO findings — no baseline, no allowlist)\n' "$BOLD" "$OFF"
note "repo    : $(basename "$PWD")"
note "scanner : $real"
note "built   : $(date -r "$real" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo unknown)"

# ── extra exclusions, each of which must carry a reason ─────────────────────
EXTRA=''
if [[ -f .keel/gate-exclusions ]]; then
  while IFS= read -r line; do
    [[ -z "${line// }" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ ! "$line" =~ \# ]]; then
      die "exclusion without a reason in .keel/gate-exclusions:
       $line
     Every exclusion must read '<path>  # REASON'. An exclusion nobody can
     justify is debt with better paperwork." 5
    fi
    pat="${line%%#*}"; reason="${line#*#}"
    # //why pure-bash trim and not `| xargs`: xargs parses quotes, so a reason
    # containing an apostrophe ("the fixture's contract") dies with
    # "unterminated quote" and the reason prints EMPTY — an exclusion that
    # silently loses its justification is the exact failure this file bans.
    trim() { local v="$1"; v="${v#"${v%%[![:space:]]*}"}"; printf '%s' "${v%"${v##*[![:space:]]}"}"; }
    pat="$(trim "$pat")"; reason="$(trim "$reason")"
    [[ -z "$pat" ]] && continue
    EXTRA="${EXTRA:+$EXTRA|}$pat"
    note "EXCLUDED: $pat — $reason"
  done < .keel/gate-exclusions
fi

FILTER="$DEFAULT_EXCLUDE${EXTRA:+|$EXTRA}"
mapfile -t FILES < <(git ls-files | grep -E '\.(rs|md|sh)$' | grep -vE "$FILTER")
n_def=$(git ls-files | grep -E '\.(rs|md|sh)$' | grep -cE "$DEFAULT_EXCLUDE")
note "gated   : ${#FILES[@]} tracked .rs/.md/.sh files"
note "EXCLUDED: $n_def by default (vendor/node_modules/target/third_party/.venv — not ours)"

if [[ ${#FILES[@]} -eq 0 ]]; then
  printf '%sOK%s   keel-zero-gate: no gated source in this repo — nothing to score.\n' "$GRN" "$OFF"
  exit 0
fi

# ── untracked source is invisible to `git ls-files` ─────────────────────────
# //why: a file written but not staged is not scanned, so a local run can read
# clean over source the author is actively writing. Caught the hard way.
mapfile -t UNTRACKED < <(git ls-files --others --exclude-standard | grep -E '\.(rs|md|sh)$' | grep -vE "$FILTER")
if [[ ${#UNTRACKED[@]} -gt 0 ]]; then
  printf '%s     WARNING%s %d untracked source file(s) are NOT in this scan:\n' "$YEL" "$OFF" "${#UNTRACKED[@]}"
  printf '             %s\n' "${UNTRACKED[@]}"
  note '         git-add them before trusting a clean result.'
fi

# ── the bypass ban ──────────────────────────────────────────────────────────
# //why ANCHORED to a comment opener rather than a bare substring: the first
# draft matched any MENTION of the token, so a sibling script's error message
# ("do NOT add keel-allow:") tripped the gate instead of reporting real
# findings. A detector that fires on prose about itself is a false positive,
# and a guard's false positive teaches people to route around the guard.
if sup=$(git grep -n -E '^[[:space:]]*(//|#)!?[[:space:]]*keel-allow(-file)?:' \
           -- '*.rs' '*.md' '*.sh' 2>/dev/null \
           | grep -vE '(^|/)keel-zero-gate\.sh:'); then
  printf '\n%sFAIL%s keel-zero-gate: SUPPRESSION ANNOTATION PRESENT\n\n' "$RED" "$OFF" >&2
  printf '%s\n' "$sup" | sed 's/^/     /' >&2
  printf '\n     This annotation hides a finding instead of fixing it. This gate refuses it\n' >&2
  printf "     by design — see this file's header. Remove it and fix the finding.\n" >&2
  exit 4
fi

declarations=$(git grep -c -F 'keel-math-names:' -- '*.rs' '*.md' '*.sh' 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
note "declared domain vocabulary (keel-math-names, allowed): $declarations"

# ── the scan ────────────────────────────────────────────────────────────────
# keel-scan writes findings to STDERR and exits 2 when it finds anything, so
# both streams are captured and the exit code read explicitly.
scan_rc=0
scan_out="$(keel-scan "${FILES[@]}" 2>&1)" || scan_rc=$?

case "$scan_rc" in
  1) printf '%s\n' "$scan_out" >&2
     die "keel-scan exited 1 — it could not read or parse at least one input. A partial
     scan reports nothing and must never render green." 1 ;;
  0|2) ;;
  *) printf '%s\n' "$scan_out" >&2
     die "keel-scan exited $scan_rc (not the documented 0/1/2) — a tool failure, not zero
     findings." 3 ;;
esac

findings="$(grep -oE '\[[a-z]+/[A-Za-z0-9_-]+\]' <<<"$scan_out" | wc -l | tr -d ' ')"

if [[ "$findings" == "0" ]]; then
  printf '%sOK%s   keel-zero-gate: %d files, ZERO findings. Every atom clean.\n' "$GRN" "$OFF" "${#FILES[@]}"
  exit 0
fi

printf '\n%sFAIL%s keel-zero-gate: %s%d findings%s across %d files — MERGE BLOCKED\n\n' \
  "$RED" "$OFF" "$BOLD" "$findings" "$OFF" "${#FILES[@]}" >&2
printf '  by rule:\n' >&2
grep -oE '\[[a-z]+/[A-Za-z0-9_-]+\]' <<<"$scan_out" | sort | uniq -c | sort -rn | sed 's/^/    /' >&2
printf '\n  by file (worst first):\n' >&2
grep -oE '^[^:]+\.(rs|md|sh):' <<<"$scan_out" | tr -d ':' | sort | uniq -c | sort -rn | head -25 | sed 's/^/    /' >&2
printf '\n  full output:\n' >&2
printf '%s\n' "$scan_out" | grep -E '\[[a-z]+/[A-Za-z0-9_-]+\]' | sed 's/^/    /' >&2
printf '\n  The threshold is ZERO. There is no baseline to raise, no allowlist to extend,\n' >&2
printf '  and no flag that lowers it. Fix the findings above.\n' >&2
exit 2
