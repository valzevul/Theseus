import UIKit
import Theseus

class TabBarDemoViewController: UIViewController {

    private let nativeTabBar = UITabBar()
    private let theseusTabBar = TheseusTabBar()
    private let gradientLayer = CAGradientLayer()

    // Default values
    private struct Defaults {
        static let tintColorIndex = 0
        static let blurRadius: Float = 2.0
        static let tintColors: [UIColor] = [.systemBlue, .systemPurple, .systemPink, .systemOrange]
    }

    // Current settings (for sheet sync)
    private var currentTintIndex = Defaults.tintColorIndex
    private var currentBlurRadius = Defaults.blurRadius

    private var isDarkMode: Bool {
        get { AppearanceManager.shared.isDarkMode }
        set { AppearanceManager.shared.isDarkMode = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupGradientBackground()
        setupNavigationBar()
        setupTabBars()
        applyDefaults()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAppearance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    private func setupGradientBackground() {
        updateGradientColors()
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func updateGradientColors() {
        if isDarkMode {
            gradientLayer.colors = [
                UIColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1.0).cgColor,
                UIColor(red: 0.20, green: 0.18, blue: 0.25, alpha: 1.0).cgColor,
                UIColor(red: 0.18, green: 0.20, blue: 0.28, alpha: 1.0).cgColor
            ]
        } else {
            gradientLayer.colors = [
                UIColor(red: 0.95, green: 0.85, blue: 0.82, alpha: 1.0).cgColor,
                UIColor(red: 0.92, green: 0.80, blue: 0.85, alpha: 1.0).cgColor,
                UIColor(red: 0.88, green: 0.78, blue: 0.82, alpha: 1.0).cgColor
            ]
        }
    }

    private func setupNavigationBar() {
        title = "Tab Bar"
        navigationController?.navigationBar.prefersLargeTitles = false

        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )

        let darkModeButton = UIBarButtonItem(
            image: UIImage(systemName: "moon.fill"),
            style: .plain,
            target: self,
            action: #selector(toggleDarkMode)
        )

        navigationItem.rightBarButtonItems = [darkModeButton, settingsButton]
    }

    @objc private func toggleDarkMode() {
        isDarkMode.toggle()
        updateAppearance()
    }

    private func updateAppearance() {
        if let items = navigationItem.rightBarButtonItems, items.count > 0 {
            items[0].image = UIImage(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
        }

        updateGradientColors()

        // Update unselected tab color for dark/light mode
        theseusTabBar.unselectedTintColor = isDarkMode ? .white : .black
    }

    @objc private func showSettings() {
        let settingsVC = TabBarSettingsViewController(
            tintIndex: currentTintIndex,
            blurRadius: currentBlurRadius
        )
        settingsVC.delegate = self

        let nav = UINavigationController(rootViewController: settingsVC)
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
            }
        }
        present(nav, animated: true)
    }

    private func applyDefaults() {
        currentTintIndex = Defaults.tintColorIndex
        currentBlurRadius = Defaults.blurRadius

        applySettings()
    }

    private func applySettings() {
        theseusTabBar.selectedTintColor = Defaults.tintColors[currentTintIndex]
        theseusTabBar.glassBlurRadius = CGFloat(currentBlurRadius)
        nativeTabBar.tintColor = Defaults.tintColors[currentTintIndex]
    }

    private func setupTabBars() {
        // Tab bar items
        let tabItems: [(String, String)] = [
            ("doc.text.image", "Today"),
            ("gamecontroller", "Games"),
            ("square.stack.3d.up.fill", "Apps"),
            ("dpad.fill", "Arcade"),
            ("magnifyingglass", "Search")
        ]

        // Native TabBar
        let nativeStack = createTabBarStack(
            label: "Native UITabBar",
            tabBarView: nativeTabBar
        )

        nativeTabBar.items = tabItems.map { item in
            UITabBarItem(title: item.1, image: UIImage(systemName: item.0), tag: 0)
        }
        nativeTabBar.selectedItem = nativeTabBar.items?.first
        nativeTabBar.delegate = self

        // Theseus TabBar
        let liquidStack = createTabBarStack(
            label: "TheseusTabBar",
            tabBarView: theseusTabBar
        )

        theseusTabBar.items = tabItems.map { item in
            TheseusTabBarItem(icon: UIImage(systemName: item.0), selectedIcon: UIImage(systemName: item.0 + ".fill") ?? UIImage(systemName: item.0), title: item.1)
        }
        theseusTabBar.selectedIndex = 0
        theseusTabBar.unselectedTintColor = .black
        theseusTabBar.onItemSelected = { [weak self] index in
            guard let self = self else { return }
            self.nativeTabBar.selectedItem = self.nativeTabBar.items?[index]
        }

        let mainStack = UIStackView(arrangedSubviews: [nativeStack, liquidStack])
        mainStack.axis = .vertical
        mainStack.spacing = 40
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            nativeTabBar.heightAnchor.constraint(equalToConstant: 49),
            theseusTabBar.heightAnchor.constraint(equalToConstant: 63)
        ])
    }

    private func createTabBarStack(label: String, tabBarView: UIView) -> UIStackView {
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 14, weight: .medium)
        labelView.textColor = .label

        let stack = UIStackView(arrangedSubviews: [labelView, tabBarView])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill

        return stack
    }
}

// MARK: - UITabBarDelegate

extension TabBarDemoViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if let index = tabBar.items?.firstIndex(of: item) {
            theseusTabBar.selectedIndex = index
        }
    }
}

// MARK: - Settings Delegate

extension TabBarDemoViewController: TabBarSettingsDelegate {
    func settingsDidChange(tintIndex: Int, blurRadius: Float) {
        currentTintIndex = tintIndex
        currentBlurRadius = blurRadius

        applySettings()
    }

    func settingsDidReset() {
        applyDefaults()
    }
}

// MARK: - Settings View Controller

protocol TabBarSettingsDelegate: AnyObject {
    func settingsDidChange(tintIndex: Int, blurRadius: Float)
    func settingsDidReset()
}

class TabBarSettingsViewController: UIViewController {

    weak var delegate: TabBarSettingsDelegate?

    private let tintSegment = UISegmentedControl(items: ["Blue", "Purple", "Pink", "Orange"])
    private let blurSlider = UISlider()
    private let blurValueLabel = UILabel()

    private var initialTintIndex: Int
    private var initialBlurRadius: Float

    init(tintIndex: Int, blurRadius: Float) {
        self.initialTintIndex = tintIndex
        self.initialBlurRadius = blurRadius
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Settings"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissSettings)
        )

        setupControls()
    }

    @objc private func dismissSettings() {
        dismiss(animated: true)
    }

    private func setupControls() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Tint Color
        let tintLabel = createLabel("Tab Tint Color")
        tintSegment.selectedSegmentIndex = initialTintIndex
        tintSegment.addTarget(self, action: #selector(settingsChanged), for: .valueChanged)
        contentStack.addArrangedSubview(createSettingRow(label: tintLabel, control: tintSegment))

        // Blur Radius
        let blurLabel = createLabel("Blur Radius")
        blurValueLabel.text = String(format: "%.1f", initialBlurRadius)
        blurValueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        blurValueLabel.textColor = .secondaryLabel
        blurSlider.minimumValue = 0
        blurSlider.maximumValue = 15
        blurSlider.value = initialBlurRadius
        blurSlider.addTarget(self, action: #selector(blurSliderChanged), for: .valueChanged)
        contentStack.addArrangedSubview(createSliderRow(label: blurLabel, valueLabel: blurValueLabel, slider: blurSlider))

        // Reset Button
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset to Defaults", for: .normal)
        resetButton.setTitleColor(.systemRed, for: .normal)
        resetButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        resetButton.addTarget(self, action: #selector(resetToDefaults), for: .touchUpInside)
        contentStack.addArrangedSubview(resetButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    private func createLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        return label
    }

    private func createSettingRow(label: UILabel, control: UIView) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    private func createSliderRow(label: UILabel, valueLabel: UILabel, slider: UISlider) -> UIStackView {
        let headerStack = UIStackView(arrangedSubviews: [label, valueLabel])
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [headerStack, slider])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    @objc private func settingsChanged() {
        notifyDelegate()
    }

    @objc private func blurSliderChanged() {
        blurValueLabel.text = String(format: "%.1f", blurSlider.value)
        notifyDelegate()
    }

    private func notifyDelegate() {
        delegate?.settingsDidChange(
            tintIndex: tintSegment.selectedSegmentIndex,
            blurRadius: blurSlider.value
        )
    }

    @objc private func resetToDefaults() {
        tintSegment.selectedSegmentIndex = 0
        blurSlider.value = 2.0
        blurValueLabel.text = "2.0"

        delegate?.settingsDidReset()
    }
}
