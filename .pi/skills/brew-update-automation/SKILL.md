---
name: brew-update-automation
description: Set up automated jobs to detect Homebrew updates, create pull requests, and approve them
---

# Brew Update Automation Skill

This skill provides GitHub Actions workflows to automatically detect Homebrew formula updates, create pull requests for those updates, and automatically approve and merge them. It is designed for Homebrew taps that distribute shell frameworks and service wrappers, following the conventions in this repository's `AGENTS.md`.

## Workflows Included

### 1. Autobump Workflow (`.github/workflows/autobump.yml`)

The primary workflow that detects upstream updates and creates pull requests. It has two parallel jobs: one for tagged formulae and one for commit-pinned formulae.

**Trigger configuration:**
```yaml
on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - .github/workflows/autobump.yml
  schedule:
    # Every day at 14:10 UTC
    - cron: 10 14 * * *
```

**Tagged formulae bumping** — uses `brew bump` with livecheck to discover new tags:
```yaml
- name: Bump tagged formulae
  env:
    HOMEBREW_GITHUB_API_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    HOMEBREW_GIT_COMMITTER_NAME: ${{ steps.git_setup.outputs.name }}
    HOMEBREW_GIT_COMMITTER_EMAIL: ${{ steps.git_setup.outputs.email }}
    TAP_NAME: ${{ steps.set-up-homebrew.outputs.tap-name }}
  run: |
    brew bump --no-fork --open-pr --formulae --bump-synced \
      "$TAP_NAME/aoe-dashboard" \
      "$TAP_NAME/ccr-service" \
      "$TAP_NAME/hermes-dashboard" \
      "$TAP_NAME/oh-my-fish"
```

**Commit-pinned formulae matrix** — updates formulae pinned to a specific commit SHA:
```yaml
strategy:
  fail-fast: false
  max-parallel: 1
  matrix:
    include:
      - formula: oh-my-zsh
        repository: ohmyzsh/ohmyzsh
        branch: master
      - formula: oh-my-bash
        repository: ohmybash/oh-my-bash
        branch: master
```

**Commit-pinned update logic** — extracts the current commit, fetches the latest from upstream, and creates a PR:
```yaml
run: |
  formula_file="Formula/$FORMULA.rb"
  current_commit="$(sed -nE \
    's|.*archive/([0-9a-f]{40})\.tar\.gz.*|\1|p' "$formula_file")"

  IFS=$'\t' read -r latest_commit commit_date < <(
    gh api "repos/$UPSTREAM_REPOSITORY/commits/$UPSTREAM_BRANCH" \
      --jq '[.sha, .commit.committer.date] | @tsv'
  )

  version="$(date --utc --date="$commit_date" +%Y.%m.%d.%H%M%S)"
  branch="bump-$FORMULA-$version"

  brew bump-formula-pr "$TAP_NAME/$FORMULA" \
    --write-only \
    --url="$archive_url" \
    --version="$version"

  git switch --Create "$branch"
  git add "$formula_file"
  git commit --message="Update $FORMULA to commit ${latest_commit:0:8} ($commit_day)"
  gh pr create \
    --repo "$GITHUB_REPOSITORY" \
    --base main \
    --head "$branch" \
    --title="$FORMULA $version" \
    --body="Created by the commit-pinned autobump workflow."
```

### 2. Auto Merge Workflow (`.github/workflows/auto-merge.yml`)

Automatically merges eligible pull requests using `pascalgn/automerge-action`:
```yaml
name: Auto Merge PRs

on:
  schedule:
    - cron: "*/10 * * * *"
  workflow_dispatch:

jobs:
  automerge:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - name: Merge eligible pull requests
        uses: pascalgn/automerge-action@7961b8b5eec56cc088c140b56d864285eabd3f67 # v0.16.4
        env:
          GITHUB_TOKEN: ${{ secrets.BREW_PAT }}
          MERGE_LABELS: ""
          MERGE_METHOD: "squash"
          MERGE_READY_STATE: "clean"
```

### 3. Auto Approve Workflow Runs (`.github/workflows/auto-approve-workflow-runs.yml`)

Automatically approves workflow runs that require manual approval (e.g., for pull requests from forks or first-time contributors):
```yaml
name: Auto Approve Workflow Runs

on:
  workflow_dispatch:
  schedule:
    # Check for workflow runs awaiting approval every 10 minutes.
    - cron: "*/10 * * * *"

permissions: {}

jobs:
  approve:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Approve pending test workflow runs
        uses: mheap/automatic-approve-action@851272ecb1e93d215b9ab3c16278d434a4fd775b # v1
        with:
          token: ${{ secrets.BREW_PAT }}
          workflows: "tests.yml,autobump.yml"
```

### 4. Test Bot Workflow (`.github/workflows/tests.yml`)

Runs `brew test-bot` on pull requests and pushes to validate formulae:
```yaml
name: brew test-bot

on:
  push:
    branches:
      - main
  pull_request:

jobs:
  test-bot:
    strategy:
      matrix:
        os: [ macos-26 ]
        include:
          - os: ubuntu-latest
            container:
              image: ghcr.io/homebrew/brew:main
              options: --privileged
    runs-on: ${{ matrix.os }}
    container: ${{ fromJSON(toJSON(matrix.container)) }}
    permissions:
      actions: read
      checks: read
      contents: read
      pull-requests: read
    steps:
      - name: Set up Homebrew
        id: set-up-homebrew
        uses: Homebrew/actions/setup-homebrew@eb02c69dbabdb66ff183c614f4ce7ab3c077592c # 2026.10.12.1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - run: brew test-bot --only-tap-syntax
      - run: brew test-bot --only-formulae
        if: github.event_name == 'pull_request'

      - name: Upload bottles as artifact
        if: always() && github.event_name == 'pull_request'
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: bottles_${{ matrix.os }}
          path: '*.bottle.*'
```

### 5. Dependabot Configuration (`.github/dependabot.yml`)

Keeps GitHub Actions up to date with weekly updates:
```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
    groups:
      github-actions:
        patterns:
          - "*"
```

## Setup Instructions

### Required Secrets

To use these workflows, you need to set up the following secrets in your repository:

1. `GITHUB_TOKEN` — Automatically provided by GitHub Actions. Used for Homebrew API access and basic authentication in CI workflows.
2. `BREW_PAT` — A personal access token (classic or fine-grained) with the following scopes:
   - `repo` scope (for pushing branches and creating PRs)
   - `workflow` scope (for approving workflow runs)
   - `write:packages` (if uploading bottles, though not currently used in this tap)

### Installation

1. Copy the workflow files from `.github/workflows/` to your repository's `.github/workflows/` directory.
2. Copy the dependabot configuration from `.github/dependabot.yml` to your repository's `.github/` directory.
3. Set up the required secrets as described above.
4. Ensure your repository contains Homebrew formulae in a `Formula/` directory.
5. If using this on a new tap, run `brew trust` to establish trust for the tap.

### Customization

- **`autobump.yml`**: Modify the "Bump tagged formulae" step to list your specific formulae. Update the matrix in `commit-pinned-autobump` for your commit-pinned formulae (oh-my-zsh, oh-my-bash pattern).
- **`tests.yml`**: Adjust the matrix `os` list if you need different macOS or Ubuntu versions.
- **`auto-approve-workflow-runs.yml`**: Modify the `workflows` parameter to list the workflow names you need auto-approved.
- **`auto-merge.yml`**: Adjust `MERGE_LABELS`, `MERGE_METHOD`, and `MERGE_READY_STATE` as needed.
- **`dependabot.yml`**: Adjust the `interval` (e.g., `daily`, `weekly`, `monthly`) as needed.

### Key Environment Variables

The workflows use these environment variables:

| Variable | Source | Purpose |
|---|---|---|
| `HOMEBREW_GITHUB_API_TOKEN` | `${{ secrets.GITHUB_TOKEN }}` | Homebrew API authentication for `brew bump` and `brew test-bot` |
| `HOMEBREW_GIT_COMMITTER_NAME/EMAIL` | `${{ steps.git_setup.outputs.* }}` | Git identity for commits created by `brew bump-formula-pr` |
| `TAP_NAME` | `${{ steps.set-up-homebrew.outputs.tap-name }}` | The tap name (e.g., `coetzeer/homebrew-octavo`) |
| `UPSTREAM_REPOSITORY` | matrix value | The upstream GitHub repository (e.g., `ohmyzsh/ohmyzsh`) |
| `UPSTREAM_BRANCH` | matrix value | The upstream default branch to check (e.g., `master`) |
| `GITHUB_TOKEN` | `${{ secrets.GITHUB_TOKEN }}` | For `gh` CLI operations (PR creation, API calls) |
| `BREW_PAT` | `${{ secrets.BREW_PAT }}` | For `pascalgn/automerge-action` and `mheap/automatic-approve-action` |

## How It Works

1. **Detection**: The `autobump.yml` workflow runs daily at 14:10 UTC. It runs `brew bump` for tagged formulae (oh-my-fish, hermes-dashboard, ccr-service) and manually checks commits for pinned formulae (oh-my-zsh, oh-my-bash).
2. **PR Creation**: When updates are found, the autobump workflow creates branches named `bump-<formula>-<version>` and creates pull requests against `main`.
3. **Approval**: The `auto-approve-workflow-runs.yml` workflow runs every 10 minutes and auto-approves `tests.yml` and `autobump.yml` workflow runs that are awaiting manual approval.
4. **Testing**: The `tests.yml` workflow runs on every push and PR, running `brew test-bot` to validate tap syntax and formula installation on both macOS and Ubuntu.
5. **Merging**: Once tests pass and all required checks are green, the `auto-merge.yml` workflow squash merges the PR using `BREW_PAT`.
6. **Maintenance**: Dependabot updates the GitHub Actions themselves on a weekly basis.

## Formula Grouping

| Formula | Upstream | Versioning Strategy | Workflow Handling |
|---|---|---|---|
| `oh-my-zsh` | [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh) | Commit date (`YYYY-MM-DD`) | Commit-pinned autobump |
| `oh-my-bash` | [ohmybash/oh-my-bash](https://github.com/ohmybash/oh-my-bash) | Commit date (`YYYY-MM-DD`) | Commit-pinned autobump |
| `oh-my-fish` | [oh-my-fish/oh-my-fish](https://github.com/oh-my-fish/oh-my-fish) | Tagged releases (v8+) | `brew bump --bump-synced` |
| `hermes-dashboard` | [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) | Tagged releases (v2026.8.31+) | `brew bump --bump-synced` |
| `ccr-service` | [musistudio/claude-code-router](https://github.com/musistudio/claude-code-router) | Tagged releases (v3.1.3+) | `brew bump --bump-synced` |

## Benefits

- **Fully automated update process** — no manual intervention needed for routine bumps
- **Reduced maintenance burden** — upstream releases are reflected in the tap within 24 hours
- **Consistent versioning** — commit date for untagged formulae, upstream tags for tagged projects
- **Automatic testing of updates** — every PR is validated by `brew test-bot` on macOS and Ubuntu
- **Rapid deployment of upstream changes** — auto-merge applies approved PRs immediately

## Gotchas

- **Orphan cleanup**: The autobump workflow includes a step to remove orphaned bump branches from failed PR creation attempts, preventing branch accumulation.
- **`--bump-synced` flag**: Used for tagged formulae to ensure the new commit is from the upstream default branch, not an arbitrary fork commit.
- **Empty formula check**: Homebrew's empty-installation check ignores `INSTALL_RECEIPT.json`, so wrapper formulae (like `ccr-service`) need a real file in the keg to pass `brew test-bot`.
- **Commit message format**: Untagged formula updates use `"Update <formula> to commit <abbreviated commit> (<date>)"` — e.g., `"Update oh-my-zsh to commit 8a5b3930 (2026-09-06)"`.

## References

- [Homebrew Actions setup-homebrew](https://github.com/Homebrew/actions) — sets up Homebrew in CI
- [Homebrew `brew bump` documentation](https://docs.brew.sh/brew-bump) — the command used for tagged formulae
- [Homebrew `brew bump-formula-pr`](https://docs.brew.sh/brew-bump-formula-pr) — used for commit-pinned formulae
- [Homebrew `brew test-bot`](https://docs.brew.sh/brew-test-bot) — runs in the test workflow
- [pascalgn/automerge-action](https://github.com/pascalgn/automerge-action) — auto-merges PRs
- [mheap/automatic-approve-action](https://github.com/mheap/automatic-approve-action) — auto-approves workflow runs