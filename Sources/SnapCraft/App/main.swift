import AppKit

// Entry point. Normally launches the menu-bar app; with `--render-previews <dir>`
// it renders the Editor and Settings screens to PNGs and exits (used to verify
// pixel fidelity without an interactive capture).
MainActor.assumeIsolated {
    let arguments = CommandLine.arguments
    if let idx = arguments.firstIndex(of: "--render-previews"), idx + 1 < arguments.count {
        PreviewRenderer.run(outputDirectory: arguments[idx + 1])
    } else {
        SnapCraftApp.main()
    }
}
