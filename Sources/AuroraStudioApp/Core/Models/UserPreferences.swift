import Foundation

struct UserPreferences: Codable, Hashable {
    var visualIntensity: VisualIntensity
    var createExperienceMode: CreateExperienceMode
    var reduceMotionOverride: Bool?
    var reduceTransparencyOverride: Bool?

    init(
        visualIntensity: VisualIntensity = .balanced,
        createExperienceMode: CreateExperienceMode = .focusHero,
        reduceMotionOverride: Bool? = nil,
        reduceTransparencyOverride: Bool? = nil
    ) {
        self.visualIntensity = visualIntensity
        self.createExperienceMode = createExperienceMode
        self.reduceMotionOverride = reduceMotionOverride
        self.reduceTransparencyOverride = reduceTransparencyOverride
    }

    func shouldReduceMotion(systemValue: Bool) -> Bool {
        reduceMotionOverride ?? systemValue
    }

    func shouldReduceTransparency(systemValue: Bool) -> Bool {
        reduceTransparencyOverride ?? systemValue
    }
}
