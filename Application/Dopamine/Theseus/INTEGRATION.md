# 液态玻璃

The fifth selectable theme has key `liquid-glass` and display name `液态玻璃`. The first four theme dictionaries are retained unchanged; the default remains Glaze. Theme selection uses the existing Preferences list and scene recreation.

Upstream: https://github.com/valzevul/Theseus, exact revision `71ca1c127a4e7fe3387361f160c4890dbd427f66` (1.1.0). All 33 Swift sources, the Metal shader, Package.swift, LICENSE and NOTICE are retained byte-identically. The complete upstream dependency graph is compiled into the app. `TheseusBundle.swift` adapts `Bundle.module` to the app bundle, whose `default.metallib` is generated from the original Metal source.

`DOTheseusBridge.swift` uses the original `.regular` material, `TheseusTabBar` and `TheseusSwitch`. It does not replace the shader or original drag lens, spring and lift behavior. The navigation adapter maps the three real item events to the existing Home/Settings/About stacks. The original tab geometry (63-point height and 66-point preferred slots) is used inside the existing bottom safe-area placement.

Cards, page surfaces, actions and package-manager surfaces use the shared material factory. The stable navigation root is the background source; each card excludes its foreground subtree from capture, and snapshots allow nested surfaces to be captured. One shared 30 Hz movement observer invalidates surfaces when scroll offsets change. Hidden bars are detached so the upstream lifecycle removes the ancestor drag lens. System Preferences continues owning its UISwitch and preference actions; a Theseus switch overlay mirrors state and forwards one valueChanged event. System alerts, photo picker and sharing retain their public UIKit controllers.

The native simulator harness compiles all actual Swift/Metal sources, checks five themes at 320/390/430 points and captures 85 screenshots. Theme-specific checks require the real Theseus class, three original accessible items, correct selection and no legacy static pill siblings. The complete RootHide archive is verified separately. Local Objective-C syntax checks do not replace the native build or physical-device UI/scroll testing.
