import Foundation
import SwiftUI

/// `UINavigationController`-style arbitrary stack manipulation. The SwiftUI
/// path is derived from `stack.value`, so inserting or removing items at any
/// position recomputes the presented path in a single transaction, analogous
/// to `setViewControllers(_:animated:)`.
public extension NavigationCoordinatable {
    /**
     Inserts a view into the navigation stack at the given position without
     navigating. The visible view only changes when inserting at the top.

     Use this to fabricate a back destination that was never actually visited,
     e.g. deep-linking straight to a detail screen while making back lead to
     the list it conceptually belongs to.

     Only `.push` routes can be inserted: a modal presentation mid-stack would
     move the modal boundary and dismiss everything above it.

     - Parameter route: The route to insert.
     - Parameter input: The parameters that are used to create the view.
     - Parameter index: The position in the stack (0 is the first pushed item;
       `stack.value.count` appends like `route(to:)`).
     */
    @discardableResult func insert<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        at index: Int
    ) -> Self {
        insertItem(route, input: input, at: index)
        return self
    }

    /**
     Inserts a view into the navigation stack at the given position without
     navigating. The visible view only changes when inserting at the top.

     - Parameter route: The route to insert.
     - Parameter index: The position in the stack (0 is the first pushed item).
     */
    @discardableResult func insert<Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>,
        at index: Int
    ) -> Self {
        insertItem(route, input: (), at: index)
        return self
    }

    /**
     Inserts a coordinator into the navigation stack at the given position
     without navigating. The visible view only changes when inserting at the top.

     - Parameter route: The route to insert.
     - Parameter input: The parameters that are used to create the coordinator.
     - Parameter index: The position in the stack (0 is the first pushed item).
     */
    @discardableResult func insert<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        at index: Int
    ) -> Output {
        insertItem(route, input: input, at: index)
    }

    /**
     Inserts a coordinator into the navigation stack at the given position
     without navigating. The visible view only changes when inserting at the top.

     - Parameter route: The route to insert.
     - Parameter index: The position in the stack (0 is the first pushed item).
     */
    @discardableResult func insert<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>,
        at index: Int
    ) -> Output {
        insertItem(route, input: (), at: index)
    }

    /**
     Removes the item at the given position from the navigation stack. If the
     removed item is not the topmost one, the visible view does not change and
     back navigation skips it. Removing the topmost item is equivalent to a pop.

     The removed item's `onDismiss` action, if registered, fires.

     - Parameter index: The position in the stack (0 is the first pushed item).
     */
    @discardableResult func remove(at index: Int) -> Self {
        precondition(
            stack.value.indices.contains(index),
            "remove(at:) index \(index) is out of bounds (stack has \(stack.value.count) items)."
        )
        stack.value.remove(at: index)
        return self
    }

    /**
     Removes the first item in the stack that matches the route, so that back
     navigation skips it (the A → B → C flow where back from C should land on A).

     - Parameter route: The route to remove.

     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func removeFirst<Input, Output: ViewPresentable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>
    ) throws -> Self {
        try _removeFirst(route, nil)
    }

    /**
     Removes the first item in the stack that matches the route and input, so
     that back navigation skips it. Since this function assumes input is
     Equatable, it will use the `==` function to determine equality.

     - Parameter route: The route to remove.
     - Parameter input: The input that will be considered.

     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func removeFirst<Input: Equatable, Output: ViewPresentable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) throws -> Self {
        try _removeFirst(route, (value: input, comparator: { $0 == $1 }))
    }

    /**
     Removes the first item in the stack that matches the route and input, so
     that back navigation skips it.

     - Parameter route: The route to remove.
     - Parameter input: The input that will be considered.
     - Parameter comparator: The function to use to determine if the inputs are equal.

     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func removeFirst<Input, Output: ViewPresentable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) throws -> Self {
        try _removeFirst(route, (value: input, comparator: comparator))
    }

    /**
     Inserts a view directly below the topmost item, fabricating the screen the
     user will land on when navigating back. The visible view does not change.

     - Parameter route: The route to insert.
     */
    @discardableResult func insertBelowTop<Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Self {
        precondition(!stack.value.isEmpty, "insertBelowTop requires at least one item in the stack.")
        return insert(route, at: stack.value.count - 1)
    }

    /**
     Inserts a view directly below the topmost item, fabricating the screen the
     user will land on when navigating back. The visible view does not change.

     - Parameter route: The route to insert.
     - Parameter input: The parameters that are used to create the view.
     */
    @discardableResult func insertBelowTop<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Self {
        precondition(!stack.value.isEmpty, "insertBelowTop requires at least one item in the stack.")
        return insert(route, input, at: stack.value.count - 1)
    }

    /**
     Inserts a coordinator directly below the topmost item, fabricating the
     screen the user will land on when navigating back. The visible view does
     not change.

     - Parameter route: The route to insert.
     */
    @discardableResult func insertBelowTop<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Output {
        precondition(!stack.value.isEmpty, "insertBelowTop requires at least one item in the stack.")
        return insert(route, at: stack.value.count - 1)
    }

    /**
     Inserts a coordinator directly below the topmost item, fabricating the
     screen the user will land on when navigating back. The visible view does
     not change.

     - Parameter route: The route to insert.
     - Parameter input: The parameters that are used to create the coordinator.
     */
    @discardableResult func insertBelowTop<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Output {
        precondition(!stack.value.isEmpty, "insertBelowTop requires at least one item in the stack.")
        return insert(route, input, at: stack.value.count - 1)
    }

    @discardableResult private func insertItem<Input, Output: ViewPresentable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        input: Input,
        at index: Int
    ) -> Output {
        let transition = self[keyPath: route]
        precondition(
            transition.type.type.isPush,
            "insert(_:at:) only supports .push routes; a modal mid-stack would move the modal boundary."
        )
        precondition(
            index >= 0 && index <= stack.value.count,
            "insert(_:at:) index \(index) is out of bounds (stack has \(stack.value.count) items)."
        )

        let output = transition.closure(self)(input)

        stack.value.insert(
            NavigationStackItem(
                presentationType: transition.type.type,
                presentable: output,
                keyPath: route.hashValue,
                input: Input.self == Void.self ? nil : input
            ),
            at: index
        )

        if let coordinator = output as? any Coordinatable {
            coordinator.parent = self
        }

        return output
    }

    private func _removeFirst<Input, Output: ViewPresentable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: (value: Input, comparator: (Input, Input) -> Bool)?
    ) throws -> Self {
        guard let index = _firstIndex(route, input) else {
            throw FocusError.routeNotFound
        }

        stack.value.remove(at: index)
        return self
    }

    private func _firstIndex<Input, Output: ViewPresentable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: (value: Input, comparator: (Input, Input) -> Bool)?
    ) -> Int? {
        stack.value.firstIndex { item in
            guard item.keyPath == route.hashValue else {
                return false
            }

            guard let input = input else {
                return true
            }

            guard let compareTo = item.input else {
                return false
            }

            return input.comparator(compareTo as! Input, input.value)
        }
    }
}

/// Read-only introspection of the navigation stack, the counterpart of reading
/// `UINavigationController.viewControllers`. Identity is route + input, not
/// view instances: use these to decide positions for `insert(_:at:)` and
/// `remove(at:)`.
public extension NavigationCoordinatable {
    /// The number of items currently in the navigation stack, excluding the
    /// root. An empty stack means the root view is visible.
    var stackCount: Int {
        stack.value.count
    }

    /**
     Whether the stack contains at least one item for the route.

     - Parameter route: The route to look for.
     */
    func contains<Input, Output: ViewPresentable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>
    ) -> Bool {
        _firstIndex(route, nil) != nil
    }

    /**
     Whether the stack contains at least one item for the route and input.
     Since this function assumes input is Equatable, it will use the `==`
     function to determine equality.

     - Parameter route: The route to look for.
     - Parameter input: The input that will be considered.
     */
    func contains<Input: Equatable, Output: ViewPresentable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Bool {
        _firstIndex(route, (value: input, comparator: { $0 == $1 })) != nil
    }

    /**
     Whether the stack contains at least one item for the route and input.

     - Parameter route: The route to look for.
     - Parameter input: The input that will be considered.
     - Parameter comparator: The function to use to determine if the inputs are equal.
     */
    func contains<Input, Output: ViewPresentable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Bool {
        _firstIndex(route, (value: input, comparator: comparator)) != nil
    }

    /**
     The position of the first item matching the route, usable with
     `remove(at:)` and `insert(_:at:)`.

     - Parameter route: The route to look for.
     - Returns: The index of the first match, or `nil` if the route is not in the stack.
     */
    func firstIndex<Input, Output: ViewPresentable>(
        of route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>
    ) -> Int? {
        _firstIndex(route, nil)
    }

    /**
     The position of the first item matching the route and input, usable with
     `remove(at:)` and `insert(_:at:)`. Since this function assumes input is
     Equatable, it will use the `==` function to determine equality.

     - Parameter route: The route to look for.
     - Parameter input: The input that will be considered.
     - Returns: The index of the first match, or `nil` if the route is not in the stack.
     */
    func firstIndex<Input: Equatable, Output: ViewPresentable>(
        of route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Int? {
        _firstIndex(route, (value: input, comparator: { $0 == $1 }))
    }

    /**
     The position of the first item matching the route and input, usable with
     `remove(at:)` and `insert(_:at:)`.

     - Parameter route: The route to look for.
     - Parameter input: The input that will be considered.
     - Parameter comparator: The function to use to determine if the inputs are equal.
     - Returns: The index of the first match, or `nil` if the route is not in the stack.
     */
    func firstIndex<Input, Output: ViewPresentable>(
        of route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Int? {
        _firstIndex(route, (value: input, comparator: comparator))
    }
}
