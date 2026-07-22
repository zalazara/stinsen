import Foundation
import SwiftUI

/// The presentation root returned by `NavigationCoordinatable.view()`. It does
/// not create a navigation container: pushes only work when hosted inside a
/// `NavigationViewCoordinator` (or as a pushed/modal child of one), but a bare
/// coordinator can still present its leading modal.
struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {
    var coordinator: T
    @StateObject private var aggregator: PathAggregator

    var body: some View {
        NavigationRootView(coordinator: coordinator)
            .stinsenModalHost(aggregator)
    }

    init(coordinator: T) {
        self.coordinator = coordinator
        self._aggregator = StateObject(
            wrappedValue: PathAggregator(anchor: StackOwner(coordinator), startIndex: 0, allowsPush: false)
        )
    }
}
