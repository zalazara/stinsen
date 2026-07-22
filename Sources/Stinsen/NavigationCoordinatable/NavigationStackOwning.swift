import Foundation
import Combine
import SwiftUI

/// Type-erased access to a `NavigationCoordinatable`'s stack. The path walk
/// crosses coordinators of different concrete types, and the
/// `NavigationCoordinatable` existential is unusable for that because of its
/// `Self` and associated-type requirements.
protocol NavigationStackOwning: AnyObject {
    /// Identity of the underlying coordinator (not of this wrapper).
    var coordinatorID: ObjectIdentifier { get }
    var stackItems: [NavigationStackItem] { get }
    /// The current `@Root` item's presentable.
    var rootChildPresentable: ViewPresentable { get }
    /// Emits after the stack or the root item has been mutated.
    var stackDidChange: AnyPublisher<Void, Never> { get }
    /// Truncates the stack so `index` is the topmost remaining item (-1 clears it).
    func popToIndex(_ index: Int)
    /// Reads and clears the dismissal action stored for the item with `id`.
    func takeDismissalAction(for id: UUID) -> (() -> Void)?
    /// The coordinator's root, including `customize()` and the level -1 router.
    func rootView() -> AnyView
    /// The view for the stack item at `index`, with its router injected.
    func destinationView(at index: Int) -> AnyView
}

final class StackOwner<T: NavigationCoordinatable>: NavigationStackOwning {
    let coordinator: T

    init(_ coordinator: T) {
        self.coordinator = coordinator
    }

    var coordinatorID: ObjectIdentifier {
        ObjectIdentifier(coordinator)
    }

    var stackItems: [NavigationStackItem] {
        coordinator.stack.value
    }

    var rootChildPresentable: ViewPresentable {
        ensureRoot()
        return coordinator.stack.root.item.child
    }

    var stackDidChange: AnyPublisher<Void, Never> {
        ensureRoot()
        return coordinator.stack.didChangeValue
            .merge(with: coordinator.stack.root.didChangeItem)
            .eraseToAnyPublisher()
    }

    private func ensureRoot() {
        if coordinator.stack.root == nil {
            coordinator.setupRoot()
        }
    }

    func popToIndex(_ index: Int) {
        coordinator.appear(index)
    }

    func takeDismissalAction(for id: UUID) -> (() -> Void)? {
        let action = coordinator.stack.dismissalAction[id]
        coordinator.stack.dismissalAction[id] = nil
        return action
    }

    func rootView() -> AnyView {
        AnyView(NavigationRootView(coordinator: coordinator))
    }

    func destinationView(at index: Int) -> AnyView {
        guard let item = coordinator.stack.value[safe: index], let view = item.presentable as? AnyView else {
            return AnyView(EmptyView())
        }

        let router: NavigationRouter<T> = NavigationRouter(
            id: index,
            itemID: item.id,
            coordinator: coordinator.routerStorable
        )

        RouterStore.shared.store(router: router)

        return AnyView(view.environmentObject(router))
    }
}

/// Creates a `StackOwner` from an existential by opening it (SE-0352).
func makeStackOwner(_ coordinator: any NavigationCoordinatable) -> NavigationStackOwning {
    func open<T: NavigationCoordinatable>(_ coordinator: T) -> NavigationStackOwning {
        StackOwner(coordinator)
    }
    return open(coordinator)
}

/// Marker to detect a pushed `NavigationViewCoordinator`, which is unsupported:
/// SwiftUI does not allow a `NavigationStack` inside a pushed view.
protocol NavigationViewCoordinatorMarker: AnyObject {}

/// A coordinator that wraps another coordinator plus a view transform
/// (`ViewWrapperCoordinator`). The path walk sees through it so the wrapped
/// coordinator's routes merge into the enclosing container, and the transform
/// is applied around the wrapped coordinator's root view.
protocol ChildCoordinatorWrapping {
    var wrappedChildCoordinator: any Coordinatable { get }
    func wrapRootView(_ view: AnyView) -> AnyView
}

/// Sees through `AnyCoordinator` and `ViewWrapperCoordinator` (but never
/// `NavigationViewCoordinator`, which is a container boundary), returning the
/// innermost presentable.
func unwrapCoordinator(_ presentable: ViewPresentable) -> ViewPresentable {
    var current = presentable
    while !(current is NavigationViewCoordinatorMarker) {
        if let typeErased = current as? AnyCoordinator {
            current = typeErased.wrappedCoordinator
        } else if let wrapper = current as? ChildCoordinatorWrapping {
            current = wrapper.wrappedChildCoordinator
        } else {
            break
        }
    }
    return current
}

/// The view for a presentable hosted by a container (a pushed child
/// coordinator's destination, or a coordinator used as `@Root`). A
/// `NavigationCoordinatable` renders only its root — its pushes are elements
/// of the enclosing container's path — with any wrapper transforms applied
/// around it. Everything else keeps its own `view()`.
func hostedRootView(_ presentable: ViewPresentable) -> AnyView {
    var transforms: [(AnyView) -> AnyView] = []
    var current = presentable

    while !(current is NavigationViewCoordinatorMarker) {
        if let typeErased = current as? AnyCoordinator {
            current = typeErased.wrappedCoordinator
        } else if let wrapper = current as? ChildCoordinatorWrapping {
            transforms.append(wrapper.wrapRootView(_:))
            current = wrapper.wrappedChildCoordinator
        } else {
            break
        }
    }

    guard let navigationChild = current as? any NavigationCoordinatable else {
        return presentable.view()
    }

    var view = makeStackOwner(navigationChild).rootView()
    for transform in transforms.reversed() {
        view = transform(view)
    }
    return view
}
