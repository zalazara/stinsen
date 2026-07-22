# ``Stinsen``

Simple, powerful and elegant implementation of the Coordinator pattern in SwiftUI, built on `NavigationStack`.

## Overview

Stinsen moves navigation out of the view layer and into coordinators: plain observable classes that declare their routes as keypaths and own a navigation stack. Views stay decoupled — they ask their router to navigate, and the coordinator decides what that means.

Define a coordinator by declaring its routes:

```swift
final class HomeCoordinator: NavigationCoordinatable {
    let stack = NavigationStack(initial: \HomeCoordinator.start)

    @Root var start = makeStart
    @Route(.push) var detail = makeDetail
    @Route(.modal) var settings = makeSettings

    @ViewBuilder func makeStart() -> some View { HomeScreen() }
    @ViewBuilder func makeDetail(id: Int) -> some View { DetailScreen(id: id) }
    func makeSettings() -> SettingsCoordinator { SettingsCoordinator() }
}
```

Navigate from the coordinator or from a view through its router:

```swift
coordinator.route(to: \.detail, 42)

// In a view:
@EnvironmentObject var router: HomeCoordinator.Router
router.route(to: \.detail, 42)
```

The whole coordinator layer is isolated to the main actor, matching SwiftUI's own `View` isolation.

## Topics

### Essentials

- ``Coordinatable``
- ``NavigationCoordinatable``
- ``TabCoordinatable``

### Defining routes

- ``NavigationRoute``
- ``PresentationType``
- ``Transition``
- ``RouteType``
- ``Presentation``
- ``RootSwitch``

### The navigation stack

- ``NavigationStack``
- ``NavigationRoot``
- <doc:StackManipulation>
- ``FocusError``

### Routers

- ``Routable``
- ``NavigationRouter``
- ``TabRouter``
- ``RouterStore``
- ``RouterObject``

### Wrapping coordinators

- ``NavigationViewCoordinator``
- ``ViewWrapperCoordinator``
- ``AnyCoordinator``

### Supporting types

- ``ViewPresentable``
- ``ChildDismissable``
- ``StringIdentifiable``
