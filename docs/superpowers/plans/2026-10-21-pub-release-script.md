# Official pub.dev Release Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a documented, non-interactive command that validates and publishes this package to the official pub.dev registry.

**Architecture:** Keep `scripts/publish.sh` as the single release entry point. Its existing environment isolation, connectivity check, clean-worktree guard, analysis, test, and dry-run stages remain unchanged; `--yes` will also forward Pub's force flag so automation has no second confirmation prompt. A hermetic Bash regression test replaces external binaries with fakes and asserts the exact publish invocation.

**Tech Stack:** Bash, Flutter CLI, Git, curl, `flutter test`.

## Global Constraints

- Publish only to official `https://pub.dev`; temporarily ignore mirror environment variables.
- Existing interactive release behavior remains unchanged unless `--yes` is explicitly supplied.
- `--dry-run-only` must never attempt a real publication.
- Documentation must cover both the recommended verification command and the irreversible publish command.

---

### Task 1: Prove and implement non-interactive publication

**Files:**
- Create: `test/publish_script_test.sh`
- Modify: `scripts/publish.sh`

**Interfaces:**
- Consumes: `scripts/publish.sh --skip-checks --yes --proxy http://127.0.0.1:7897`.
- Produces: exactly one fake Flutter call `pub publish --force` after a successful `pub publish --dry-run`.

- [ ] **Step 1: Write the failing regression test**

Create a shell test that makes a temporary fake `flutter`, `git`, `curl`, and `nc` executable directory, runs the release script with `--skip-checks --yes --proxy http://127.0.0.1:7897`, and checks its call log with:

```bash
grep -Fx 'pub publish --dry-run' "$CALL_LOG"
grep -Fx 'pub publish --force' "$CALL_LOG"
```

- [ ] **Step 2: Run the regression test to verify it fails**

Run: `bash test/publish_script_test.sh`

Expected: FAIL because the script currently invokes `flutter pub publish` without `--force`.

- [ ] **Step 3: Implement the minimal non-interactive publish behavior**

Change only the final publication block in `scripts/publish.sh`:

```bash
if [[ "$AUTO_CONFIRM" -eq 1 ]]; then
  run_pub_command publish --force
else
  run_pub_command publish
fi
```

- [ ] **Step 4: Re-run the regression test**

Run: `bash test/publish_script_test.sh`

Expected: PASS and confirms both dry-run and force publish calls.

- [ ] **Step 5: Commit**

```bash
git add scripts/publish.sh test/publish_script_test.sh
git commit -m "feat: support non-interactive pub publishing"
```

### Task 2: Document the release workflow

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`

**Interfaces:**
- Consumes: the `scripts/publish.sh` options from its `--help` output.
- Produces: English and Chinese “Publish to pub.dev” sections with dry-run, interactive, non-interactive, and proxy examples.

- [ ] **Step 1: Add documentation assertions to the shell test**

Extend `test/publish_script_test.sh` to assert both README files contain `scripts/publish.sh --dry-run-only` and `scripts/publish.sh --yes`.

- [ ] **Step 2: Run the documentation assertions to verify they fail**

Run: `bash test/publish_script_test.sh`

Expected: FAIL because neither README documents the release commands.

- [ ] **Step 3: Add concise English and Chinese release documentation**

Add matching `## Publish to pub.dev` / `## 发布到 pub.dev` sections explaining that the script runs cleanliness checks, `flutter analyze`, `flutter test`, and Pub dry-run; state that publication is irreversible; and include:

```bash
./scripts/publish.sh --dry-run-only
./scripts/publish.sh
./scripts/publish.sh --yes
./scripts/publish.sh --yes --proxy http://127.0.0.1:7897
```

- [ ] **Step 4: Re-run the shell test**

Run: `bash test/publish_script_test.sh`

Expected: PASS.

- [ ] **Step 5: Run full package verification**

Run: `flutter analyze && flutter test && ./scripts/publish.sh --dry-run-only`

Expected: analyzer succeeds, all non-live tests pass, and Pub reports zero publication warnings.

- [ ] **Step 6: Commit**

```bash
git add README.md README.zh-CN.md test/publish_script_test.sh
git commit -m "docs: document pub.dev release workflow"
```
