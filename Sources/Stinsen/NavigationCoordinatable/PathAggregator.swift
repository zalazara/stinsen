import Foundation
import Combine
import SwiftUI

/// Owns the state of one navigation container (a `SwiftUI.NavigationStack` and
/// its terminal modal). The path is derived from the coordinator model by
/// walking `stack.value` from the anchor, recursing into pushed child
/// `NavigationCoordinatable`s and stopping at the first modal/fullScreen item.
/// The model stays the single source of truth: UI-initiated pops are written
/// back through the coordinators and the path recomputes idempotently.
@MainActor final class PathAggregator: ObservableObject {
    struct TerminalModal {
        let owner: NavigationStackOwning
        let index: Int
        let itemID: UUID
        let type: PresentationType
    }

    @Published private(set) var path: [StinsenPathElement] = []
    @Published private(set) var terminalModal: TerminalModal?

    private let anchor: NavigationStackOwning
    private let startIndex: Int
    /// `false` for a bare, self-hosted coordinator root: it can present its
    /// leading modal, but pushes are dead ends (there is no container above).
    private let allowsPush: Bool

    private var owners: [ObjectIdentifier: NavigationStackOwning] = [:]
    private var resolution: [UUID: (owner: NavigationStackOwning, index: Int)] = [:]
    private var cancellables: [ObjectIdentifier: AnyCancellable] = [:]
    private var isWritingBack = false

    init(anchor: NavigationStackOwning, startIndex: Int, allowsPush: Bool) {
        self.anchor = anchor
        self.startIndex = startIndex
        self.allowsPush = allowsPush
        recompute()
    }

    // MARK: Model -> UI

    private func recompute() {
        guard !isWritingBack else { return }

        var newPath: [StinsenPathElement] = []
        var newResolution: [UUID: (owner: NavigationStackOwning, index: Int)] = [:]
        var visited: [ObjectIdentifier: NavigationStackOwning] = [:]
        let newModal: TerminalModal?

        if allowsPush {
            newModal = walk(anchor, from: startIndex, into: &newPath, resolution: &newResolution, visited: &visited)
        } else {
            visited[anchor.coordinatorID] = anchor
            if let item = anchor.stackItems[safe: startIndex], !item.presentationType.isPush {
                newModal = TerminalModal(owner: anchor, index: startIndex, itemID: item.id, type: item.presentationType)
            } else {
                newModal = nil
            }
        }

        fireDismissalActions(newPath: newPath, newModal: newModal)

        resolution = newResolution
        resubscribe(to: visited)

        if newPath != path {
            path = newPath
        }
        if newModal?.itemID != terminalModal?.itemID {
            terminalModal = newModal
        }
    }

    private func walk(
        _ owner: NavigationStackOwning,
        from start: Int,
        into path: inout [StinsenPathElement],
        resolution: inout [UUID: (owner: NavigationStackOwning, index: Int)],
        visited: inout [ObjectIdentifier: NavigationStackOwning]
    ) -> TerminalModal? {
        visited[owner.coordinatorID] = owner

        // A coordinator used as `@Root` contributes its routes before the
        // owner's own pushed items, mirroring the pushed-child ordering.
        if start == 0,
           let rootChild = unwrapCoordinator(owner.rootChildPresentable) as? any NavigationCoordinatable {
            let childOwner = self.owner(for: rootChild)
            if visited[childOwner.coordinatorID] == nil,
               let modal = walk(childOwner, from: 0, into: &path, resolution: &resolution, visited: &visited) {
                return modal
            }
        }

        let items = owner.stackItems
        var index = start

        while index < items.count {
            let item = items[index]

            guard item.presentationType.isPush else {
                return TerminalModal(owner: owner, index: index, itemID: item.id, type: item.presentationType)
            }

            path.append(StinsenPathElement(itemID: item.id, ownerID: owner.coordinatorID, index: index))
            resolution[item.id] = (owner, index)

            // A pushed child coordinator contributes its own pushes to this
            // container's path; it never creates a nested container.
            if let child = unwrapCoordinator(item.presentable) as? any NavigationCoordinatable {
                let childOwner = self.owner(for: child)
                if let modal = walk(childOwner, from: 0, into: &path, resolution: &resolution, visited: &visited) {
                    return modal
                }
            }

            index += 1
        }

        return nil
    }

    private func owner(for coordinator: any NavigationCoordinatable) -> NavigationStackOwning {
        let key = ObjectIdentifier(coordinator)
        if let existing = owners[key] {
            return existing
        }
        let owner = makeStackOwner(coordinator)
        owners[key] = owner
        return owner
    }

    private func resubscribe(to visited: [ObjectIdentifier: NavigationStackOwning]) {
        for key in cancellables.keys where visited[key] == nil {
            cancellables[key] = nil
            owners[key] = nil
        }

        for (key, owner) in visited {
            owners[key] = owner
            if cancellables[key] == nil {
                // Stack mutations only happen on the main actor, so the
                // subjects always fire there.
                cancellables[key] = owner.stackDidChange.sink { [weak self] in
                    MainActor.assumeIsolated {
                        self?.recompute()
                    }
                }
            }
        }
    }

    /// Fires the dismissal action of every element that was removed from the
    /// model, deepest first, mirroring the old `onDisappear`/`onDismiss` hooks.
    /// Elements that merely left the path while still present in their owner's
    /// stack (e.g. hidden behind a new modal boundary) do not fire.
    private func fireDismissalActions(newPath: [StinsenPathElement], newModal: TerminalModal?) {
        var actions: [() -> Void] = []

        if let oldModal = terminalModal, oldModal.itemID != newModal?.itemID {
            let stillPresent = oldModal.owner.stackItems.contains { $0.id == oldModal.itemID }
            if !stillPresent, let action = oldModal.owner.takeDismissalAction(for: oldModal.itemID) {
                actions.append(action)
            }
        }

        let newIDs = Set(newPath.map(\.itemID))
        for element in path.reversed() where !newIDs.contains(element.itemID) {
            guard let owner = owners[element.ownerID] else { continue }
            let stillPresent = owner.stackItems.contains { $0.id == element.itemID }
            if !stillPresent, let action = owner.takeDismissalAction(for: element.itemID) {
                actions.append(action)
            }
        }

        guard !actions.isEmpty else { return }

        // Fired outside the current model mutation, so an action that routes
        // again does not re-enter the ongoing recompute.
        Task { @MainActor in
            for action in actions {
                action()
            }
        }
    }

    // MARK: UI -> Model

    /// Called by the `NavigationStack` path binding setter when the UI pops
    /// (back button, swipe). Truncates every affected coordinator's stack.
    func uiDidSetPath(_ newPath: [StinsenPathElement]) {
        guard newPath != path, newPath.count < path.count else { return }

        let removed = path.suffix(from: newPath.count)

        // Deepest first; one pop per owner, to the lowest removed index.
        var pops: [(owner: NavigationStackOwning, index: Int, itemID: UUID)] = []
        for element in removed.reversed() {
            guard let owner = owners[element.ownerID] else { continue }
            if let existing = pops.firstIndex(where: { $0.owner.coordinatorID == element.ownerID }) {
                if element.index < pops[existing].index {
                    pops[existing] = (owner, element.index, element.itemID)
                }
            } else {
                pops.append((owner, element.index, element.itemID))
            }
        }

        isWritingBack = true
        for pop in pops {
            if pop.owner.stackItems[safe: pop.index]?.id == pop.itemID {
                pop.owner.popToIndex(pop.index - 1)
            }
        }
        isWritingBack = false

        recompute()
    }

    /// Called when the UI dismisses the terminal modal (sheet drag or the
    /// `isPresented` binding turning false).
    func uiDismissedModal() {
        guard let modal = terminalModal else { return }
        guard modal.owner.stackItems[safe: modal.index]?.id == modal.itemID else { return }
        modal.owner.popToIndex(modal.index - 1)
    }

    // MARK: Destinations

    func destination(for element: StinsenPathElement) -> AnyView {
        guard let entry = resolution[element.itemID],
              let item = entry.owner.stackItems[safe: entry.index],
              item.id == element.itemID else {
            return AnyView(EmptyView())
        }

        if item.presentable is AnyView {
            return entry.owner.destinationView(at: entry.index)
        }

        if unwrapCoordinator(item.presentable) is any NavigationCoordinatable {
            // Only the child's root: its pushes are already elements of this
            // path. Wrapper transforms are applied around it.
            return hostedRootView(item.presentable)
        }

        if unwrapCoordinator(item.presentable) is NavigationViewCoordinatorMarker {
            assertionFailure(
                "Pushing a NavigationViewCoordinator is not supported: SwiftUI does not allow "
                + "a NavigationStack inside a pushed view. Present it as a modal instead."
            )
        }

        return item.presentable.view()
    }
}
