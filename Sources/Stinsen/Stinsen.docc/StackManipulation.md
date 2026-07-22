# Stack Manipulation

Rearrange the navigation stack at any position, like `UINavigationController.setViewControllers`.

## Overview

The SwiftUI `NavigationStack` path is derived from the coordinator's stack, so inserting or removing items at any position is presented in a single animated transaction. All functions are available both on ``NavigationCoordinatable`` and on ``NavigationRouter``.

Unlike UIKit, where identity is the view controller instance, in Stinsen identity is the route plus its input. If the same route appears more than once in the stack, disambiguate with the input, using `Equatable` conformance or a custom comparator.

### Fabricating a back destination

Insert a screen the user never actually visited, e.g. deep-linking straight to a detail screen while making back lead to the list it conceptually belongs to:

```swift
coordinator
    .popToRoot()
    .route(to: \.detail, productId) // stack: [detail]
coordinator.insertBelowTop(\.list)  // stack: [list, detail], detail stays visible
```

`insert(_:at:)` places a route at an arbitrary position instead:

```swift
coordinator.insert(\.list, at: 0)
```

Only `.push` routes can be inserted: a modal presentation mid-stack would move the modal boundary and dismiss everything above it.

### Removing an intermediate step

In an A → B → C flow, make back from C land on A:

```swift
try coordinator.removeFirst(\.stepB)

// With input disambiguation:
try coordinator.removeFirst(\.detail, 42)
try coordinator.removeFirst(\.detail, target) { $0.id == $1.id }
```

Removing an item fires its `onDismiss` action, if one was registered. Removing the topmost item is equivalent to a pop.

### Introspection

The read-only introspection functions mirror reading `UINavigationController.viewControllers`:

```swift
coordinator.stackCount                    // number of items in the stack
coordinator.contains(\.stepB)             // whether a route is in the stack
if let index = coordinator.firstIndex(of: \.detail, 42) {
    coordinator.remove(at: index)         // or insert(\.someRoute, at: index)
}
```
