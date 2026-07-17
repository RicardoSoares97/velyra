# Contributing

## GitFlow

All normal work starts from `develop`.

```text
main
└── production releases and hotfixes

develop
└── next-release integration

feature/*
release/*
hotfix/*
```

See `docs/gitflow.md` for the complete workflow.

## Commits

Use Conventional Commits:

```text
feat: add Trakt device activation
fix: restore focus after closing details
chore: update tvOS workflow
```

## Pull requests

- `feature/*` targets `develop`.
- `release/*` targets `main`, then is merged back into `develop`.
- `hotfix/*` targets `main`, then is merged back into `develop`.
- Every PR must build for the tvOS simulator.
- UI changes must document focus and accessibility behaviour.
- Every PR must complete `.github/PULL_REQUEST_TEMPLATE.md`.
- `docs/apple-platform-standards.md` is a mandatory acceptance contract.
- Every release-facing PR must have at least one release-note category label:
  `feature`, `enhancement`, `bug`, `fix`, `accessibility`, `performance`,
  `documentation`, `dependencies`, `maintenance`, or `ci`.
- Use `skip-changelog` only when a change has no user or release-operator impact.
  Unlabelled PRs remain visible under `Other changes` rather than being omitted.

## Rules

- Never commit Trakt credentials, tokens, certificates or provisioning profiles.
- Never place OAuth tokens in iCloud.
- Never commit copyrighted film/series media without explicit rights.
- Keep domain and data logic independent from SwiftUI where practical.
- Every interactive element requires a clear focused state.
- Respect Reduce Motion, Reduce Transparency and VoiceOver.
- Use AVPlayer as the primary engine unless a documented compatibility case requires another route.
- Do not add third-party source code without reviewing its licence.

## Definition of done

A feature is complete only when it meets Apple platform behaviour, accessibility, localisation, privacy, performance and testing requirements. Working code alone is not sufficient.
