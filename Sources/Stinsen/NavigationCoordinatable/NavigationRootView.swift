import Foundation
import SwiftUI

/// Renders a `NavigationCoordinatable`'s root: the current `NavigationRoot`
/// item wrapped in `customize()`, with the level -1 router injected. Used both
/// as the root content of a navigation container and as the destination for a
/// pushed child coordinator.
struct NavigationRootView<T: NavigationCoordinatable>: View {
    var coordinator: T
    private let router: NavigationRouter<T>
    @ObservedObject var root: NavigationRoot

    var body: some View {
        // A coordinator used as `@Root` renders only its root view — its
        // routes are elements of the enclosing container's path.
        self.coordinator.customize(hostedRootView(root.item.child))
            .environmentObject(router)
    }

    init(coordinator: T) {
        self.coordinator = coordinator

        self.router = NavigationRouter(
            id: -1,
            coordinator: coordinator.routerStorable
        )

        if coordinator.stack.root == nil {
            coordinator.setupRoot()
        }

        self.root = coordinator.stack.root

        RouterStore.shared.store(router: router)
    }
}
