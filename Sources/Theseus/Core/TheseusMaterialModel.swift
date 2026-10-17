import UIKit

/// Neutral material body fitted to native regular glass on iOS 27; both render
/// backends and the capture veil derive from it.
enum TheseusMaterialModel {

    /// Native regular glass, light appearance: out = in + mix x (pole - in).
    static let lightMixAlpha: CGFloat = 0.53
    static let lightPole: CGFloat = 0.99

    /// Native regular glass, dark appearance: out = lift + range x (1 - e^(-in / scale)),
    /// in units of full white.
    static let darkToneLift: CGFloat = 0.1148
    static let darkToneRange: CGFloat = 0.7557
    static let darkToneScale: CGFloat = 0.6787

    /// Chroma scale about luminance that native regular glass applies after
    /// the tone step; `TheseusTheme.backdropSaturation` multiplies it.
    static func chromaScale(isDark: Bool) -> CGFloat {
        isDark ? 1.043 : 0.937
    }

    static func darkTone(_ value: CGFloat) -> CGFloat {
        darkToneLift + darkToneRange * (1.0 - exp(-max(value, 0.0) / darkToneScale))
    }

    /// Native regular glass at Tint Amount 0, 0.25, 0.5, 0.75 and 1: light mixes
    /// toward `lightPole`; dark keeps its tone to 0.5, then mixes toward `darkTintPole`.
    static let lightTintMixes: [CGFloat] = [0.4104, 0.4698, 0.53, 0.6218, 0.7127]
    static let darkTintMixes: [CGFloat] = [0, 0, 0, 0.276, 0.4847]
    static let darkTintPole: CGFloat = 0.1125

    /// iOS 26's Clear and Tinted looks: a plain mix toward a pole.
    struct PoleMix: Equatable {
        let mix: CGFloat
        let pole: CGFloat
    }

    static let iOS26LightClear = PoleMix(mix: 0.687, pole: 0.99)
    static let iOS26LightTinted = PoleMix(mix: 0.846, pole: 0.974)
    static let iOS26DarkClear = PoleMix(mix: 0.764, pole: 0.149)
    static let iOS26DarkTinted = PoleMix(mix: 0.78, pole: 0.0956)

    static func tintCurve(_ values: [CGFloat], at spectrum: CGFloat) -> CGFloat {
        let position = min(max(spectrum, 0.0), 1.0) * CGFloat(values.count - 1)
        let index = min(Int(position), values.count - 2)
        let t = position - CGFloat(index)
        return values[index] + (values[index + 1] - values[index]) * t
    }

    /// What the body does to the backdrop's luminance: the dark tone at
    /// `toneStrength`, then a mix toward `pole` at `poleMix`.
    struct BodyTransfer: Equatable {
        var toneStrength: CGFloat
        var poleMix: CGFloat
        var pole: CGFloat
    }

    static func bodyTransfer(
        configuration: TheseusConfiguration,
        isDark: Bool,
        spectrum: CGFloat,
        style: TheseusSettings.GlassStyle
    ) -> BodyTransfer {
        let plainMix = poleMix(configuration: configuration)
        if plainMix > 0 {
            return BodyTransfer(toneStrength: 0, poleMix: plainMix, pole: pole(configuration: configuration))
        }
        let scale = min(max(configuration.theme.neutralBodyScale, 0.0), 4.0)
        let s = min(max(spectrum, 0.0), 1.0)
        if style == .iOS26 {
            let clear = isDark ? iOS26DarkClear : iOS26LightClear
            let tinted = isDark ? iOS26DarkTinted : iOS26LightTinted
            let mix = clear.mix + (tinted.mix - clear.mix) * s
            let pole = clear.pole + (tinted.pole - clear.pole) * s
            return BodyTransfer(toneStrength: 0, poleMix: min(mix * scale, 1.0), pole: pole)
        }
        if isDark {
            return BodyTransfer(
                toneStrength: min(scale, 1.5),
                poleMix: tintCurve(darkTintMixes, at: s) * min(scale, 1.0),
                pole: darkTintPole
            )
        }
        return BodyTransfer(toneStrength: 0, poleMix: min(tintCurve(lightTintMixes, at: s) * scale, 1.0), pole: lightPole)
    }

    /// Body strength relative to regular glass at iOS 27's default Tint Amount.
    static func bodyStrength(configuration: TheseusConfiguration, spectrum: CGFloat) -> CGFloat {
        let scale = min(max(configuration.theme.neutralBodyScale, 0.0), 4.0)
        return scale * tintCurve(lightTintMixes, at: spectrum) / lightMixAlpha
    }

    /// Additive lift, fraction of white; negative darkens.
    static func liftAmount(configuration: TheseusConfiguration) -> CGFloat {
        min(max(configuration.theme.luminanceLift, -1.0), 1.0)
    }

    static func gain(configuration: TheseusConfiguration) -> CGFloat {
        min(max(configuration.theme.backdropGain, 0.0), 2.0)
    }

    static func curveValue(_ curve: [CGFloat], at input: CGFloat) -> CGFloat {
        let position = min(max(input, 0.0), 1.0) * CGFloat(curve.count - 1)
        let index = min(Int(position), curve.count - 2)
        return curve[index] + (curve[index + 1] - curve[index]) * (position - CGFloat(index))
    }

    static func chromaScale(configuration: TheseusConfiguration, isDark: Bool, spectrum: CGFloat, luminance: CGFloat) -> CGFloat {
        let base = chromaScale(configuration: configuration, isDark: isDark, spectrum: spectrum)
        guard configuration.theme.bodyCurve != nil else { return base }
        return (base + configuration.theme.bodyCurveChromaSlope * min(max(luminance, 0.0), 1.0)) * configuration.theme.bodyCurveSaturation
    }

    static func chromaScale(configuration: TheseusConfiguration, isDark: Bool, spectrum: CGFloat) -> CGFloat {
        let saturation = min(max(configuration.theme.backdropSaturation, 0.0), 4.0)
        if configuration.theme.bodyCurve != nil {
            return saturation
        }
        if poleMix(configuration: configuration) > 0 {
            return saturation
        }
        let strength = min(bodyStrength(configuration: configuration, spectrum: spectrum), 1.0)
        let native = 1.0 + (chromaScale(isDark: isDark) - 1.0) * strength
        return native * saturation
    }

    /// Weight of the plain pole mix, 0 when the surface uses the regular transfer.
    static func poleMix(configuration: TheseusConfiguration) -> CGFloat {
        min(max(configuration.theme.bodyPoleMix, 0.0), 1.0)
    }

    static func pole(configuration: TheseusConfiguration) -> CGFloat {
        min(max(configuration.theme.bodyPole, 0.0), 1.0)
    }

    /// The body transfer for one grey level.
    static func bodyValue(
        _ input: CGFloat,
        configuration: TheseusConfiguration,
        isDark: Bool,
        spectrum: CGFloat,
        style: TheseusSettings.GlassStyle = TheseusSettings.shared.effectiveGlassStyle
    ) -> CGFloat {
        if let curve = configuration.theme.bodyCurve, curve.count > 1 {
            let value = min(max(curveValue(curve, at: input), 0.0), 1.0) * gain(configuration: configuration) + liftAmount(configuration: configuration)
            return min(max(value, 0.0), 1.0)
        }
        let transfer = bodyTransfer(configuration: configuration, isDark: isDark, spectrum: spectrum, style: style)
        var value = min(max(input, 0.0), 1.0)
        if transfer.toneStrength > 0 {
            value += (darkTone(value) - value) * transfer.toneStrength
        }
        if transfer.poleMix > 0 {
            value += (transfer.pole - value) * transfer.poleMix
        }
        value *= gain(configuration: configuration)
        value += liftAmount(configuration: configuration)
        return min(max(value, 0.0), 1.0)
    }

    /// A brand tint as native regular glass composes it over the untinted body.
    struct TintModel: Equatable {
        var gain: CGFloat
        var offset: CGFloat
        var closing: CGFloat
        var toPole: CGFloat
        var threshold: CGFloat
        var pole: CGFloat
    }

    static let lightTint = TintModel(gain: 0.221, offset: 0.141, closing: 0, toPole: 0, threshold: 0, pole: 0)
    static let darkTint = TintModel(gain: 0, offset: 0, closing: 0.103, toPole: 0.146, threshold: 0.146, pole: 0.872)

    static func tintModel(isDark: Bool) -> TintModel {
        isDark ? darkTint : lightTint
    }

    /// The tinted glass over an untinted `body`, as the shader composes it.
    static func tinted(_ tint: [CGFloat], alpha: CGFloat, weight: CGFloat = 1, body: [CGFloat], model: TintModel) -> [CGFloat] {
        let clampedBody = body.map { min(max($0, 0), 1) }
        let luminance = min(max(0.2126 * clampedBody[0] + 0.7152 * clampedBody[1] + 0.0722 * clampedBody[2], 0), 1)
        let shortfall = 1 - luminance
        var target = tint.map { min(max($0, 0), 1) * (1 - model.gain * shortfall) - model.offset * shortfall }
        let rise = max(luminance - model.threshold, 0)
        let strongest = target.max() ?? 0
        target = target.map { strongest - (1 - model.closing * rise) * (strongest - $0) }
        target = target.map { min(max($0 + model.toPole * rise * (model.pole - $0), 0), 1) }
        let share = min(max(weight, 0), 1) * min(max(alpha, 0), 1)
        return (0..<3).map { body[$0] + share * (target[$0] - body[$0]) }
    }

    /// The colour and alpha that, composited over `backdrop`, give `result`:
    /// at least `minimumAlpha`, more where a channel would leave 0...1.
    static func veil(producing result: [CGFloat], over backdrop: [CGFloat], minimumAlpha: CGFloat) -> UIColor {
        var alpha = min(max(minimumAlpha, 0), 1)
        for index in 0..<3 {
            let difference = result[index] - backdrop[index]
            if difference > 0.0001 {
                alpha = max(alpha, difference / max(1 - backdrop[index], 0.0001))
            } else if difference < -0.0001 {
                alpha = max(alpha, -difference / max(backdrop[index], 0.0001))
            }
        }
        alpha = min(alpha, 1)
        guard alpha > 0.0001 else { return UIColor(white: 1, alpha: 0) }
        let value = (0..<3).map { min(max((result[$0] - (1 - alpha) * backdrop[$0]) / alpha, 0), 1) }
        return UIColor(red: value[0], green: value[1], blue: value[2], alpha: alpha)
    }

    /// Flat stand-in for `layer.render` captures, which cannot read the Metal
    /// sublayer; the body's slope around the backdrop's mean sets the alpha.
    static func veilColor(
        configuration: TheseusConfiguration,
        isDark: Bool,
        spectrum: CGFloat,
        backdrop: CaptureColor
    ) -> UIColor {
        let mean = min(max(backdrop.luminance, 0.05), 0.95)
        let delta: CGFloat = 0.05
        let low = bodyValue(mean - delta, configuration: configuration, isDark: isDark, spectrum: spectrum)
        let high = bodyValue(mean + delta, configuration: configuration, isDark: isDark, spectrum: spectrum)
        let target = bodyValue(mean, configuration: configuration, isDark: isDark, spectrum: spectrum)
        let slope = (high - low) / (2 * delta)
        let chroma = chromaScale(configuration: configuration, isDark: isDark, spectrum: spectrum, luminance: backdrop.luminance)
        let gain = self.gain(configuration: configuration)
        let back = [backdrop.red, backdrop.green, backdrop.blue].map { min(max($0, 0), 1) }
        let body = back.map { min(max(target + ($0 - backdrop.luminance) * chroma * gain, 0), 1) }
        var alpha = min(max(1.0 - slope, 0.0), 1.0)
        for index in 0..<3 {
            let difference = body[index] - back[index]
            if difference > 0.0001 {
                alpha = max(alpha, difference / max(1 - back[index], 0.0001))
            } else if difference < -0.0001 {
                alpha = max(alpha, -difference / max(back[index], 0.0001))
            }
        }
        alpha = min(alpha, 1)
        guard alpha > 0.0001 else {
            return UIColor(white: 1, alpha: 0)
        }
        let value = (0..<3).map { min(max((body[$0] - (1 - alpha) * back[$0]) / alpha, 0), 1) }
        return UIColor(red: value[0], green: value[1], blue: value[2], alpha: alpha)
    }

    /// The stand-in for a `GlassRim` surface: its face over the backdrop's
    /// mean, as opaque as the detail the face and the frost remove.
    static func veilColor(
        glassRim: TheseusConfiguration.GlassRim,
        isDark: Bool,
        spectrum: CGFloat,
        backdrop: CaptureColor
    ) -> UIColor {
        let style = TheseusSettings.shared.effectiveGlassStyle
        let face = glassRim.face(isDark: isDark, tintAmount: spectrum, style: style)
        let back = [backdrop.red, backdrop.green, backdrop.blue].map { min(max($0, 0), 1) }
        let mean = min(max(backdrop.luminance, 0.05), 0.95)
        let delta: CGFloat = 0.05
        let slope = (face.apply([mean + delta, mean + delta, mean + delta])[1] - face.apply([mean - delta, mean - delta, mean - delta])[1]) / (2 * delta)
        let frost = glassRim.styled(style).frost(tintAmount: TheseusConfiguration.GlassRim.frostAmount(spectrum: spectrum, style: style))
        let detail = max(slope, 0) * (1 - frost.cover) * (1 - 0.5 * frost.blend)
        return veil(producing: face.apply(back), over: back, minimumAlpha: 1 - detail)
    }

    static func veilColor(
        configuration: TheseusConfiguration,
        isDark: Bool,
        spectrum: CGFloat,
        backdropLuminance: CGFloat
    ) -> UIColor {
        veilColor(configuration: configuration, isDark: isDark, spectrum: spectrum, backdrop: .grey(backdropLuminance))
    }
}
