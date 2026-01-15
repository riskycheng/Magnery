import SwiftUI

struct TabBarVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        let next = nextValue()
        // If any view in the hierarchy wants to hide (false), hide it.
        value = value && next
    }
}

extension View {
    func setTabBarVisibility(_ visible: Bool) -> some View {
        self.preference(key: TabBarVisibilityPreferenceKey.self, value: visible)
    }
}
