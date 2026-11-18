#!/usr/bin/env python3
"""Source-contract checks runnable on iPhone; no UIKit execution or workflow dispatch."""
from pathlib import Path
import plistlib
import re
import unittest

REPO = Path(__file__).resolve().parents[2]
APP = REPO / 'Application/Dopamine'
KEYS = ['origami', 'glaze', 'nocturne', 'dusty-rose']


def source(relative):
    text = (APP / relative).read_text()
    return re.sub(r'//[^\n]*|/\*.*?\*/', '', text, flags=re.S)


class ThemeSourceContracts(unittest.TestCase):
    def setUp(self):
        self.themes = plistlib.loads((APP / 'UI/Themes/Themes.plist').read_bytes())

    def test_four_theme_resources(self):
        self.assertEqual([theme['key'] for theme in self.themes], KEYS)
        self.assertEqual([theme['darkTheme'] for theme in self.themes], [False, False, True, False])
        for theme in self.themes:
            self.assertFalse({'liquidGlass', 'usesTheseus', 'glassBlurRadius'} & theme.keys())
            self.assertEqual(len(list((APP / 'Assets.xcassets').rglob(theme['image'] + '.imageset'))), 1)

    def test_old_key_is_unknown_and_uses_existing_migration_guard(self):
        # Static source contract only: this does not execute Objective-C preferences.
        self.assertNotIn('liquid-glass', [theme['key'] for theme in self.themes])
        manager = source('UI/Themes/DOThemeManager.m')
        compact = re.sub(r'\s+', '', manager)
        self.assertIn('NSString*savedTheme=[preferencespreferenceValueForKey:@"theme"];', compact)
        self.assertIn('NSArray*validKeys=[selfgetAvailableThemeKeys];', compact)
        self.assertIn('if(![savedThemeisKindOfClass:NSString.class]||![validKeyscontainsObject:savedTheme]){[preferencessetPreferenceValue:@"glaze"forKey:@"theme"];}', compact)
        self.assertIn('for(DOTheme*themeinself.themes)[keysaddObject:theme.key];', compact)
        self.assertRegex(compact, r'if\(\[theme\.keyisEqualToString:key\]\)(?:\{returntheme;\}|returntheme;)')
        self.assertIn('DOTheme*theme=[selfgetThemeForKey:value];', compact)
        self.assertIn('returntheme?:[selfgetThemeForKey:@"glaze"]?:self.themes.firstObject;', compact)
        self.assertNotIn('liquidGlassUIInitialized', manager)

    def test_removed_renderer_and_interfaces(self):
        self.assertFalse((APP / 'Theseus').exists())
        project = (REPO / 'Application/Dopamine.xcodeproj/project.pbxproj').read_text()
        for marker in ('Theseus', 'default.metallib', 'TheseusShaders', 'DopamineTheseus'):
            self.assertNotIn(marker, project)
        for path in (APP / 'UI').rglob('*'):
            if path.suffix not in {'.h', '.m', '.plist'}:
                continue
            text = path.read_text()
            for marker in ('usesTheseus', 'DOTheseus', 'UIGlassEffect', 'isLiquidGlassStyle', 'applyLiquidGlassToView:'):
                self.assertNotIn(marker, text, str(path.relative_to(REPO)))
        self.assertIn('applyThemeSurfaceToView:', source('UI/DOGlobalAppearance.h'))
        self.assertRegex(source('UI/DOGlobalAppearance.m'), r'\+\s*\(BOOL\)isRoseStyle\s*\{\s*return YES;\s*\}')

    def test_test_runner_has_no_swift_or_shader_build(self):
        for name in ('prepare.py', 'run.sh', 'Harness.m'):
            text = (REPO / '.github/ui-tests' / name).read_text()
            for marker in ('Theseus', 'swiftc', 'metallib', 'production_swift', 'production_metal'):
                self.assertNotIn(marker, text, name)
        workflow = (REPO / '.github/workflows/rose-roothide.yml').read_text()
        self.assertIn('python3 .github/scripts/verify_themes.py', workflow)
        self.assertNotIn('verify_liquid_glass.py', workflow)
        self.assertNotIn('downloadComponent MetalToolchain', workflow)


if __name__ == '__main__':
    unittest.main(verbosity=2)
