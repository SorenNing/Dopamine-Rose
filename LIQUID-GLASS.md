# Dopamine RootHide: three-theme native UI

RootHide baseline: `3.x_roothide_AI_review_fix` (`3ac500e9d95553c2ffd651894315d79b31ee8aed`), version `3.0.13-30`, bundle `cn.zqbb.dopaRH`. Existing RootHide payloads and jailbreak implementation are retained.

Themes: 折纸 · 白昼 (`origami`), 琉光 · 青瓷 (`glaze`, default), 砂金 · 夜潮 (`nocturne`). Invalid or former theme preferences migrate to Glaze. All three use the same native UIKit layout and semantic colors. The project includes original background artwork in complete 1x/2x/3x asset sets.

The home page contains a centered brand surface, device-information card with the original issue notice, two restart cards, a fixed low jailbreak button and a three-entry glass capsule (Home, Settings, About). Settings, exploit/PAC/PPL/Jetsam/theme selection, credits/licenses, package-manager selection, logs/errors, update details and dormant download UI share the appearance system. System alerts, photo picker and share sheet use public style/tint properties.

On iOS 26 the surface factory resolves the public `UIGlassEffect` class and `effectWithStyle:` selector with availability checks. Older systems use public ultra-thin `UIBlurEffect` with theme tint, thin borders and shadows. Public blur styles do not reproduce CSS blur radius/saturation exactly. Reduce Transparency uses an opaque theme surface. No backboardd filter or private `CAFilter` is required.

Titan's two Xcode deployment targets are aligned to iOS 15, consistent with its declared iOS 16/17 support and the other bundled frameworks. Final archive validation inspects every embedded framework's actual Mach-O minimum OS; it rejects an accidental higher target rather than relying on source plist values.

UI corrections include per-instance preparation mutex initialization, real UIButton disabled state, main-thread workaround alert creation, per-controller fade state, Scene-aware windows/log sharing, public navigation frame computation, no private display-corner KVC, masked public log blur, initial incremental-log handling and download timer cleanup. Original RootHide gates/run/finalize/restart operations remain in the existing execution paths.

Build manually: Actions → **Build Dopamine Rose RootHide** → Run workflow → `main`. The workflow has no push trigger. It builds the original complete RootHide project on macOS, produces byte-identical IPA/TIPA archives and verifies bundle/version, four required libraries, RootHide marker, UI selectors, compiled three-theme metadata and Mach-O signature load commands. `verify_liquid_glass.py` emits an artifact verification receipt. These checks do not establish on-device jailbreak success or visual equivalence; device testing remains separate.
