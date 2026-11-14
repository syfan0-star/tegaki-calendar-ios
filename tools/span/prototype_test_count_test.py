#!/usr/bin/env python3
"""The test of span-shots' count of the prototype's tests (tools/span/prototype_test_count.py; review S5C2-SAFE-1).

    python3 -I tools/span/prototype_test_count_test.py [--count <prototype_test_count.py>]

Writes made-up xcodebuild logs, result-bundle summaries (`xcresulttool get test-results summary`) and per-test results
(`xcresulttool get test-results tests`) into a temporary folder (removed afterwards; nothing of this repository is
written), runs the count (or --count) on each case with XCODEBUILD_STATUS, and expects PASSED or FAILED with the reason
among its `::error::` lines. The FAILED cases are the ways a run could pass with fewer tests than the minimums, a failed
test, or a log and a bundle that do not agree — among them review S5C2-SAFE-1's: one class one test short while the
other class lost a passed line to the app's log, which the count before this file let through as a warning. Prints one
line per case and exits 0 when every case gives what it should, 1 otherwise. build.yml runs it on every push.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ISOLATION = "PrototypeIsolationTests"
INTERACTION = "SpanPrototypeInteractionTests"
# A passed line the app's log cut, as on 11/13 (docs/M7C.md, wave C1's lead decision 7).
CUT = ("Test Case '-[TegakiCalendarTests.SpanPrototypeIn2026-11-13 02:23:12.000 xctest[1:2] [RemoteRecognizer] "
       "a line of the app\n")


def line(cls, index, result="passed"):
    return "Test Case '-[TegakiCalendarTests.%s test%02d]' %s (0.101 seconds).\n" % (cls, index, result)


def log(isolation, interaction, cut=0, failed=None, other=None):
    """The log of `isolation` + `interaction` passed tests; the last `cut` passed lines of the interaction class cut."""
    lines = ["Test Suite 'Selected tests' started at 2026-11-15 06:00:00.000.\n"]
    lines += [line(ISOLATION, n) for n in range(isolation)]
    lines += [line(INTERACTION, n) for n in range(interaction - cut)]
    lines += [CUT] * cut
    if failed:
        lines.append(line(failed, 90, "failed"))
    if other:
        lines.append(line(other, 91))
    lines.append("Executed %d tests, with 0 failures (0 unexpected) in 9.9 (10.0) seconds\n" % (isolation + interaction))
    return "".join(lines)


def summary(passed, failed=0):
    return {"result": "Passed" if failed == 0 else "Failed", "passedTests": passed, "failedTests": failed,
            "skippedTests": 0, "totalTestCount": passed + failed}


def tests(counts, identifiers=True):
    """`get test-results tests` with `counts` {class: passed} under a test plan and the unit test bundle."""
    suites = []
    for cls, passed in counts.items():
        cases = []
        for n in range(passed):
            case = {"name": "test%02d()" % n, "nodeType": "Test Case", "result": "Passed", "duration": "0,1s"}
            if identifiers:
                case["nodeIdentifier"] = "%s/test%02d()" % (cls, n)
            cases.append(case)
        suites.append({"name": cls, "nodeType": "Test Suite", "result": "Passed", "children": cases})
    return {"devices": [{"deviceName": "iPad Pro 13-inch (M5)", "platform": "iOS Simulator"}],
            "testNodes": [{"name": "TegakiCalendar", "nodeType": "Test Plan", "result": "Passed",
                           "children": [{"name": "TegakiCalendarTests", "nodeType": "Unit test bundle", "result": "Passed",
                                         "children": suites}]}],
            "testPlanConfigurations": [{"configurationId": "1", "configurationName": "Test Scheme Action"}]}


# Each case: (name, expected "PASSED" or "FAILED", a part of an ::error:: line it must print (or None), a part of
# its output it must print (or None), the log, the summary (None: no file), the per-test results (None: no file),
# xcodebuild's status).
CASES = [
    ("every test passed, the log whole", "PASSED", None, "span-shots tests: 24 passed",
     log(4, 20), summary(24), tests({ISOLATION: 4, INTERACTION: 20}), 0),
    ("one interaction line cut by the app's log, taken from the bundle", "PASSED", None, "missing from the log SpanPrototypeInteractionTests 1",
     log(4, 20, cut=1), summary(24), tests({ISOLATION: 4, INTERACTION: 20}), 0),
    ("the cut line's class at its minimum (19, one cut)", "PASSED", None, "taken from the bundle",
     log(4, 19, cut=1), summary(23), tests({ISOLATION: 4, INTERACTION: 19}), 0),
    ("S5C2-SAFE-1: isolation one short while interaction lost a line", "FAILED", "PrototypeIsolationTests: 3 passed (the result bundle), fewer than 4", None,
     log(3, 24, cut=1), summary(27), tests({ISOLATION: 3, INTERACTION: 24}), 0),
    ("isolation one short, the log whole", "FAILED", "PrototypeIsolationTests: 3 passed (the log), fewer than 4", None,
     log(3, 24), summary(27), tests({ISOLATION: 3, INTERACTION: 24}), 0),
    ("interaction under its minimum, its line cut too", "FAILED", "SpanPrototypeInteractionTests: 18 passed (the result bundle), fewer than 19", None,
     log(4, 18, cut=1), summary(22), tests({ISOLATION: 4, INTERACTION: 18}), 0),
    ("a cut line without the bundle's classes", "FAILED", "the result bundle has 24 passed tests, the log 23 (the bundle gave no count by class", None,
     log(4, 20, cut=1), summary(24), None, 0),
    ("the bundle's classes not adding up to its summary", "FAILED", "the result bundle has 24 passed tests, the log 23", "are not counted",
     log(4, 20, cut=1), summary(24), tests({ISOLATION: 4, INTERACTION: 21}), 0),
    ("the bundle's classes from the suites (no nodeIdentifier)", "FAILED", "PrototypeIsolationTests: 3 passed (the result bundle), fewer than 4", None,
     log(3, 24, cut=1), summary(27), tests({ISOLATION: 3, INTERACTION: 24}, identifiers=False), 0),
    ("a failed test in the log", "FAILED", "SpanPrototypeInteractionTests: 1 failed", None,
     log(4, 20, failed=INTERACTION), summary(24, failed=1), tests({ISOLATION: 4, INTERACTION: 20}), 1),
    ("a failed test in the bundle only", "FAILED", "the result bundle has 1 failed tests", None,
     log(4, 20), summary(24, failed=1), tests({ISOLATION: 4, INTERACTION: 20}), 0),
    ("xcodebuild ended with 65", "FAILED", "xcodebuild test-without-building ended with 65", None,
     log(4, 20), summary(24), tests({ISOLATION: 4, INTERACTION: 20}), 65),
    ("the bundle has fewer passed tests than the log", "FAILED", "the result bundle has 23 passed tests, the log 24", None,
     log(4, 20), summary(23), tests({ISOLATION: 4, INTERACTION: 19}), 0),
    ("another class ran", "FAILED", "other classes ran: SpanSessionTests", None,
     log(4, 20, other="SpanSessionTests"), summary(25), tests({ISOLATION: 4, INTERACTION: 20, "SpanSessionTests": 1}), 0),
    ("no summary: the log alone, whole", "PASSED", None, "the log alone counts",
     log(4, 20), None, None, 0),
    ("no summary: the log alone, a line cut", "FAILED", "SpanPrototypeInteractionTests: 18 passed (the log), fewer than 19", None,
     log(4, 19, cut=1), None, None, 0),
]


def write_json(path, data):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--count", default=os.path.join(HERE, "prototype_test_count.py"))
    args = parser.parse_args()
    folder = tempfile.mkdtemp(prefix="prototype-test-count-test-")
    failures = 0
    try:
        for index, (name, expected, reason, said, text, made_summary, made_tests, status) in enumerate(CASES):
            case = os.path.join(folder, "case%02d" % index)
            os.makedirs(case)
            log_path = os.path.join(case, "prototype-tests.log")
            summary_path = os.path.join(case, "prototype-tests-summary.json")
            tests_path = os.path.join(case, "prototype-tests-tests.json")
            with open(log_path, "w", encoding="utf-8") as handle:
                handle.write(text)
            if made_summary is not None:
                write_json(summary_path, made_summary)
            if made_tests is not None:
                write_json(tests_path, made_tests)
            environment = dict(os.environ, XCODEBUILD_STATUS=str(status))
            result = subprocess.run([sys.executable, "-I", args.count, log_path, summary_path, tests_path],
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=environment)
            output = result.stdout.decode("utf-8", "replace")
            got = {0: "PASSED", 1: "FAILED"}.get(result.returncode, "error %d" % result.returncode)
            errors = [row.strip()[len("::error::"):] for row in output.split("\n") if row.strip().startswith("::error::")]
            good = (got == expected and (reason is None or any(reason in row for row in errors))
                    and (said is None or said in output) and (expected == "FAILED" or not errors))
            if not good:
                failures += 1
            print("%s %s: expected %s, got %s%s" % ("ok  " if good else "BAD ", name, expected, got,
                                                  (" — " + errors[0]) if errors else ""))
            if not good:
                for row in output.strip().split("\n") + result.stderr.decode("utf-8", "replace").strip().split("\n"):
                    if row:
                        print("     " + row)
    finally:
        shutil.rmtree(folder, ignore_errors=True)
    print("prototype test count test: %d case(s), %s" % (len(CASES), "all as expected" if failures == 0
                                                          else "%d not as expected" % failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
