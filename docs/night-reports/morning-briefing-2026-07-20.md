# Morning Briefing — 2026-07-20

**Session**: `claude/night-20260719` → PR pending  
**Branch**: `claude/night-20260719`  
**Tests**: 3505 passed / 0 failed ✅  
**Analyze**: No issues ✅

---

## What was done tonight

### Task 1 — Issue #29: AppTextField Phase 3 (5 files converted)

Continued the AppTextField unification drive. Converted raw `TextField` / `TextFormField`
instances in 5 screens to the design-system `AppTextField` widget:

| File | Change |
|------|--------|
| `newsletter_compose_screen.dart` | title + body → `AppTextField` / `AppTextField.multiline` |
| `profile_screen.dart` | display-name → `AppTextField` |
| `fleet_member_screen.dart` | user-ID field in add-member dialog → `AppTextField` (key preserved) |
| `inquiry_screen.dart` | subject → `AppTextField`; message kept raw (uses custom `counterText`) |
| `settings_screen.dart` | company-name in business-account dialog → `AppTextField` |

Test safety verified: `find.byType(TextFormField)` still works because `AppTextField` renders
`TextFormField` internally. All key-based lookups are unaffected.

### Task 2 — pm_report.yml: 3 CI bugs fixed

Weekly PM reports have been failing since 2026-07-06. Three bugs were present on `main`
(PRs #75, #77, #83 each attempted a fix but all remain unmerged):

| Bug | Root cause | Fix |
|-----|-----------|-----|
| `grep -c` double-output | `$(grep -c … \|\| echo "0")` emits `"0\n0"` | `ISSUE_COUNT=$(…) \|\| ISSUE_COUNT=0` |
| `grep -oP` flag collision | Pattern `'-\K[0-9]+'` starts with `-`, treated as a flag | Changed to `grep -oE ' -[0-9]+'` + `tr -d` |
| Label 422 on issue create | Labels `pm-report`/`weekly` may not exist yet | Idempotent `createLabel` loop before `create` |

---

## Blockers remaining (human action required)

See `docs/HUMAN_TASKS.md` for the full list. Key items:

- `android/app/google-services.json` — still placeholder (`trust-car-platform` project ID); replace with real Firebase Console download before release
- `ios/Runner/GoogleService-Info.plist` — still missing; requires Mac + Firebase Console download

---

## Suggested next actions

1. **Merge tonight's PR** — unblocks Issue #29 progress and fixes weekly PM reports
2. **Issue #29 Phase 4** — ~22 remaining raw fields (chat inputs, isDense tiles); categorize and convert the safe ones
3. **Resolve stale PRs #75/#77/#83** — they fix the same pm_report.yml bugs; close them as superseded by tonight's PR
