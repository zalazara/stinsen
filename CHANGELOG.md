# Changelog

## 3.0.0

Stinsen's rendering core migrated from the deprecated `NavigationView` +
`NavigationLink(isActive:)` to `SwiftUI.NavigationStack(path:)`. The public
coordinator API is unchanged: `route(to:)`, `popTo`/`popToRoot`/`popLast`,
`focusFirst`, `root`/`isRoot`/`hasRoot`, `@Route`/`@Root`, `NavigationRouter`,
`RouterStore`/`@RouterObject`, `dismissCoordinator` and `onDismiss` closures all
work as before. Consuming apps only need to raise their deployment target.

### Breaking

- Minimum deployment targets are now **iOS 16.0, macOS 13.0, tvOS 16.0 and
  watchOS 9.0** (the `NavigationStack` baseline).
- On macOS, `.fullScreen` presentations degrade to a sheet
  (`fullScreenCover` does not exist on macOS).

### Behavior changes

- Deep links (chained `route(to:)` calls in one transaction) now animate as a
  single `NavigationStack` transition and are reliable at any depth.
- `onDismiss`/dismissal actions no longer misfire when a screen is merely
  covered by a further push; they fire exactly once, when the route is actually
  removed from the stack.
- Custom `ViewWrapperCoordinator` factories that hand-rolled a `NavigationView`
  no longer wire pushes; use `NavigationViewCoordinator` instead.
- Pushing a `NavigationViewCoordinator` is unsupported (SwiftUI does not allow
  a `NavigationStack` inside a pushed view) and asserts in debug builds.
  Present it as a modal instead. Similarly, `NavigationViewCoordinator`
  wrapping a `TabCoordinatable` no longer lets tab children push into the
  outer container: give each tab its own `NavigationViewCoordinator`.
- If a parent coordinator routes further after pushing a child coordinator
  that also pushes, the resulting order is now deterministic: the child's
  routes come first, then the parent's later routes.

### Internals

- `PresentationHelper`/`Presented` (per-level recursive `NavigationLink`
  machinery) were replaced by `PathAggregator` +
  `NavigationStackContainerView`: each navigation container derives its
  `NavigationStack` path from the coordinator stacks, and UI pops are written
  back to the coordinators, which remain the single source of truth.
- Added a unit test suite for the path derivation and pop write-back logic.
