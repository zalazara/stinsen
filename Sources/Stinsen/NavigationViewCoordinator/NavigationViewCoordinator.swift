import Foundation
import SwiftUI

/// The NavigationViewCoordinator is used to represent a coordinator with a NavigationStack
public class NavigationViewCoordinator<T: Coordinatable>: ViewWrapperCoordinator<T, AnyView>, NavigationViewCoordinatorMarker {
    public init(_ childCoordinator: T) {
        super.init(childCoordinator) { view in
            if let navigationChild = childCoordinator as? any NavigationCoordinatable {
                let owner = makeStackOwner(navigationChild)
                return AnyView(
                    NavigationStackContainerView(
                        anchor: owner,
                        startIndex: 0,
                        rootContent: owner.rootView()
                    )
                )
            } else {
                return AnyView(
                    SwiftUI.NavigationStack {
                        view
                    }
                )
            }
        }
    }

    @available(*, unavailable)
    public override init(_ childCoordinator: T, _ view: @escaping (AnyView) -> AnyView) {
        fatalError("view cannot be customized")
    }

    @available(*, unavailable)
    public override init(_ childCoordinator: T, _ view: @escaping (any Coordinatable) -> (AnyView) -> AnyView) {
        fatalError("view cannot be customized")
    }
}
