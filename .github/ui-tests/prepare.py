#!/usr/bin/env python3
"""Stage byte-identical production Objective-C and simulator-only dependency headers."""
import argparse
import hashlib
import json
import plistlib
import re
import shutil
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(repo, output):
    ui = repo / "Application/Dopamine/UI"
    src, app = output / "src", output / "DopamineLayoutHarness.app"
    src.mkdir(parents=True, exist_ok=True)
    app.mkdir(parents=True, exist_ok=True)
    sources = [
        ui / "DOGlobalAppearance.m",
        ui / "Themes/DOTheme.m",
        ui / "DONavigationController.m",
        ui / "Transition/DOModalTransitionScale.m",
        ui / "Transition/DOModalTransitionPush.m",
        ui / "Transition/DOModalBackAction.m",
        repo / "Application/Dopamine/Extensions/UIImage+Blur.m",
    ]
    headers = [
        ui / "DOGlobalAppearance.h", ui / "Themes/DOTheme.h",
        ui / "Transition/DOModalTransitionScale.h",
        ui / "Transition/DOModalTransitionPush.h", ui / "Transition/DOModalBackAction.h",
        repo / "Application/Dopamine/Extensions/UIImage+Blur.h",
    ]
    manifest = {"production_sources": [], "production_headers": [], "resources": []}
    for paths, section in [(sources, "production_sources"), (headers, "production_headers")]:
        for path in paths:
            target = src / path.name
            shutil.copyfile(path, target)
            assert digest(target) == digest(path), f"Source copy differs: {path}"
            manifest[section].append({"path": str(path.relative_to(repo)), "sha256": digest(path)})
    bridge_header = repo / "Application/Dopamine/Theseus/DOTheseusBridge.h"
    (output / "Theseus").mkdir(exist_ok=True)
    shutil.copyfile(bridge_header, output / "Theseus/DOTheseusBridge.h")
    (src / "Theseus").mkdir(exist_ok=True)
    shutil.copyfile(bridge_header, src / "Theseus/DOTheseusBridge.h")
    manifest["production_headers"].append({"path": str(bridge_header.relative_to(repo)), "sha256": digest(bridge_header)})
    swift_paths = sorted((repo / "Application/Dopamine/Theseus").rglob("*.swift"))
    swift_paths = [p for p in swift_paths if p.name != "Package.swift"]
    manifest["production_swift"] = []
    for path in swift_paths:
        shutil.copyfile(path, src / path.name)
        manifest["production_swift"].append({"path": str(path.relative_to(repo)), "sha256": digest(path)})
    assert len(swift_paths) == 35, len(swift_paths)
    shader = repo / "Application/Dopamine/Theseus/Sources/Theseus/Shaders/TheseusShaders.metal"
    shutil.copyfile(shader, src / shader.name)
    manifest["production_metal"] = [{"path": str(shader.relative_to(repo)), "sha256": digest(shader)}]
    # Quoted includes must resolve in the temporary flat directory, never beside business .m files.
    shims = {
        "DOMainViewController.h": '#import <UIKit/UIKit.h>\n#import "DOSettingsController.h"\n#import "DOCreditsViewController.h"\n@interface DOMainViewController : UIViewController\n@end\n',
        "DOSettingsController.h": '#import <UIKit/UIKit.h>\n@interface DOSettingsController : UIViewController\n@end\n',
        "DOCreditsViewController.h": '#import <UIKit/UIKit.h>\n@interface DOCreditsViewController : UIViewController\n@end\n',
        "DOUIManager.h": '#import <UIKit/UIKit.h>\nFOUNDATION_EXPORT NSString *DOLocalizedString(NSString *key);\n',
        "DOThemeManager.h": '#import "DOTheme.h"\n@interface DOThemeManager : NSObject\n@property(nonatomic, strong) NSArray<DOTheme *> *themes;\n@property(nonatomic) NSInteger selectedIndex;\n+ (instancetype)sharedInstance;\n- (DOTheme *)enabledTheme;\n@end\n',
        "DONavigationController.h": '#import <UIKit/UIKit.h>\n#import "DOMainViewController.h"\n#import "DOGlobalAppearance.h"\n#import "DOModalTransitionScale.h"\n#import "DOModalTransitionPush.h"\n@interface DONavigationController : UINavigationController <UINavigationControllerDelegate>\n- (void)selectTopLevelTab:(NSInteger)index;\n- (void)setNavigationEnabled:(BOOL)enabled;\n@end\n',
    }
    for name, contents in shims.items():
        (src / name).write_text(contents)
    appearance_header = (ui / "DOGlobalAppearance.h").read_text()
    navigation_header = (ui / "DONavigationController.h").read_text()
    for selector in ["brandCardView", "contentViewForController:"]:
        if selector not in appearance_header:
            raise ValueError(f"Production DOGlobalAppearance.h must expose +{selector}")
    for selector in ["selectTopLevelTab:", "setNavigationEnabled:"]:
        if selector not in navigation_header:
            raise ValueError(f"Production DONavigationController.h must expose -{selector}")
    main = (ui / "DOMainViewController.m").read_text()
    if not re.search(r"\[\s*DOGlobalAppearance\s+brandCardView\s*\]", main):
        raise ValueError("Production home must use the shared [DOGlobalAppearance brandCardView]")
    manifest["routing_dependency_shims"] = sorted(shims)
    manifest["home_uses_production_brand_factory"] = True
    manifest["production_home_sha256"] = digest(ui / "DOMainViewController.m")
    # Every include in these copied translation units must be satisfiable from SDK or staging.
    for path in sources:
        for include in re.findall(r'^\s*#(?:import|include)\s+"([^"]+)"', path.read_text(), re.M):
            if not (src / include).is_file() and not (src / "UI" / include).resolve().is_file():
                raise ValueError(f"Unstaged quoted include in {path.name}: {include}")
    themes_path = ui / "Themes/Themes.plist"
    themes = plistlib.loads(themes_path.read_bytes())
    if not isinstance(themes, list) or [t.get("key") for t in themes] != ["origami", "glaze", "nocturne", "dusty-rose", "liquid-glass"]:
        raise ValueError("Expected the five approved production themes in Themes.plist")
    shutil.copyfile(themes_path, app / "Themes.plist")
    manifest["resources"].append({"path": str(themes_path.relative_to(repo)), "sha256": digest(themes_path)})
    assets = repo / "Application/Dopamine/Assets.xcassets"
    # UIImage imageNamed: can resolve loose PNG/JPEG resources. No fake generated backgrounds.
    for name in sorted({Path(t["image"]).stem for t in themes} | {"Background_Glaze"}):
        if not re.fullmatch(r"[A-Za-z0-9_-]+", name):
            raise ValueError(f"Unsafe asset name: {name}")
        folders = list(assets.rglob(f"{name}.imageset"))
        if len(folders) != 1:
            raise ValueError(f"Expected exactly one asset catalog entry for {name}: {folders}")
        folder = folders[0]
        content = json.loads((folder / "Contents.json").read_text())
        candidates = [item for item in content["images"] if item.get("filename")]
        candidates.sort(key=lambda item: (item.get("scale") != "1x", item.get("idiom") != "universal"))
        if not candidates:
            raise ValueError(f"No raster file for {name}")
        item = candidates[0]
        original = folder / item["filename"]
        if original.suffix.lower() not in {".png", ".jpg", ".jpeg"}:
            raise ValueError(f"Expected raster resource for {name}: {original}")
        target = app / (name + original.suffix.lower())
        shutil.copyfile(original, target)
        manifest["resources"].append({"path": str(original.relative_to(repo)), "sha256": digest(original),
                                      "bundle_name": target.name, "source_scale": item.get("scale", "unspecified")})
    harness = Path(__file__).resolve().parent / "Harness.m"
    shutil.copyfile(harness, src / "Harness.m")
    manifest["harness_sha256"] = digest(harness)
    info = {"CFBundleIdentifier": "dev.dopamine.layout-harness", "CFBundleExecutable": "DopamineLayoutHarness",
            "CFBundleName": "DopamineLayoutHarness", "CFBundlePackageType": "APPL",
            "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0", "MinimumOSVersion": "15.0",
            "LSRequiresIPhoneOS": True, "UIDeviceFamily": [1], "UILaunchScreen": {},
            "UIRequiredDeviceCapabilities": [], "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
            "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False,
                "UISceneConfigurations": {"UIWindowSceneSessionRoleApplication": [
                    {"UISceneConfigurationName": "Harness", "UISceneDelegateClassName": "DOHarnessSceneDelegate"}]}}}
    (app / "Info.plist").write_bytes(plistlib.dumps(info))
    (app / "source-manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    (output / "source-manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"Staged {len(sources)} byte-identical production .m files and {len(themes)} production themes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    prepare(args.repo.resolve(), args.output.resolve())
