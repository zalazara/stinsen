import Foundation
import SwiftUI

/// One navigation container: a `SwiftUI.NavigationStack` whose path is derived
/// from the coordinator model by a `PathAggregator`, plus the container's
/// terminal modal presented via sheet/fullScreenCover.
struct NavigationStackContainerView: View {
    @StateObject private var aggregator: PathAggregator
    private let rootContent: AnyView

    init(anchor: NavigationStackOwning, startIndex: Int, rootContent: AnyView) {
        self._aggregator = StateObject(
            wrappedValue: PathAggregator(anchor: anchor, startIndex: startIndex, allowsPush: true)
        )
        self.rootContent = rootContent
    }

    var body: some View {
        SwiftUI.NavigationStack(
            path: Binding(
                get: { aggregator.path },
                set: { aggregator.uiDidSetPath($0) }
            )
        ) {
            rootContent
                .navigationDestination(for: StinsenPathElement.self) { element in
                    aggregator.destination(for: element)
                }
        }
        .stinsenModalHost(aggregator)
    }
}

extension View {
    /// Presents the aggregator's terminal modal via sheet or fullScreenCover.
    /// macOS has no `fullScreenCover`, so there `.fullScreen` degrades to a sheet.
    func stinsenModalHost(_ aggregator: PathAggregator) -> some View {
        #if os(macOS)
        return self
            .sheet(
                isPresented: Binding(
                    get: { aggregator.terminalModal != nil },
                    set: { if !$0 { aggregator.uiDismissedModal() } }
                )
            ) {
                StinsenModalChildView(aggregator: aggregator)
            }
        #else
        return self
            .sheet(
                isPresented: Binding(
                    get: { aggregator.terminalModal?.type.isModal == true },
                    set: { if !$0 { aggregator.uiDismissedModal() } }
                )
            ) {
                StinsenModalChildView(aggregator: aggregator)
            }
            .fullScreenCover(
                isPresented: Binding(
                    get: { aggregator.terminalModal?.type.isFullScreen == true },
                    set: { if !$0 { aggregator.uiDismissedModal() } }
                )
            ) {
                StinsenModalChildView(aggregator: aggregator)
            }
        #endif
    }
}

/// Content of a presented modal. A plain view gets its own navigation
/// container (so routes pushed after the modal land inside it), with the
/// navigation bar hidden for parity with the old `NavigationView` wrapping.
/// A coordinator is presented bare and brings its own container if it is a
/// `NavigationViewCoordinator`.
struct StinsenModalChildView: View {
    @ObservedObject var aggregator: PathAggregator

    var body: some View {
        if let modal = aggregator.terminalModal {
            modalContent(modal)
                .id(modal.itemID)
                .interactiveDismissDisabled(!modal.type.isModalDismissible)
        }
    }

    @ViewBuilder
    private func modalContent(_ modal: PathAggregator.TerminalModal) -> some View {
        if let item = modal.owner.stackItems[safe: modal.index], item.id == modal.itemID {
            if item.presentable is AnyView {
                NavigationStackContainerView(
                    anchor: modal.owner,
                    startIndex: modal.index + 1,
                    rootContent: modalRootContent(modal)
                )
            } else {
                item.presentable.view()
            }
        }
    }

    /// The modal's own view as the root of its container. The navigation bar is
    /// hidden for parity with the old `NavigationView` wrapping; macOS never
    /// hid it (and has no `.navigationBar` toolbar placement).
    private func modalRootContent(_ modal: PathAggregator.TerminalModal) -> AnyView {
        #if os(macOS)
        return modal.owner.destinationView(at: modal.index)
        #else
        return AnyView(
            modal.owner.destinationView(at: modal.index)
                .toolbar(.hidden, for: .navigationBar)
        )
        #endif
    }
}
