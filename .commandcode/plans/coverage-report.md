# Plan: `mac-env coverage:report` command

## Goal

Add a new `mac-env coverage:report` subcommand that:
1. Always runs both coverage suites (single-site + multisite)
2. Displays PHPUnit's `--coverage-text` output for each suite
3. Shows class-level method/line coverage summaries (or 100% coverage)

Keeps the existing `coverage:check` command untouched (it remains the 100% gate).

## Files to modify

### 1. `bin/mac-env` (wp-env-opossum)

**Add `do_coverage_report()` function** — runs both coverage suites and displays the text output:

```sh
do_coverage_report() {
    echo "=== Single-site coverage ==="
    run_tests coverage || return $?
    echo ""
    echo "=== Multisite coverage ==="
    run_tests coverage-multisite || return $?
}
```

**Add case in main switch:**
```sh
coverage:report) do_coverage_report ;;
```

**Update `print_help()`:**
```
  mac-env coverage:report
                        run both coverage suites (single + multisite) and
                        display the --coverage-text output.
```

## Verification

1. Run `mac-env coverage:report` from the git-updater plugin root
2. Verify both coverage suites run (single-site then multisite)
3. Verify `--coverage-text` output is displayed for each suite
4. Verify output shows class-level method/line coverage summaries
5. Verify 100% coverage case shows "100.00%" for all classes
6. Verify existing `coverage:check` still works unchanged

## Notes

- Uses PHPUnit's built-in `--coverage-text` flag (already included in `run_tests coverage` and `run_tests coverage-multisite`)
- No custom parsing needed — the text output provides class-level summaries
- The clover XML files are still generated (for `coverage:check` and HTML reports) but not directly consumed by this command
