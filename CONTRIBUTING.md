# Contributing

## Branches

Use short feature branches:

```text
feature/addon-manifest
feature/trakt-device-auth
feature/player-diagnostics
```

## Commits

Prefer Conventional Commits:

```text
feat: add addon manifest client
fix: restore focus after closing details
chore: update tvOS build workflow
```

## Rules

- Do not commit secrets, Trakt credentials, certificates or provisioning profiles.
- Keep domain logic independent from SwiftUI where practical.
- Add a focused state to every interactive tvOS control.
- Do not add third-party source code without reviewing its licence.
- Use AVPlayer as the primary engine unless a documented compatibility case requires another route.
