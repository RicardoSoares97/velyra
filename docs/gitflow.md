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

After approval, merge the release into both `main` and `develop`, then tag it:

```bash
git tag -a v0.2.0 -m "Velyra 0.2.0"
```

## Protection rules

- Require pull requests for `main` and `develop`.
- Require a passing tvOS simulator build.
- Disable force-push on permanent branches.
- Prefer squash merges for feature branches.
- Use merge commits for release and hotfix branches to preserve GitFlow history.
