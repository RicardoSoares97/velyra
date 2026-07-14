# Velyra Design System

## Direction

Velyra should feel cinematic, minimal and premium without imitating another streaming service. Content artwork is visually dominant; interface chrome remains restrained.

The app supports both system-controlled light and dark appearances. Dark is expected to be the most common TV experience, while light remains a complete first-class theme.

## Brand colour

| Token | Value | Purpose |
|---|---:|---|
| Primary | `#DD571C` | Main actions, active navigation and brand identity |
| Primary hover | `#F06A2D` | Optional hover/highlight state |
| Primary pressed | `#B74413` | Pressed state |
| Focus ring | `#FF8A55` | High-visibility tvOS focus outline |
| On primary | `#111114` | Text and icons displayed on orange |

Black/dark text is deliberately used on `#DD571C`. It has stronger normal-text contrast than white.

## Light theme

| Token | Value |
|---|---:|
| Background | `#F7F7F8` |
| Surface | `#FFFFFF` |
| Elevated surface | `#EFEFF2` |
| Primary text | `#111114` |
| Secondary text | `#62626A` |
| Border | `#DDDDE2` |
| Primary container | `#FFE3D6` |

## Dark theme

| Token | Value |
|---|---:|
| Background | `#09090B` |
| Surface | `#151518` |
| Elevated surface | `#202024` |
| Primary text | `#F7F7F8` |
| Secondary text | `#A7A7AF` |
| Border | `#34343A` |
| Primary container | `#3A190D` |

## Focus behaviour

- Every interactive element must have an obvious focused state.
- Cards scale between 1.05 and 1.08.
- Use the orange focus ring instead of relying only on scale.
- Motion should complete in approximately 160 ms.
- Focus must not be communicated through colour alone.
- Avoid very large scale changes that cause neighbouring rows to jump.

## Typography

Use the system font so text remains familiar, accessible and optimised for tvOS.

- Brand wordmark: rounded, black weight, increased tracking.
- Screen heading: large title or title.
- Section title: title 2, bold.
- Card title: headline.
- Supporting information: subheadline.

## Corners and spacing

- Small control radius: 14 pt.
- Card radius: 22 pt.
- Horizontal screen padding: 72 pt.
- Card gaps: 24–28 pt.
- Minimum interactive control height: 54 pt.
