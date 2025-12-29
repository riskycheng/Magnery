import SwiftUI

struct TabBarVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        let next = nextValue()
        // If any view in the hierarchy wants to hide the tab bar, we hide it.
        if !next {
            value = false
        } else {
            // If the next value is true, we only keep it if the current value wasn't already false.
            // This ensures that a child's 'false' isn't overridden by a parent's 'true'.
        }
    }
}

extension View {
    func setTabBarVisibility(_ visible: Bool) -> some View {
        self.preference(key: TabBarVisibilityPreferenceKey.self, value: visible)
    }
}
