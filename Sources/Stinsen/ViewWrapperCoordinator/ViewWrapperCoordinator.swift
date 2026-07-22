import Foundation
import SwiftUI

/// The ViewWrapperCoordinator is used to represent a coordinator wrapped in a custom view
open class ViewWrapperCoordinator<T: Coordinatable, V: View>: Coordinatable {
    public func dismissChild<C: Coordinatable>(coordinator: C, action: (() -> Void)?) {
        guard let parent = self.parent else {
            assertionFailure("Can not dismiss a coordinator since no coordinator is presented.")
            return
        }
        
        parent.dismissChild(coordinator: self, action: action)
    }

    public var canDismissChild: Bool {
        self.parent?.canDismissChild ?? false
    }

    public weak var parent: ChildDismissable?
    public let child: T
    private let viewFactory: (any Coordinatable) -> (AnyView) -> V

    public func view() -> AnyView {
        AnyView(
            ViewWrapperCoordinatorView(coordinator: self, viewFactory(self))
        )
    }
    
    public init(_ childCoordinator: T, _ view: @escaping (AnyView) -> V) {
        self.child = childCoordinator
        self.viewFactory = { _ in { view($0) } }
        self.child.parent = self
    }
    
    public init(_ childCoordinator: T, _ view: @escaping (any Coordinatable) -> (AnyView) -> V) {
        self.child = childCoordinator
        self.viewFactory = view
        self.child.parent = self
    }
}

extension ViewWrapperCoordinator: ChildCoordinatorWrapping {
    var wrappedChildCoordinator: any Coordinatable { child }

    func wrapRootView(_ view: AnyView) -> AnyView {
        AnyView(viewFactory(self)(view))
    }
}
