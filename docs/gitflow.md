# GitFlow

## Permanent branches

### `main`

Represents code that is eligible for TestFlight or App Store distribution. Every merge into `main` must correspond to a tagged release or an approved hotfix.

### `develop`

Integration branch for the next version. Feature branches start here and return here through pull requests.

## Supporting branches

| Branch | Starts from | Merges into | Purpose |
|---|---|---|---|
| `feature/*` | `develop` | `develop` | Isolated product work |
| `release/*` | `develop` | `main` and `develop` | Stabilisation, metadata and versioning |
| `hotfix/*` | `main` | `main` and `develop` | Urgent production correction |

## Examples

```bash
git switch develop
git pull
git switch -c feature/trakt-device-auth

# work, test and commit

git push -u origin feature/trakt-device-auth
```

Release preparation:

```bash
git switch develop
git switch -c release/0.2.0
```

The release branch updates `MARKETING_VERSION` in `project.yml`, completes all
release checks, and returns through the normal pull-request path to `main`. After
approval, merge the same release back into `develop`. Tag the resulting release
commit on `main` only after both integrations are complete:

```bash
git tag -a v0.2.0 -m "Velyra 0.2.0"
git push origin v0.2.0
```

The tag must be exactly `vMAJOR.MINOR.PATCH`, must match `MARKETING_VERSION`, and
must point to a commit reachable from `main`. The user performs all Git operations;
GitHub Actions never creates branches, merges, or tags.

The tag workflow rebuilds independently instead of reusing a branch artifact. It
publishes an unsigned versioned IPA, its SHA-256 checksum, and a Markdown
changelog only after confirming that the draft release contains exactly those
three assets. Generated notes use the pull-request labels documented in
`CONTRIBUTING.md`.

## Protection rules

- Require pull requests for `main` and `develop`.
- Require the `tvOS Build` status check (job `build`) before integration.
- Disable force-push on permanent branches.
- Prefer squash merges for feature branches.
- Use merge commits for release and hotfix branches to preserve GitFlow history.
- Keep workflow permissions at least privilege: branch CI has `contents: read`;
  only the tag release workflow has `contents: write`.
- Protect release tags and limit who may create `v*` tags.

## Release recovery

- A validation or build failure occurs before release creation, so no GitHub
  Release is created.
- A failure during asset upload or verification leaves a draft. Rerunning the tag
  workflow resumes that draft and replaces the three expected assets.
- An existing public release is never silently overwritten: the workflow refuses
  to continue unless an existing release is still a draft.
- Correct the underlying branch through GitFlow before creating a new release tag;
  do not move or reuse a published semantic-version tag.
