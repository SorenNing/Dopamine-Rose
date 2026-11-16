import Foundation

// The app target compiles the pinned shader into its own default.metallib.
// Keep the upstream MetalContext byte-identical to the Swift package version.
extension Bundle {
    static var module: Bundle { .main }
}
