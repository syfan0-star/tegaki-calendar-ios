#!/bin/bash
# What the runner looked like when a job was cancelled (1.4 D1d; docs/M7D.md, 実行機の打ち切り). On the image xcode-27
# four jobs ended with only "The operation was canceled." (D0's span-shots twice, the quick paths r14-q-d1 and r14-q-d1b):
# no one cancelled them, no limit was reached, and GitHub kept no reason. So the last step of every job on xcode-27 of
# build.yml and duo.yml runs this when, and only when, the job was cancelled (`if: cancelled()`: by hand, by the job's
# time limit, or by the runner's side), and prints:
#   - the time, the image, the job, uptime (the load), `memory_pressure -Q`, `vm_stat`, `sysctl vm.swapusage` (with
#     hw.ncpu and hw.memsize), and the 15 processes using the most CPU (`ps -r`; the program, not its arguments);
#   - from the runner's own diagnostic folder (_diag: tried at $RUNNER_TEMP/../_diag, $RUNNER_TEMP/../../_diag, beside the
#     running Runner.Worker and Runner.Listener (<root>/bin/… → <root>/_diag), $HOME/runners/*/_diag and
#     $HOME/actions-runner/_diag), ONLY the lines of Runner_*.log and Worker_*.log that match
#     cancel|Cancel|shutdown|Shutdown|lost|disconnect: the newest $DIAG_MAX (200) of them, each cut to 300 characters,
#     anything like a token, a signature or a long key blanked. The repository is public: the _diag folder is never
#     uploaded and never printed whole.
# Every command has a limit of its own (20 s) and a missing command or folder is a line, not an error. Always exits 0.
#
# Usage: bash tools/ci/cancel-diag.sh   (DIAG_MAX, DIAG_ROOTS: more folders to look in, one a line, for a test)
set -u

DIAG_MAX="${DIAG_MAX:-200}"
case "$DIAG_MAX" in ''|*[!0-9]*) DIAG_MAX=200 ;; esac
PATTERN='cancel|Cancel|shutdown|Shutdown|lost|disconnect'

section() {  # section <title>
  echo ""
  echo "== $*"
}

limited() {  # limited <seconds> <command…>: the command, ended after <seconds> (TERM, KILL 5 s later); never fatal
  local LIMIT="$1" PID WATCH STATUS=0
  shift
  if ! command -v "$1" > /dev/null 2>&1; then
    echo "($1: not on this runner)"
    return 0
  fi
  "$@" 2>&1 &
  PID=$!
  # The watcher's sleep writes nothing and dies with it, so no process is left holding the step's output.
  (
    trap 'kill "$NAP" 2>/dev/null; exit 0' TERM
    sleep "$LIMIT" > /dev/null 2>&1 &
    NAP=$!
    wait "$NAP"
    if kill -TERM "$PID" 2>/dev/null; then
      echo "(stopped after $LIMIT s)"
      sleep 5 > /dev/null 2>&1 &
      NAP=$!
      wait "$NAP"
      kill -KILL "$PID" 2>/dev/null || true
    fi
  ) &
  WATCH=$!
  wait "$PID" 2>/dev/null || STATUS=$?
  kill -TERM "$WATCH" 2>/dev/null || true
  wait "$WATCH" 2>/dev/null || true
  [ "$STATUS" = 0 ] || echo "($1 ended with $STATUS)"
  return 0
}

redact() {  # stdin → stdout: tokens, signatures, keys and long base64 runs blanked, each line cut to 300 characters
  sed -E \
    -e 's/eyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}/[jwt]/g' \
    -e 's/gh[pousr]_[A-Za-z0-9]{16,}/[token]/g' \
    -e 's/([Tt]oken|TOKEN|[Ss]ecret|SECRET|[Pp]assword|PASSWORD|[Aa]uthorization|AUTHORIZATION|[Bb]earer|[Ss]ig|[Kk]ey|KEY)([\"]?[=:]+[\"]?[[:space:]]*|[[:space:]]+)[^[:space:]\",;&)]+/\1\2[redacted]/g' \
    -e 's/[A-Za-z0-9+_-]{40,}={0,2}/[long]/g' 2>/dev/null | cut -c1-300
}

diag_dirs() {  # the candidate _diag folders, one a line (existing or not)
  if [ -n "${RUNNER_TEMP:-}" ]; then
    echo "$RUNNER_TEMP/../_diag"
    echo "$RUNNER_TEMP/../../_diag"
  fi
  { ps -Ao comm= 2>/dev/null; ps -Ao args= 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) print $i }'; } | grep -E '/bin/Runner\.(Worker|Listener)(\.dll)?$' \
    | sed -E 's#/bin/Runner\.(Worker|Listener)(\.dll)?$#/_diag#' || true
  for D in "${HOME:-/nonexistent}"/runners/*/_diag "${HOME:-/nonexistent}"/actions-runner/_diag /Users/runner/runners/*/_diag; do
    echo "$D"
  done
  if [ -n "${DIAG_ROOTS:-}" ]; then printf '%s\n' "$DIAG_ROOTS"; fi
}

echo "Diagnostics of a cancelled job (tools/ci/cancel-diag.sh; docs/M7D.md, 実行機の打ち切り)"
echo "time: $(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo '?')  image: ${ImageOS:-?} ${ImageVersion:-?}  job: ${GITHUB_JOB:-?}  run: ${GITHUB_RUN_ID:-?} attempt ${GITHUB_RUN_ATTEMPT:-?}"

section "uptime"
limited 20 uptime
section "memory_pressure -Q"
limited 20 memory_pressure -Q
section "vm_stat"
limited 20 vm_stat
section "sysctl vm.swapusage hw.ncpu hw.memsize"
limited 20 sysctl vm.swapusage hw.ncpu hw.memsize
section "the 15 processes using the most CPU (ps -r)"
limited 20 sh -c 'ps -Ao pid,ppid,pcpu,pmem,rss,etime,state,comm -r 2>&1 | head -n 16'

section "the runner's _diag: lines matching ${PATTERN} in Runner_*.log and Worker_*.log (the newest ${DIAG_MAX}, never the whole folder)"
SEEN=""
FILES=""
while IFS= read -r CANDIDATE; do
  [ -n "$CANDIDATE" ] && [ -d "$CANDIDATE" ] || continue
  REAL="$(cd "$CANDIDATE" 2>/dev/null && pwd -P)" || continue
  case "
$SEEN
" in *"
$REAL
"*) continue ;; esac
  SEEN="$SEEN
$REAL"
  echo "folder: $REAL"
  # The logs oldest first, so the last lines kept are the newest (`ls -tr`: names without spaces, Runner_<time>-utc.log).
  LIST="$(cd "$REAL" && ls -1tr Runner_*.log Worker_*.log 2>/dev/null || true)"
  if [ -z "$LIST" ]; then
    echo "  (no Runner_*.log or Worker_*.log)"
    continue
  fi
  while IFS= read -r NAME; do
    [ -n "$NAME" ] && [ -f "$REAL/$NAME" ] || continue
    FILES="$FILES
$REAL/$NAME"
  done <<EOF
$LIST
EOF
done <<EOF
$(diag_dirs)
EOF
if [ -z "$SEEN" ]; then
  echo "(no _diag folder found)"
elif [ -z "$FILES" ]; then
  echo "(no runner log in the folders above)"
else
  MATCHES="${RUNNER_TEMP:-/tmp}/cancel-diag.$$"
  : > "$MATCHES" 2>/dev/null || MATCHES=/dev/null
  while IFS= read -r FILE; do
    [ -n "$FILE" ] || continue
    { grep -E "$PATTERN" "$FILE" 2>/dev/null || true; } | sed "s#^#${FILE##*/}: #" >> "$MATCHES" 2>/dev/null || true
  done <<EOF
$FILES
EOF
  if [ "$MATCHES" = /dev/null ]; then
    echo "(the matching lines could not be gathered)"
  else
    TOTAL="$(wc -l < "$MATCHES" | tr -d ' ')"
    echo "$TOTAL matching lines in $(printf '%s\n' "$FILES" | grep -c . | tr -d ' ') logs; the newest ${DIAG_MAX} of them:"
    tail -n "$DIAG_MAX" "$MATCHES" | redact
    rm -f "$MATCHES"
  fi
fi
exit 0
