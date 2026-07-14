# Legal and Distribution Boundaries

Velyra is intended to be a client application. It must not host, index, bundle or distribute unauthorised media.

## Clean-room rule

The initial repository is independent. Public protocols and documented APIs may be implemented, but source code from GPL projects must not be copied unless Velyra intentionally adopts the corresponding GPL obligations.

Changing GPL source code from Kotlin to Swift does not automatically remove those obligations.

## Addon rule

Prefer remote declarative HTTP/JSON addons. Avoid downloading and executing arbitrary JavaScript or other executable plugin code, particularly for App Store distribution.

## User communication

The application should state that:

- users must have permission to access their configured sources;
- Velyra does not provide media;
- third-party services are independent;
- compatibility is not guaranteed for every stream or format.

A qualified legal review is required before public distribution.
