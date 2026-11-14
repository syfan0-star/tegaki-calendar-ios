#!/usr/bin/env python3
"""The count of the prototype's tests in span-shots (docs/M7C.md, wave C1's lead decision 7; review S5C2-SAFE-1).

    XCODEBUILD_STATUS=<n> python3 -I tools/span/prototype_test_count.py <log> <summary.json> <tests.json>

<log> is xcodebuild's output of `test-without-building` with -only-testing PrototypeIsolationTests and
SpanPrototypeInteractionTests; <summary.json> is `xcrun xcresulttool get test-results summary` of its result bundle and
<tests.json> `xcrun xcresulttool get test-results tests` (one node per test case under its class); either may be empty
or missing. XCODEBUILD_STATUS is xcodebuild's exit status (1 when it is not given).

Passes (exit 0) when xcodebuild ended with 0, no test failed (the log's "Test Case '-[…]' failed" lines and the
bundle's failedTests), no other class ran, and each class has at least its minimum of passed tests (NEED): counted
from the log, one line per test case, and also from the bundle's own count for that class when the bundle gives one.

The app's log lines are written into the same output, and one can cut a test's "passed" line (11/13, and run
43520437949's first attempt on 11/14: "Test Case '-[…SpanPrototypeIn2026-11-13 02:23:12… [RemoteRecognizer] …"), so the
log counts fewer passed tests than the bundle with every test passed. Such missing lines are taken from the bundle only
class by class: when the bundle says every test passed, nothing failed by the log, and the bundle counts each class at
least as many passed tests as the log (its per-class counts adding up to its passedTests), each class's count is the
bundle's, with a warning that names the classes the log missed. A class whose bundle count is under its minimum fails
whatever the other class lost (before, the sum of the lost lines could cover another class's real shortfall). Without
the bundle's per-class counts a log that misses lines fails, as it did before 1ea1d7e. A bundle with fewer passed tests
than the log fails. Without a summary the log alone counts (a warning).

Prints the counts and one `::error::` line per problem (GitHub's annotation). tools/span/prototype_test_count_test.py
runs it on made-up logs and bundles (build.yml runs that test on every push).
"""
import json
import os
import re
import sys

NEED = {"PrototypeIsolationTests": 4, "SpanPrototypeInteractionTests": 19}

CASE = re.compile(r"Test [Cc]ase '(?:-\[)?(?:\w+\.)?(?P<cls>\w+)[ .](?P<name>test\w*)(?:\(\))?\]?' "
                  r"(?P<result>passed|failed|skipped)")

# xcresulttool's results of a test case (`get test-results tests`), as the log's words.
BUNDLE_RESULTS = {"Passed": "passed", "Failed": "failed", "Skipped": "skipped", "Expected Failure": "passed"}


def log_results(text):
    """(class, test) → passed | failed | skipped, the last line of each test case."""
    results = {}
    for match in CASE.finditer(text):
        results[(match.group("cls"), match.group("name"))] = match.group("result")
    return results


def read_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return None


def bundle_classes(tests):
    """class → {passed, failed, skipped, other} from `get test-results tests`, or None when it has no test case.

    A test case is a node whose nodeType is "Test Case"; its class is the first part of its nodeIdentifier
    ("PrototypeIsolationTests/testX()"), or else the name of the nearest "Test Suite" above it (a module prefix
    "TegakiCalendarTests." is dropped)."""
    if not isinstance(tests, dict):
        return None
    counts = {}
    found = [0]

    def walk(node, suite):
        if isinstance(node, list):
            for item in node:
                walk(item, suite)
            return
        if not isinstance(node, dict):
            return
        kind = node.get("nodeType")
        if kind == "Test Case":
            identifier = node.get("nodeIdentifier") or ""
            cls = identifier.split("/")[0] if "/" in identifier else (suite or "")
            cls = cls.split(".")[-1]
            result = BUNDLE_RESULTS.get(node.get("result"), "other")
            counts.setdefault(cls, {"passed": 0, "failed": 0, "skipped": 0, "other": 0})[result] += 1
            found[0] += 1
            return
        if kind == "Test Suite" and node.get("name"):
            suite = str(node["name"])
        walk(node.get("children"), suite)

    walk(tests.get("testNodes"), None)
    return counts if found[0] else None


def main(argv):
    if len(argv) != 4:
        sys.stderr.write(__doc__.split("\n\n")[1] + "\n")
        return 2
    log_path, summary_path, tests_path = argv[1:]
    try:
        with open(log_path, encoding="utf-8", errors="replace") as handle:
            text = handle.read()
    except OSError as error:
        print("::error::the test log %s cannot be read: %s" % (log_path, error))
        return 1
    status = int(os.environ.get("XCODEBUILD_STATUS", "1"))
    results = log_results(text)

    def count(cls, result):
        return sum(1 for (c, _), r in results.items() if c == cls and r == result)

    problems = []
    if status != 0:
        problems.append("xcodebuild test-without-building ended with %d" % status)
    logged = {}
    for cls, least in NEED.items():
        passed, failed, skipped = count(cls, "passed"), count(cls, "failed"), count(cls, "skipped")
        logged[cls] = passed
        print("%s: %d passed, %d failed, %d skipped (at least %d must pass)" % (cls, passed, failed, skipped, least))
        if failed:
            problems.append("%s: %d failed" % (cls, failed))
    others = sorted(set(c for (c, _) in results if c not in NEED))
    if others:
        problems.append("other classes ran: %s" % ", ".join(others))
    failed_all = sum(1 for r in results.values() if r == "failed")
    passed_all = sum(1 for r in results.values() if r == "passed")

    # The passed tests of each class that the minimums are checked on: the log's and, when the bundle gives them, the
    # bundle's; only the bundle's when the log lost passed lines that the bundle has, class by class.
    from_log = dict(logged)
    from_bundle = None
    taken_from_bundle = False
    summary = read_json(summary_path)
    if isinstance(summary, dict) and "passedTests" in summary:
        print("result bundle: %s, %s passed, %s failed, %s skipped of %s" % (summary.get("result"), summary.get("passedTests"),
              summary.get("failedTests"), summary.get("skippedTests"), summary.get("totalTestCount")))
        bundle_passed = summary.get("passedTests")
        bundle_failed = summary.get("failedTests", 0)
        if bundle_failed != 0:
            problems.append("the result bundle has %s failed tests" % bundle_failed)
        classes = bundle_classes(read_json(tests_path))
        if classes is None:
            print("result bundle by class: none (xcresulttool gave no test case)")
        else:
            print("result bundle by class: " + ", ".join("%s %d passed, %d failed, %d skipped" % (
                cls, c["passed"], c["failed"], c["skipped"]) for cls, c in sorted(classes.items())))
            strange = sorted(cls for cls in classes if cls not in NEED)
            if strange:
                problems.append("the result bundle has other classes: %s" % ", ".join(strange))
            added = sum(c["passed"] for c in classes.values())
            if isinstance(bundle_passed, int) and added == bundle_passed:
                from_bundle = {cls: classes.get(cls, {}).get("passed", 0) for cls in NEED}
            else:
                print("::warning::the result bundle's classes add up to %d passed tests, its summary says %s: its classes "
                      "are not counted" % (added, bundle_passed))
        if bundle_passed != passed_all:
            lost = bundle_passed - passed_all if isinstance(bundle_passed, int) else 0
            missing = {}
            fewer = []
            if from_bundle is not None:
                missing = {cls: from_bundle[cls] - from_log[cls] for cls in NEED if from_bundle[cls] > from_log[cls]}
                fewer = [cls for cls in NEED if from_bundle[cls] < from_log[cls]]
            if (lost > 0 and from_bundle is not None and not fewer and sum(missing.values()) == lost
                    and bundle_failed == 0 and failed_all == 0 and status == 0):
                # The log lost passed lines (an app's log line cut them); the bundle has them, class by class.
                taken_from_bundle = True
                print("::warning::the result bundle has %d passed tests, the log %d: missing from the log %s, taken from "
                      "the bundle (every test passed there)" % (bundle_passed, passed_all,
                                                                ", ".join("%s %d" % (cls, n) for cls, n in sorted(missing.items()))))
            else:
                why = "" if from_bundle is not None or lost <= 0 else " (the bundle gave no count by class to tell which class lost them)"
                problems.append("the result bundle has %s passed tests, the log %d%s" % (bundle_passed, passed_all, why))
    else:
        print("::warning::xcresulttool gave no summary; the log alone counts")

    # MUTATION (r13-q-s5c2-fix-md, not to be merged): the shape of review S5C2-SAFE-1's defect, no minimum is checked
    # once lost lines were taken from the bundle.
    checks = [] if taken_from_bundle else (
        [("the log", from_log)] + ([("the result bundle", from_bundle)] if from_bundle is not None else []))
    for source, numbers in checks:
        for cls, least in NEED.items():
            if numbers[cls] < least:
                problems.append("%s: %d passed (%s), fewer than %d" % (cls, numbers[cls], source, least))
    print("span-shots tests: %d passed, %d failed in the log" % (passed_all, failed_all))
    for problem in problems:
        print("::error::" + problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
