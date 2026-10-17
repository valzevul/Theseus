import SwiftUI
import UIKit
import Theseus

// MARK: - TheseusView Representable

struct TheseusViewRepresentable: UIViewRepresentable {
    var configuration: TheseusConfiguration
    var sourceView: UIView?

    init(configuration: TheseusConfiguration = TheseusConfiguration()) {
        self.configuration = configuration
    }

    func makeUIView(context: Context) -> TheseusView {
        let view = TheseusView(configuration: configuration)
        return view
    }

    func updateUIView(_ uiView: TheseusView, context: Context) {
        uiView.configuration = configuration
        if let source = sourceView {
            uiView.sourceView = source
        }
    }
}

// MARK: - TheseusTabBar Representable

struct TheseusTabBarRepresentable: UIViewRepresentable {
    var items: [TheseusTabBarItem]
    @Binding var selectedIndex: Int
    var selectedTintColor: UIColor
    var unselectedTintColor: UIColor
    var glassBlurRadius: CGFloat
    var lensMaterial: TheseusLensMaterial?
    var onMake: ((TheseusTabBar) -> Void)? = nil
    var backdropVersion: Int

    init(
        items: [TheseusTabBarItem],
        selectedIndex: Binding<Int>,
        selectedTintColor: UIColor = .systemBlue,
        unselectedTintColor: UIColor = TheseusTabBar.nativeUnselectedTint,
        glassBlurRadius: CGFloat = 0.0,
        lensMaterial: TheseusLensMaterial? = nil,
        backdropVersion: Int = 0,
        onMake: ((TheseusTabBar) -> Void)? = nil
    ) {
        self.items = items
        self._selectedIndex = selectedIndex
        self.selectedTintColor = selectedTintColor
        self.unselectedTintColor = unselectedTintColor
        self.glassBlurRadius = glassBlurRadius
        self.lensMaterial = lensMaterial
        self.backdropVersion = backdropVersion
        self.onMake = onMake
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> TheseusTabBar {
        let tabBar = TheseusTabBar()
        onMake?(tabBar)
        tabBar.items = items
        tabBar.selectedIndex = selectedIndex
        tabBar.selectedTintColor = selectedTintColor
        tabBar.unselectedTintColor = unselectedTintColor
        tabBar.glassBlurRadius = glassBlurRadius
        if let lensMaterial = lensMaterial {
            tabBar.lensMaterial = lensMaterial
        }
        tabBar.onItemSelected = { index in
            context.coordinator.parent.selectedIndex = index
        }
        return tabBar
    }

    func updateUIView(_ uiView: TheseusTabBar, context: Context) {
        if let lensMaterial = lensMaterial, uiView.lensMaterial != lensMaterial {
            uiView.lensMaterial = lensMaterial
        }
        // Only update items if count changed to avoid rebuild
        if uiView.items.count != items.count {
            uiView.items = items
        }
        uiView.selectedIndex = selectedIndex
        uiView.selectedTintColor = selectedTintColor
        uiView.unselectedTintColor = unselectedTintColor
        // Only update glass properties if changed to avoid invalidation during drag
        if uiView.glassBlurRadius != glassBlurRadius {
            uiView.glassBlurRadius = glassBlurRadius
        }
        if context.coordinator.backdropVersion != backdropVersion {
            context.coordinator.backdropVersion = backdropVersion
            uiView.invalidateBackground()
        }
    }

    class Coordinator {
        var parent: TheseusTabBarRepresentable
        var backdropVersion = 0

        init(_ parent: TheseusTabBarRepresentable) {
            self.parent = parent
        }
    }
}

// MARK: - TheseusSwitch Representable

struct TheseusSwitchRepresentable: UIViewRepresentable {
    @Binding var isOn: Bool
    var onTintColor: UIColor
    var offTintColor: UIColor?
    var thumbTintColor: UIColor

    init(
        isOn: Binding<Bool>,
        onTintColor: UIColor = UIColor(red: 0.259, green: 0.831, blue: 0.318, alpha: 1.0),
        offTintColor: UIColor? = nil,
        thumbTintColor: UIColor = .white
    ) {
        self._isOn = isOn
        self.onTintColor = onTintColor
        self.offTintColor = offTintColor
        self.thumbTintColor = thumbTintColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> TheseusSwitch {
        let switchControl = TheseusSwitch()
        switchControl.isOn = isOn
        switchControl.onTintColor = onTintColor
        if let offTintColor { switchControl.offTintColor = offTintColor }
        switchControl.thumbTintColor = thumbTintColor
        switchControl.onValueChanged = { newValue in
            context.coordinator.parent.isOn = newValue
        }
        return switchControl
    }

    func updateUIView(_ uiView: TheseusSwitch, context: Context) {
        if uiView.isOn != isOn {
            uiView.setOn(isOn, animated: true)
        }
        uiView.onTintColor = onTintColor
        if let offTintColor { uiView.offTintColor = offTintColor }
        uiView.thumbTintColor = thumbTintColor
    }

    class Coordinator {
        var parent: TheseusSwitchRepresentable

        init(_ parent: TheseusSwitchRepresentable) {
            self.parent = parent
        }
    }
}

// MARK: - TheseusSlider Representable

struct TheseusSliderRepresentable: UIViewRepresentable {
    @Binding var value: CGFloat
    var minimumValue: CGFloat
    var maximumValue: CGFloat
    var trackColor: UIColor
    var backColor: UIColor?
    var knobColor: UIColor
    var positionsCount: Int

    init(
        value: Binding<CGFloat>,
        minimumValue: CGFloat = 0,
        maximumValue: CGFloat = 1,
        trackColor: UIColor = UIColor(white: 0.4, alpha: 1.0),
        backColor: UIColor? = nil,
        knobColor: UIColor = .white,
        positionsCount: Int = 0
    ) {
        self._value = value
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.trackColor = trackColor
        self.backColor = backColor
        self.knobColor = knobColor
        self.positionsCount = positionsCount
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> TheseusSlider {
        let slider = TheseusSlider()
        slider.minimumValue = minimumValue
        slider.maximumValue = maximumValue
        slider.setValue(value)
        slider.trackColor = trackColor
        if let backColor { slider.backColor = backColor }
        slider.knobColor = knobColor
        slider.positionsCount = positionsCount
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        return slider
    }

    func updateUIView(_ uiView: TheseusSlider, context: Context) {
        uiView.minimumValue = minimumValue
        uiView.maximumValue = maximumValue
        if !uiView.isTracking {
            uiView.setValue(value)
        }
        uiView.trackColor = trackColor
        if let backColor { uiView.backColor = backColor }
        uiView.knobColor = knobColor
        uiView.positionsCount = positionsCount
    }

    class Coordinator: NSObject {
        var parent: TheseusSliderRepresentable

        init(_ parent: TheseusSliderRepresentable) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: TheseusSlider) {
            parent.value = sender.value
        }
    }
}
