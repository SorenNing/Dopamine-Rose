# Dopamine RootHide: four-theme native UI

The selectable themes are 折纸 · 白昼 (`origami`), 琉光 · 青瓷 (`glaze`, default), 砂金 · 夜潮 (`nocturne`), and 灰粉 · 玫瑰 (`dusty-rose`). All four share the native UIKit layout. Origami and Dusty Rose use the user-supplied portrait JPEG backgrounds (1024×2218 and 1080×2337 respectively), while retaining their primary/secondary/accent palettes. Their shared full-screen navigation background uses centered aspect-fill cropping across Home, Settings, About, pushed selection/license/update pages and logs; push/pop backdrops reuse the same image. Translucent UIKit surfaces remain above the image for legibility. System alerts, photo picker and share sheet keep their system-managed surfaces, and the static cold-launch storyboard remains neutral. Unknown or missing saved theme keys fall back to Glaze through `DOThemeManager`.

RootHide baseline: `3.x_roothide_AI_review_fix` (`3ac500e9d95553c2ffd651894315d79b31ee8aed`), version `3.0.13-30`, bundle `cn.zqbb.dopaRH`. Existing RootHide payloads and jailbreak implementation are retained.

The static iOS launch storyboard uses a neutral fallback. Once application code starts, the window and navigation surface use the selected theme. The system-rendered cold-launch screen cannot access app preferences, so it is not guaranteed to match every selected theme before app code runs.

The home page contains a centered brand surface, device-information card with the original issue notice, two restart cards, a fixed low jailbreak button and a three-entry navigation capsule (Home, Settings, About). Settings, exploit/PAC/PPL/Jetsam/theme selection, credits/licenses, package-manager selection, logs/errors, update details and dormant download UI share the appearance system. System alerts, photo picker and share sheet use public style/tint properties.

Titan's two Xcode deployment targets are aligned to iOS 15, consistent with its declared iOS 16/17 support and the other bundled frameworks. Final archive validation inspects every embedded framework's actual Mach-O minimum OS and rejects an accidental higher target rather than relying on source plist values.

UI layout checks cover the shared single-line brand, navigation-owned full-size page roots, clipped inner page containers above the navigation capsule, full-row backgrounds including accessories, transparent internal action buttons, white switch thumbs, and navigation selection. Original RootHide gates/run/finalize/restart operations remain in the existing execution paths.

## Local and CI verification

Run `python3 .github/ui-tests/test_themes_static.py` on iPhone or any Python 3 host for standard-library-only source-contract checks: four theme resources, removed renderer/build dependencies, and the existing unknown-key migration and enabled-theme fallback to Glaze. These inspect production source; they do not execute Objective-C preferences or prove runtime migration.

The manual workflow runs `.github/ui-tests/run.sh` before device compilation. It stages byte-identical production Objective-C appearance, theme and navigation sources in a simulator harness. The matrix covers four themes at 320/390/430-point widths with 68 screenshots: six brand cases, nine page cases and two sampled push/pop transition frames per theme. Assertions check brand compression, root bounds, clipped panel bounds, row/accessory coverage, navigation switching/push/pop, selection state and transition-backdrop cleanup. The harness uses the Objective-C compiler and UIKit frameworks without a separate shader or Swift build step.

The harness saves native screenshots, assertion results and console logs. Fixture controllers replace business actions and private Preferences, so this is shared-component UIKit verification, not a full on-device test. Interactive swipe cancellation, complete business pages and physical-device rendering remain untested by this harness.

Build manually: Actions → **Build Dopamine Rose RootHide** → Run workflow → `main`. The workflow has no push trigger. It builds the original complete RootHide project on macOS, produces byte-identical IPA/TIPA archives and verifies bundle/version, required libraries and payloads, RootHide marker, UI selectors, compiled four-theme metadata, Mach-O signature load commands and minimum OS. `.github/scripts/verify_themes.py` emits an artifact verification receipt. These checks do not establish on-device jailbreak success or visual equivalence; device testing remains separate.
