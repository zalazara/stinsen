import XCTest
import SwiftUI
@testable import Stinsen

private final class ChildTestCoordinator: NavigationCoordinatable {
    let stack = Stinsen.NavigationStack<ChildTestCoordinator>(initial: \ChildTestCoordinator.start)

    @Root var start = makeStart
    @Root var alternate = makeAlternate
    @Route(.push) var pushed = makePushed
    @Route(.modal) var modal = makeModal

    @ViewBuilder func makeStart() -> some View { Text("child-root") }
    @ViewBuilder func makeAlternate() -> some View { Text("child-alternate") }
    @ViewBuilder func makePushed() -> some View { Text("child-pushed") }
    @ViewBuilder func makeModal() -> some View { Text("child-modal") }
}

private final class ParentTestCoordinator: NavigationCoordinatable {
    let stack = Stinsen.NavigationStack<ParentTestCoordinator>(initial: \ParentTestCoordinator.start)

    @Root var start = makeStart
    @Root var alternate = makeAlternate
    @Route(.push) var pushed = makePushed
    @Route(.push) var child = makeChild
    @Route(.modal) var modal = makeModal
    @Route(.modalNonDismissible) var lockedModal = makeModal
    @Route(.fullScreen) var cover = makeCover

    @ViewBuilder func makeStart() -> some View { Text("root") }
    @ViewBuilder func makeAlternate() -> some View { Text("alternate") }
    @ViewBuilder func makePushed() -> some View { Text("pushed") }
    func makeChild() -> ChildTestCoordinator { ChildTestCoordinator() }
    @ViewBuilder func makeModal() -> some View { Text("modal") }
    @ViewBuilder func makeCover() -> some View { Text("cover") }
}

final class PathAggregatorTests: XCTestCase {
    private var parent: ParentTestCoordinator!

    override func setUp() {
        super.setUp()
        parent = ParentTestCoordinator()
    }

    private func makeAggregator(startIndex: Int = 0, allowsPush: Bool = true) -> PathAggregator {
        PathAggregator(anchor: StackOwner(parent), startIndex: startIndex, allowsPush: allowsPush)
    }

    // MARK: Path derivation

    func testPushesProducePathElements() {
        let aggregator = makeAggregator()
        parent.route(to: \.pushed)
        parent.route(to: \.pushed)

        XCTAssertEqual(aggregator.path.count, 2)
        XCTAssertEqual(aggregator.path.map(\.index), [0, 1])
        XCTAssertNil(aggregator.terminalModal)
    }

    func testDeepLinkChainedInOneTransactionProducesFullPath() {
        parent.route(to: \.pushed).route(to: \.pushed).route(to: \.pushed)
        let aggregator = makeAggregator()

        XCTAssertEqual(aggregator.path.count, 3)
    }

    func testModalTerminatesPath() {
        let aggregator = makeAggregator()
        parent.route(to: \.pushed)
        parent.route(to: \.modal)
        parent.route(to: \.pushed)

        XCTAssertEqual(aggregator.path.count, 1)
        XCTAssertEqual(aggregator.terminalModal?.index, 1)
        XCTAssertEqual(aggregator.terminalModal?.type.isModal, true)

        // The push after the modal belongs to the modal's own container.
        let modalAggregator = makeAggregator(startIndex: 2)
        XCTAssertEqual(modalAggregator.path.map(\.index), [2])
        XCTAssertNil(modalAggregator.terminalModal)
    }

    func testFullScreenTerminatesPath() {
        let aggregator = makeAggregator()
        parent.route(to: \.cover)

        XCTAssertTrue(aggregator.path.isEmpty)
        XCTAssertEqual(aggregator.terminalModal?.type.isFullScreen, true)
    }

    func testPushedChildCoordinatorContributesToParentPath() {
        let aggregator = makeAggregator()
        let child = parent.route(to: \.child)
        child.route(to: \.pushed)

        XCTAssertEqual(aggregator.path.count, 2)
        XCTAssertEqual(aggregator.path[0].ownerID, ObjectIdentifier(parent))
        XCTAssertEqual(aggregator.path[1].ownerID, ObjectIdentifier(child))
    }

    func testChildModalTerminatesParentContainer() {
        let aggregator = makeAggregator()
        let child = parent.route(to: \.child)
        child.route(to: \.modal)

        XCTAssertEqual(aggregator.path.count, 1)
        XCTAssertEqual(aggregator.terminalModal?.index, 0)
        XCTAssertTrue(aggregator.terminalModal?.owner.coordinatorID == ObjectIdentifier(child))
    }

    // MARK: Bare (self-hosted) roots

    func testBareRootPresentsLeadingModal() {
        let aggregator = makeAggregator(allowsPush: false)
        parent.route(to: \.modal)

        XCTAssertTrue(aggregator.path.isEmpty)
        XCTAssertEqual(aggregator.terminalModal?.index, 0)
    }

    func testBareRootPushIsDeadEnd() {
        let aggregator = makeAggregator(allowsPush: false)
        parent.route(to: \.pushed)
        parent.route(to: \.modal)

        XCTAssertTrue(aggregator.path.isEmpty)
        XCTAssertNil(aggregator.terminalModal)
    }

    // MARK: Programmatic pops

    func testPopToRootClearsPathAndModal() {
        let aggregator = makeAggregator()
        parent.route(to: \.pushed)
        parent.route(to: \.modal)
        parent.popToRoot()

        XCTAssertTrue(aggregator.path.isEmpty)
        XCTAssertNil(aggregator.terminalModal)
        XCTAssertTrue(parent.stack.value.isEmpty)
    }

    func testFocusFirstTrimsPath() throws {
        let aggregator = makeAggregator()
        parent.route(to: \.pushed)
        parent.route(to: \.pushed)
        parent.route(to: \.pushed)
        try parent.focusFirst(\.pushed)

        XCTAssertEqual(aggregator.path.count, 1)
    }

    // MARK: UI-initiated pops (path binding write-back)

    func testUIPopTruncatesOwnerStack() {
        let aggregator = makeAggregator()
        parent.route(to: \.pushed)
        parent.route(to: \.pushed)

        aggregator.uiDidSetPath(Array(aggregator.path.prefix(1)))

        XCTAssertEqual(parent.stack.value.count, 1)
        XCTAssertEqual(aggregator.path.count, 1)
    }

    func testUIPopAcrossChildCoordinatorTruncatesBothStacks() {
        let aggregator = makeAggregator()
        let child = parent.route(to: \.child)
        child.route(to: \.pushed)

        aggregator.uiDidSetPath([])

        XCTAssertTrue(parent.stack.value.isEmpty)
        XCTAssertTrue(child.stack.value.isEmpty)
        XCTAssertTrue(aggregator.path.isEmpty)
    }

    func testUIPopToChildRootKeepsChildItemInParent() {
        let aggregator = makeAggregator()
        let child = parent.route(to: \.child)
        child.route(to: \.pushed)

        aggregator.uiDidSetPath(Array(aggregator.path.prefix(1)))

        XCTAssertEqual(parent.stack.value.count, 1)
        XCTAssertTrue(child.stack.value.isEmpty)
        XCTAssertEqual(aggregator.path.count, 1)
    }

    func testUIDismissedModalPopsIt() {
        let aggregator = makeAggregator()
        parent.route(to: \.pushed)
        parent.route(to: \.modal)

        aggregator.uiDismissedModal()

        XCTAssertEqual(parent.stack.value.count, 1)
        XCTAssertNil(aggregator.terminalModal)
        XCTAssertEqual(aggregator.path.count, 1)
    }

    // MARK: Dismissal actions

    func testDismissalActionFiresOnPop() {
        let aggregator = makeAggregator()
        let expectation = expectation(description: "onDismiss fired")
        parent.route(to: \.pushed, onDismiss: { expectation.fulfill() })
        _ = aggregator

        parent.popLast()

        wait(for: [expectation], timeout: 1)
    }

    func testDismissalActionDoesNotFireWhenCoveredByPush() {
        let aggregator = makeAggregator()
        let expectation = expectation(description: "onDismiss fired")
        expectation.isInverted = true
        parent.route(to: \.pushed, onDismiss: { expectation.fulfill() })
        _ = aggregator

        parent.route(to: \.pushed)

        wait(for: [expectation], timeout: 0.2)
    }

    func testModalDismissalActionFiresOnUIDismiss() {
        let aggregator = makeAggregator()
        let expectation = expectation(description: "onDismiss fired")
        parent.route(to: \.modal, onDismiss: { expectation.fulfill() })

        aggregator.uiDismissedModal()

        wait(for: [expectation], timeout: 1)
    }

    func testPopToRootFiresActionOnce() {
        let aggregator = makeAggregator()
        parent.route(to: \.pushed)
        parent.route(to: \.pushed)
        _ = aggregator

        var fired = 0
        let expectation = expectation(description: "action fired")
        parent.popToRoot {
            fired += 1
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(fired, 1)
    }

    // MARK: Root switching

    /// `root()` and `popToRoot()` are orthogonal: `root()` only swaps which
    /// view is the stack's base, pushed items stay in the path on top of it.
    func testRootSwitchKeepsPushedPath() {
        let aggregator = makeAggregator()
        parent.route(to: \.pushed)

        parent.root(\.alternate)

        XCTAssertEqual(parent.stack.value.count, 1)
        XCTAssertEqual(aggregator.path.count, 1)
        XCTAssertTrue(parent.isRoot(\.alternate))
    }

    func testPopToRootPlusRootSwitchLandsOnNewRoot() {
        let aggregator = makeAggregator()
        parent.route(to: \.pushed)
        parent.route(to: \.modal)

        parent.popToRoot()
        parent.root(\.alternate)

        XCTAssertTrue(parent.stack.value.isEmpty)
        XCTAssertTrue(aggregator.path.isEmpty)
        XCTAssertNil(aggregator.terminalModal)
        XCTAssertTrue(parent.isRoot(\.alternate))
    }

    func testPushedChildRootSwitchSwapsOnlyItsBase() {
        let aggregator = makeAggregator()
        let child = parent.route(to: \.child)
        child.route(to: \.pushed)
        XCTAssertEqual(aggregator.path.count, 2)

        child.popToRoot()
        child.root(\.alternate)

        // The child item itself stays pushed in the parent; its own pushes are
        // gone and its base view is now the alternate root.
        XCTAssertEqual(parent.stack.value.count, 1)
        XCTAssertTrue(child.stack.value.isEmpty)
        XCTAssertEqual(aggregator.path.count, 1)
        XCTAssertTrue(child.isRoot(\.alternate))
    }

    // MARK: Identity

    func testRepushingSameRouteYieldsDistinctPathElement() {
        let aggregator = makeAggregator()
        parent.route(to: \.pushed)
        let first = aggregator.path[0]
        parent.popLast()
        parent.route(to: \.pushed)
        let second = aggregator.path[0]

        XCTAssertNotEqual(first, second)
    }
}
