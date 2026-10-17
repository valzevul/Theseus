import UIKit
import Theseus

class SettingsViewController: UITableViewController {

    private let settings = TheseusSettings.shared

    private enum Section: Int, CaseIterable {
        case deviceInfo
        case appearance
        case tierOverride
        case iosOverride
        case policyOverride
        case qualityOverride
        case fallback
        case simulation
        case reset
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Settings"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissSettings)
        )

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(SwitchCell.self, forCellReuseIdentifier: "SwitchCell")
        tableView.register(SliderCell.self, forCellReuseIdentifier: "SliderCell")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: TheseusSettings.settingsDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func dismissSettings() {
        dismiss(animated: true)
    }

    @objc private func settingsDidChange() {
        tableView.reloadData()
    }

    // MARK: - Table View Data Source

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .deviceInfo: return 5
        case .appearance: return 1
        case .tierOverride: return DeviceTier.allCases.count + 1 // +1 for Auto
        case .iosOverride: return 7 // Current + iOS 13-18
        case .policyOverride: return RefractionPolicy.allCases.count + 1
        case .qualityOverride: return RefractionQuality.allCases.count + 1
        case .fallback: return 1
        case .simulation: return 3
        case .reset: return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .deviceInfo: return "Device Info"
        case .appearance: return "Liquid Glass Appearance (iOS 27)"
        case .tierOverride: return "Device Tier Override"
        case .iosOverride: return "iOS Version Simulation"
        case .policyOverride: return "Refraction Policy Override"
        case .qualityOverride: return "Refraction Quality Override"
        case .fallback: return "Rendering Mode"
        case .simulation: return "Environment Simulation"
        case .reset: return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .deviceInfo:
            return deviceInfoCell(for: indexPath)
        case .appearance:
            return appearanceCell(for: indexPath)
        case .tierOverride:
            return tierOverrideCell(for: indexPath)
        case .iosOverride:
            return iosOverrideCell(for: indexPath)
        case .policyOverride:
            return policyOverrideCell(for: indexPath)
        case .qualityOverride:
            return qualityOverrideCell(for: indexPath)
        case .fallback:
            return fallbackCell(for: indexPath)
        case .simulation:
            return simulationCell(for: indexPath)
        case .reset:
            return resetCell(for: indexPath)
        }
    }

    // MARK: - Cell Configuration

    private func deviceInfoCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.selectionStyle = .none
        cell.accessoryType = .none

        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Detected Tier: \(TheseusCapability.deviceTier.description)"
        case 1:
            cell.textLabel?.text = "Memory: \(String(format: "%.1f", TheseusCapability.physicalMemoryGB)) GB"
        case 2:
            cell.textLabel?.text = "Cores: \(TheseusCapability.processorCount)"
        case 3:
            cell.textLabel?.text = "iOS Version: \(TheseusCapability.iosVersionString)"
        case 4:
            cell.textLabel?.text = "Metal: \(TheseusCapability.isMetalAvailable ? "Available" : "Not Available")"
        default:
            break
        }

        cell.textLabel?.font = .systemFont(ofSize: 14)
        cell.textLabel?.textColor = .secondaryLabel
        return cell
    }

    private func appearanceCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SliderCell", for: indexPath) as! SliderCell
        cell.configure(
            minimumLabel: "Clear",
            maximumLabel: "Tinted",
            value: Float(settings.tintSpectrum)
        ) { [weak self] value in
            self?.settings.tintSpectrum = CGFloat(value)
        }
        return cell
    }

    private func tierOverrideCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        if indexPath.row == 0 {
            cell.textLabel?.text = "Auto (Detected)"
            cell.accessoryType = settings.tierOverride == nil ? .checkmark : .none
        } else {
            let tier = DeviceTier.allCases[indexPath.row - 1]
            cell.textLabel?.text = tier.description
            cell.accessoryType = settings.tierOverride == tier ? .checkmark : .none
        }

        cell.textLabel?.font = .systemFont(ofSize: 16)
        cell.textLabel?.textColor = .label
        return cell
    }

    private func iosOverrideCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        if indexPath.row == 0 {
            cell.textLabel?.text = "Current (iOS \(TheseusCapability.iosMajorVersion))"
            cell.accessoryType = settings.iosVersionOverride == nil ? .checkmark : .none
        } else {
            let version = 12 + indexPath.row // iOS 13-18
            cell.textLabel?.text = "iOS \(version)"
            cell.accessoryType = settings.iosVersionOverride == version ? .checkmark : .none
        }

        cell.textLabel?.font = .systemFont(ofSize: 16)
        cell.textLabel?.textColor = .label
        return cell
    }

    private func policyOverrideCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        if indexPath.row == 0 {
            let autoPolicy = settings.effectiveRefractionPolicy
            cell.textLabel?.text = "Auto (\(autoPolicy.description))"
            cell.accessoryType = settings.refractionPolicyOverride == nil ? .checkmark : .none
        } else {
            let policy = RefractionPolicy.allCases[indexPath.row - 1]
            cell.textLabel?.text = policy.description
            cell.accessoryType = settings.refractionPolicyOverride == policy ? .checkmark : .none
        }

        cell.textLabel?.font = .systemFont(ofSize: 16)
        cell.textLabel?.textColor = .label
        return cell
    }

    private func qualityOverrideCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        if indexPath.row == 0 {
            let autoQuality = settings.effectiveRefractionQuality
            cell.textLabel?.text = "Auto (\(autoQuality.description))"
            cell.accessoryType = settings.refractionQualityOverride == nil ? .checkmark : .none
        } else {
            let quality = RefractionQuality.allCases[indexPath.row - 1]
            cell.textLabel?.text = quality.description
            cell.accessoryType = settings.refractionQualityOverride == quality ? .checkmark : .none
        }

        cell.textLabel?.font = .systemFont(ofSize: 16)
        cell.textLabel?.textColor = .label
        return cell
    }

    private func fallbackCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchCell

        let willUseFallback = settings.shouldUseFallback
        cell.configure(
            title: "Force UIVisualEffectView Fallback",
            subtitle: willUseFallback ? "Active (Metal disabled)" : "Metal rendering active",
            isOn: settings.forceFallback
        ) { [weak self] isOn in
            self?.settings.forceFallback = isOn
        }

        return cell
    }

    private func simulationCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchCell

        switch indexPath.row {
        case 0:
            let actual = TheseusEnvironment.shared.isLowPowerModeEnabled
            cell.configure(
                title: "Simulate Low Power Mode",
                subtitle: "Actual: \(actual ? "On" : "Off")",
                isOn: settings.simulateLowPowerMode ?? false
            ) { [weak self] isOn in
                self?.settings.simulateLowPowerMode = isOn ? true : nil
            }
        case 1:
            let actual = TheseusEnvironment.shared.reduceTransparencyEnabled
            cell.configure(
                title: "Simulate Reduce Transparency",
                subtitle: "Actual: \(actual ? "On" : "Off")",
                isOn: settings.simulateReduceTransparency ?? false
            ) { [weak self] isOn in
                self?.settings.simulateReduceTransparency = isOn ? true : nil
            }
        case 2:
            let actual = TheseusEnvironment.shared.reduceMotionEnabled
            cell.configure(
                title: "Simulate Reduce Motion",
                subtitle: "Actual: \(actual ? "On" : "Off")",
                isOn: settings.simulateReduceMotion ?? false
            ) { [weak self] isOn in
                self?.settings.simulateReduceMotion = isOn ? true : nil
            }
        default:
            break
        }

        return cell
    }

    private func resetCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = "Reset to Defaults"
        cell.textLabel?.textColor = .systemRed
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        cell.textLabel?.textAlignment = .center
        cell.accessoryType = .none
        return cell
    }

    // MARK: - Selection Handling

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section)! {
        case .tierOverride:
            if indexPath.row == 0 {
                settings.tierOverride = nil
            } else {
                settings.tierOverride = DeviceTier.allCases[indexPath.row - 1]
            }
        case .iosOverride:
            if indexPath.row == 0 {
                settings.iosVersionOverride = nil
            } else {
                settings.iosVersionOverride = 12 + indexPath.row
            }
        case .policyOverride:
            if indexPath.row == 0 {
                settings.refractionPolicyOverride = nil
            } else {
                settings.refractionPolicyOverride = RefractionPolicy.allCases[indexPath.row - 1]
            }
        case .qualityOverride:
            if indexPath.row == 0 {
                settings.refractionQualityOverride = nil
            } else {
                settings.refractionQualityOverride = RefractionQuality.allCases[indexPath.row - 1]
            }
        case .reset:
            settings.resetToDefaults()
        default:
            break
        }

        tableView.reloadData()
    }
}

// MARK: - Slider Cell

private class SliderCell: UITableViewCell {
    private let slider = UISlider()
    private let minimumLabel = UILabel()
    private let maximumLabel = UILabel()
    private var onValueChanged: ((Float) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        minimumLabel.font = .systemFont(ofSize: 13)
        minimumLabel.textColor = .secondaryLabel
        maximumLabel.font = .systemFont(ofSize: 13)
        maximumLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [minimumLabel, slider, maximumLabel])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            stack.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(minimumLabel: String, maximumLabel: String, value: Float, onValueChanged: @escaping (Float) -> Void) {
        self.minimumLabel.text = minimumLabel
        self.maximumLabel.text = maximumLabel
        // Skip the reload while the user is tracking a slider.
        if !slider.isTracking {
            slider.value = value
        }
        self.onValueChanged = onValueChanged
    }

    @objc private func sliderChanged() {
        onValueChanged?(slider.value)
    }
}

// MARK: - Switch Cell

private class SwitchCell: UITableViewCell {
    private let toggle = UISwitch()
    private let subtitleLabel = UILabel()
    private var onValueChanged: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        toggle.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        accessoryView = toggle

        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, subtitle: String? = nil, isOn: Bool, onValueChanged: @escaping (Bool) -> Void) {
        textLabel?.text = title
        toggle.isOn = isOn
        self.onValueChanged = onValueChanged

        subtitleLabel.removeFromSuperview()
        if let subtitle = subtitle {
            subtitleLabel.text = subtitle
            contentView.addSubview(subtitleLabel)
            NSLayoutConstraint.activate([
                subtitleLabel.topAnchor.constraint(equalTo: textLabel!.bottomAnchor, constant: 2),
                subtitleLabel.leadingAnchor.constraint(equalTo: textLabel!.leadingAnchor)
            ])
        }
    }

    @objc private func switchChanged() {
        onValueChanged?(toggle.isOn)
    }
}
