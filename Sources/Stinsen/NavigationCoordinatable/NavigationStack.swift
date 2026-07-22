import Foundation
import Combine
import SwiftUI

struct NavigationRootItem {
    let keyPath: Int
    let input: Any?
    let child: ViewPresentable
}

/// Wrapper around childCoordinators
/// Used so that you don't need to write @Published
public class NavigationRoot: ObservableObject {
    /// Emits after `item` has been mutated, unlike `$item` which emits on willSet.
    let didChangeItem = PassthroughSubject<Void, Never>()

    @Published var item: NavigationRootItem {
        didSet {
            didChangeItem.send()
        }
    }

    init(item: NavigationRootItem) {
        self.item = item
    }
}

/// Represents a stack of routes
public class NavigationStack<T: NavigationCoordinatable> {
    /// Dismissal actions keyed by the id of the item whose removal fires them,
    /// so they stay attached to the right item across stack mutations.
    var dismissalAction: [UUID: () -> Void] = [:]

    weak var parent: ChildDismissable?
    var poppedTo = PassthroughSubject<Int, Never>()
    let initial: PartialKeyPath<T>
    let initialInput: Any?
    var root: NavigationRoot!

    /// Emits after `value` has been mutated, unlike `$value` which emits on willSet.
    let didChangeValue = PassthroughSubject<Void, Never>()

    @Published var value: [NavigationStackItem] {
        didSet {
            didChangeValue.send()
        }
    }
    
    public init(initial: PartialKeyPath<T>, _ initialInput: Any? = nil) {
        self.value = []
        self.initial = initial
        self.initialInput = initialInput
        self.root = nil
    }
}

/// Convenience checks against the navigation stack's contents
public extension NavigationStack {
    /**
        The Hash of the route at the top of the stack
        - Returns: the hash of the route at the top of the stack or -1
     */
    var currentRoute: Int {
        return value.last?.keyPath ?? -1
    }

    /**
    Checks if a particular KeyPath is in a stack
     - Parameter keyPathHash:The hash of the keyPath
     - Returns: Boolean indiacting whether the route is in the stack
     */
    func isInStack(_ keyPathHash: Int) -> Bool {
        return value.contains { $0.keyPath == keyPathHash }
    }

    /**
    Checks if a parent coordinator
     - Returns: Boolean indiacting whether the coordinator has a parent
     */
    func hasParent() -> Bool {
        return self.parent != nil
    }
}

struct NavigationStackItem {
    /// Unique identity for this entry, so that popping and re-routing to the
    /// same route yields a distinct `NavigationStack` path element.
    let id: UUID = UUID()
    let presentationType: PresentationType
    let presentable: ViewPresentable
    let keyPath: Int
    let input: Any?
}
