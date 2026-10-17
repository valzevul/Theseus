import SwiftUI
import Theseus

@main
struct TheseusDemoSwiftUIApp: App {
    private let previewScene = UserDefaults.standard.string(forKey: "preview")

    init() {
        if UserDefaults.standard.object(forKey: "spectrum") != nil {
            TheseusSettings.shared.tintSpectrum = CGFloat(UserDefaults.standard.double(forKey: "spectrum"))
        }
    }

    var body: some Scene {
        WindowGroup {
            if let scene = previewScene {
                ReadmePreviewHost(scene: scene)
            } else {
                ContentView()
            }
        }
    }
}
