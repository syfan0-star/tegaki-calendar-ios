# The handwriting's check of a photo and its retake (docs/M7D_CONTRACT.md §3.5 (f); docs/M7D.md, D0b). Sourced (`.`)
# by the photo steps of build.yml and ja-baseline.yml (J-4: the same lines in both; ja-baseline.yml reads this file
# from the pushed commit, as tools/shots/screen_ready.swift) and by build.yml's l10n-shots.
#
# In D0 (run 44632524223) the photos taken on the image 20261119.0378.1 (macOS 27.2 hosts) lacked part of their demo
# handwriting: 4 of build-and-test's 54, 11 of l10n-shots' 50 with handwriting. Whole PencilKit tiles (512 lu) were not
# shown; the canvas held every stroke, the save bytes were the same (gate 2), and the same photos of attempt 2 (image
# 20261104.0337.1) were complete and otherwise the same to the pixel. Whether such tiles come late or never is not known.
# So each photo is checked with tools/shots/ink_check.swift against its line in tools/shots/ink_ref.tsv, and a photo
# whose handwriting is short is taken again with the same launch and the same wait (a new launch draws it anew), at
# most twice; then the take with the fewest pixels short stays, with a warning. A complete photo is kept as it was
# taken (same arguments and waits as before; J-4 compares complete photos). Every result goes into $INK_LOG.
#
#   ink_build                         makes $INK ready: waits for (at most 300 s) and takes the build of the step "Build
#                                     the handwriting check in the background" (both workflows, before the boot), else
#                                     compiles ink_check in the background here (once a job; the first check waits)
#   ink_read <file> <name> <take>     checks one photo: INK_STATUS (0 complete or not checked, 1 short, 2 unreadable or
#                                     another size) and INK_SHORT (pixels short); one line in $INK_LOG
#   ink_retake <file> <name> <wait s> <the launch's arguments after the bundle id…>
#                                     after a photo: up to 2 more takes when its handwriting is short; the best one stays
#                                     (a notice when a retake is complete, a warning when none is)
#   ink_hint <file> <name> <take> <seconds from the launch to the photo> <the toast's seconds>
#                                     the pinch hint's 2 takes: 0 when this take stays (written in time and its
#                                     handwriting complete), else 1 (after take 2 the better take stays: in time first,
#                                     then fewer pixels short; both late and complete: take 2, as before; a notice when
#                                     take 2 stays complete after a short take 1)
#
# The caller has UDID and BUNDLE. INK_LOG (default shots/ink.txt), INK_SKIP (1: no check, for photos taken again later)
# and INK_STALE (photos that stayed short; reset it per device) are the caller's to set. A short photo is still checked
# and warned of, but not taken again, after 3 photos of a device stayed short (the reference may be stale: renew its
# line with `ink_check ref`, tools/shots/ink_check.swift) or once a step's takes again have cost INK_BUDGET seconds
# (default 180; a photo already being taken again finishes its takes). A failed retake (its launch or its screenshot)
# puts take 1 back and does not count as a photo that stayed short. So a photo is taken at most 3 times, and a step
# spends at most about INK_BUDGET + 2 takes on it. At D0's slowest pace (an estimate: about 35 s a take there, 12–15 s
# on a healthy image) that is about 4.2 min for each of the two photo steps, and the pinch hints' second takes (ink_hint,
# not in the budget; 2 in build-and-test and in ja-baseline) about 1.2: about 9.5 min a job over the estimates behind
# D0b's limits (build-and-test 141 of 160 min, ja-baseline 114 of 130; docs/M7D.md, D0b), which keeps about 9 and 6.

INK="${RUNNER_TEMP:-/tmp}/ink_check"
INK_REF="${GITHUB_WORKSPACE:-.}/tools/shots/ink_ref.tsv"
INK_BEST="${RUNNER_TEMP:-/tmp}/ink-best.png"
INK_LOG="${INK_LOG:-shots/ink.txt}"
INK_SKIP="${INK_SKIP:-0}"
INK_STALE="${INK_STALE:-0}"
INK_BUDGET="${INK_BUDGET:-180}"
INK_SPENT=0
INK_BUILD=""
INK_HINT_FIRST=""

ink_build() {  # ink_build: the background build of an earlier step, else swiftc in the background here
  local BG="${RUNNER_TEMP:-/tmp}/ink_check.build" WAITED=0 PID
  [ ! -x "$INK" ] || return 0
  if [ -f "$BG/pid" ]; then
    PID="$(cat "$BG/pid" 2>/dev/null || true)"
    while [ ! -f "$BG/status" ] && [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null && [ "$WAITED" -lt 300 ]; do
      sleep 1
      WAITED=$((WAITED + 1))
    done
    if [ "$(cat "$BG/status" 2>/dev/null || true)" = 0 ] && [ -x "$BG/ink_check" ] && cp -f "$BG/ink_check" "$INK"; then
      echo "tools/shots/ink_check.swift was built in the background (waited for it ${WAITED} s here)."
      return 0
    fi
    echo "::warning::the background build of tools/shots/ink_check.swift did not end well; it is built here."
    cat "$BG/log" 2>/dev/null || true
  fi
  ( swiftc -O "${GITHUB_WORKSPACE:-.}/tools/shots/ink_check.swift" -o "$INK.part.$$" > "$INK.log.$$" 2>&1 && mv -f "$INK.part.$$" "$INK" ) &
  INK_BUILD=$!
}

ink_read() {  # ink_read <file> <name in ink_ref.tsv> <take>
  local LINE STATUS=0
  INK_STATUS=0
  INK_SHORT=0
  if [ -n "$INK_BUILD" ]; then
    wait "$INK_BUILD" 2>/dev/null || true
    INK_BUILD=""
    if [ ! -x "$INK" ]; then
      echo "::warning::tools/shots/ink_check.swift did not compile; no photo is checked for its handwriting (docs/M7D.md, D0b)."
      cat "$INK.log.$$" 2>/dev/null || true
    fi
  fi
  [ -x "$INK" ] || return 0
  LINE="$("$INK" "$1" "$INK_REF" "$2" 2>&1)" || STATUS=$?
  printf '%s\ttake %s\t%s\n' "$2" "$3" "$LINE" >> "$INK_LOG" 2>/dev/null || true
  case "$LINE" in
    *" px short"*) INK_SHORT="${LINE%% px short*}"; INK_SHORT="${INK_SHORT##*(}" ;;
  esac
  case "$INK_SHORT" in ''|*[!0-9]*) INK_SHORT=0 ;; esac
  case "$STATUS" in
    0) ;;
    1) INK_STATUS=1; echo "$LINE (take $3)" ;;
    *) INK_STATUS=2; echo "$LINE (take $3)" ;;
  esac
}

ink_retake() {  # ink_retake <file> <name in ink_ref.tsv> <wait s> <the launch's arguments after the bundle id…>
  local FILE="$1" NAME="$2" WAIT="$3" TAKE TAKES=1 BEST_TAKE=1 BEST_SHORT FIRST_SHORT STARTED WHY=""
  shift 3
  [ "$INK_SKIP" = 0 ] || return 0
  ink_read "$FILE" "$NAME" 1
  [ "$INK_STATUS" = 1 ] || return 0
  [ "$INK_STALE" -lt 3 ] || WHY="$INK_STALE photos of this device stayed short after 3 takes (tools/shots/ink_ref.tsv stale?)"
  [ "$INK_SPENT" -lt "$INK_BUDGET" ] || WHY="this step's $INK_BUDGET s for taking photos again are spent"
  if [ -n "$WHY" ]; then
    printf '%s\tkept take 1\t%s px short; not taken again: %s\n' "$NAME" "$INK_SHORT" "$WHY" >> "$INK_LOG" 2>/dev/null || true
    echo "::warning::$NAME: its handwriting is short ($INK_SHORT px) and it is not taken again: $WHY (docs/M7D.md, D0b)."
    return 0
  fi
  cp -f "$FILE" "$INK_BEST" || return 0
  BEST_SHORT="$INK_SHORT"
  FIRST_SHORT="$INK_SHORT"
  STARTED="$(date +%s)"
  for TAKE in 2 3; do
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    sleep 1
    echo "$NAME: take $TAKE (its handwriting short)"
    # The caller's arguments, split as in its own launch.
    xcrun simctl launch "$UDID" "$BUNDLE" "$@" || { echo "::warning::$NAME: the launch of take $TAKE failed"; break; }
    sleep "$WAIT"
    xcrun simctl io "$UDID" screenshot "$FILE" > /dev/null 2>&1 || { echo "::warning::$NAME: take $TAKE could not be written"; break; }
    TAKES="$TAKE"
    ink_read "$FILE" "$NAME" "$TAKE"
    [ "$INK_STATUS" = 1 ] || break
    if [ "$INK_SHORT" -lt "$BEST_SHORT" ]; then
      cp -f "$FILE" "$INK_BEST" || break
      BEST_TAKE="$TAKE"
      BEST_SHORT="$INK_SHORT"
    fi
  done
  INK_SPENT=$((INK_SPENT + $(date +%s) - STARTED))
  if [ "$INK_STATUS" = 0 ]; then
    printf '%s\tkept take %s\tcomplete\n' "$NAME" "$TAKES" >> "$INK_LOG" 2>/dev/null || true
    # Visible in the run's annotations: J-4 then compares the complete retake (docs/M7D.md, D0b).
    echo "::notice::$NAME: its handwriting was short on take 1 ($FIRST_SHORT px) and complete on take $TAKES, which is kept (docs/M7D.md, D0b)."
    return 0
  fi
  cp -f "$INK_BEST" "$FILE" || echo "::warning::$NAME: take $BEST_TAKE could not be put back; the last take stays"
  if [ "$TAKES" -gt 1 ]; then
    printf '%s\tkept take %s\t%s px short; %s takes\n' "$NAME" "$BEST_TAKE" "$BEST_SHORT" "$TAKES" >> "$INK_LOG" 2>/dev/null || true
    INK_STALE=$((INK_STALE + 1))
    echo "::warning::$NAME: no take had all its handwriting ($TAKES taken); take $BEST_TAKE ($BEST_SHORT px short) is kept (docs/M7D.md, D0b)."
  else
    printf '%s\tkept take 1\t%s px short; taking it again failed\n' "$NAME" "$BEST_SHORT" >> "$INK_LOG" 2>/dev/null || true
    echo "::warning::$NAME: its handwriting is short ($BEST_SHORT px) and taking it again failed; take 1 is kept (docs/M7D.md, D0b)."
  fi
}

ink_hint() {  # ink_hint <file> <name in ink_ref.tsv> <take 1|2> <seconds from the launch to the photo> <the toast's seconds>
  local LATE=0 FIRST_LATE FIRST_SHORT
  [ "$4" -le "$5" ] || LATE=1
  if [ "$INK_SKIP" = 0 ]; then ink_read "$1" "$2" "$3"; else INK_STATUS=0; INK_SHORT=0; fi
  if [ "$LATE" = 0 ] && [ "$INK_STATUS" != 1 ]; then
    FIRST_SHORT="${INK_HINT_FIRST#* }"
    if [ "$3" = 2 ] && [ -n "$INK_HINT_FIRST" ] && [ "$FIRST_SHORT" != 0 ]; then
      echo "::notice::$2: its handwriting was short on take 1 ($FIRST_SHORT px) and complete on take 2, which is kept (docs/M7D.md, D0b)."
    fi
    INK_HINT_FIRST=""
    return 0
  fi
  [ "$INK_STATUS" = 1 ] || INK_SHORT=0
  if [ "$3" = 1 ]; then
    INK_HINT_FIRST=""
    if cp -f "$1" "$INK_BEST"; then INK_HINT_FIRST="$LATE $INK_SHORT"; fi
    return 1
  fi
  if [ -n "$INK_HINT_FIRST" ]; then
    FIRST_LATE="${INK_HINT_FIRST% *}"
    FIRST_SHORT="${INK_HINT_FIRST#* }"
    if [ "$FIRST_LATE" -lt "$LATE" ] || { [ "$FIRST_LATE" = "$LATE" ] && [ "$FIRST_SHORT" -lt "$INK_SHORT" ]; }; then
      if cp -f "$INK_BEST" "$1"; then
        printf '%s\tkept take 1\t%s px short, %s\n' "$2" "$FIRST_SHORT" "$([ "$FIRST_LATE" = 0 ] && echo "in time" || echo "late")" >> "$INK_LOG" 2>/dev/null || true
        echo "$2: take 1 is kept (in time first, then fewer pixels short)"
      fi
    fi
  fi
  INK_HINT_FIRST=""
  return 1
}
