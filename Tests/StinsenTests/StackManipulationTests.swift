import XCTest
import SwiftUI
@testable import Stinsen

private final class StackChildCoordinator: NavigationCoordinatable {
    let stack = Stinsen.NavigationStack<StackChildCoordinator>(initial: \StackChildCoordinator.start)

    @Root var start = makeStart

    @ViewBuilder func makeStart() -> some View { Text("child-root") }
}

private final class StackTestCoordinator: NavigationCoordinatable {
    let stack = Stinsen.NavigationStack<StackTestCoordinator>(initial: \StackTestCoordinator.start)

    @Root var start = makeStart
    @Route(.push) var stepA = makeStepA
    @Route(.push) var stepB = makeStepB
    @Route(.push) var stepC = makeStepC
    @Route(.push) var detail = makeDetail
    @Route(.push) var child = makeChild

    @ViewBuilder func makeStart() -> some View { Text("root") }
    @ViewBuilder func makeStepA() -> some View { Text("A") }
    @ViewBuilder func makeStepB() -> some View { Text("B") }
    @ViewBuilder func makeStepC() -> some View { Text("C") }
    @ViewBuilder func makeDetail(number: Int) -> some View { Text("detail-\(number)") }
    func makeChild() -> StackChildCoordinator { StackChildCoordinator() }
}

final class StackManipulationTests: XCTestCase {
    private var coordinator: StackTestCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = StackTestCoordinator()
    }

    private func makeAggregator() -> PathAggregator {
        PathAggregator(anchor: StackOwner(coordinator), startIndex: 0, allowsPush: true)
    }

    private func keyPathHashes() -> [Int] {
        coordinator.stack.value.map(\.keyPath)
    }

    // MARK: insert

    func testInsertBelowTopKeepsVisibleTop() {
        let aggregator = makeAggregator()
        coordinator.route(to: \.stepA).route(to: \.stepC)
        let topID = aggregator.path.last?.itemID

        coordinator.insert(\.stepB, at: 1)

        XCTAssertEqual(coordinator.stack.value.count, 3)
        XCTAssertEqual(aggregator.path.count, 3)
        XCTAssertEqual(aggregator.path.last?.itemID, topID)
        XCTAssertEqual(keyPathHashes(), [
            (\StackTestCoordinator.stepA).hashValue,
            (\StackTestCoordinator.stepB).hashValue,
            (\StackTestCoordinator.stepC).hashValue,
        ])
    }

    func testInsertThenPopLandsOnInsertedView() {
        let aggregator = makeAggregator()
        coordinator.route(to: \.stepC)

        coordinator.insert(\.stepB, at: 0)
        coordinator.popLast()

        XCTAssertEqual(aggregator.path.count, 1)
        XCTAssertEqual(keyPathHashes(), [(\StackTestCoordinator.stepB).hashValue])
    }

    func testInsertWithInputStoresInput() {
        coordinator.route(to: \.stepC)

        coordinator.insert(\.detail, 42, at: 0)

        XCTAssertEqual(coordinator.stack.value[0].input as? Int, 42)
    }

    func testInsertAtEndBehavesLikeRoute() {
        let aggregator = makeAggregator()
        coordinator.route(to: \.stepA)

        coordinator.insert(\.stepB, at: 1)

        XCTAssertEqual(aggregator.path.count, 2)
        XCTAssertEqual(coordinator.stack.value.last?.keyPath, (\StackTestCoordinator.stepB).hashValue)
    }

    func testInsertCoordinatorSetsParent() {
        coordinator.route(to: \.stepC)

        let child = coordinator.insert(\.child, at: 0)

        XCTAssertIdentical(child.parent, coordinator)
        XCTAssertEqual(coordinator.stack.value.count, 2)
    }

    // MARK: remove

    func testRemoveMiddleItemKeepsVisibleTop() {
        let aggregator = makeAggregator()
        coordinator.route(to: \.stepA).route(to: \.stepB).route(to: \.stepC)
        let topID = aggregator.path.last?.itemID

        coordinator.remove(at: 1)

        XCTAssertEqual(aggregator.path.count, 2)
        XCTAssertEqual(aggregator.path.last?.itemID, topID)
        XCTAssertEqual(keyPathHashes(), [
            (\StackTestCoordinator.stepA).hashValue,
            (\StackTestCoordinator.stepC).hashValue,
        ])
    }

    func testRemoveTopBehavesLikePop() {
        let aggregator = makeAggregator()
        coordinator.route(to: \.stepA).route(to: \.stepB)

        coordinator.remove(at: 1)

        XCTAssertEqual(aggregator.path.count, 1)
        XCTAssertEqual(keyPathHashes(), [(\StackTestCoordinator.stepA).hashValue])
    }

    func testRemoveFirstSkipsIntermediateStepOnBack() throws {
        let aggregator = makeAggregator()
        coordinator.route(to: \.stepA).route(to: \.stepB).route(to: \.stepC)

        try coordinator.removeFirst(\.stepB)

        XCTAssertEqual(keyPathHashes(), [
            (\StackTestCoordinator.stepA).hashValue,
            (\StackTestCoordinator.stepC).hashValue,
        ])

        // Back from C now lands on A.
        aggregator.uiDidSetPath(Array(aggregator.path.prefix(1)))
        XCTAssertEqual(keyPathHashes(), [(\StackTestCoordinator.stepA).hashValue])
    }

    func testRemoveFirstThrowsWhenRouteNotFound() {
        coordinator.route(to: \.stepA)

        XCTAssertThrowsError(try coordinator.removeFirst(\.stepB)) { error in
            guard case FocusError.routeNotFound = error else {
                return XCTFail("Expected FocusError.routeNotFound, got \(error)")
            }
        }
    }

    func testRemoveFirstWithInputRemovesMatchingItemOnly() throws {
        coordinator.route(to: \.detail, 1)
        coordinator.route(to: \.detail, 2)

        try coordinator.removeFirst(\.detail, 1)

        XCTAssertEqual(coordinator.stack.value.count, 1)
        XCTAssertEqual(coordinator.stack.value[0].input as? Int, 2)
    }

    // MARK: insertBelowTop

    func testInsertBelowTopFabricatesBackDestination() {
        let aggregator = makeAggregator()
        coordinator.route(to: \.stepC)
        let topID = aggregator.path.last?.itemID

        coordinator.insertBelowTop(\.stepA)

        XCTAssertEqual(aggregator.path.last?.itemID, topID)
        XCTAssertEqual(keyPathHashes(), [
            (\StackTestCoordinator.stepA).hashValue,
            (\StackTestCoordinator.stepC).hashValue,
        ])
    }

    func testInsertBelowTopWithInput() {
        coordinator.route(to: \.stepC)

        coordinator.insertBelowTop(\.detail, 7)

        XCTAssertEqual(coordinator.stack.value[0].input as? Int, 7)
        XCTAssertEqual(coordinator.stack.value.last?.keyPath, (\StackTestCoordinator.stepC).hashValue)
    }

    // MARK: Introspection

    func testStackCountReflectsMutations() {
        XCTAssertEqual(coordinator.stackCount, 0)

        coordinator.route(to: \.stepA).route(to: \.stepB)
        XCTAssertEqual(coordinator.stackCount, 2)

        coordinator.remove(at: 0)
        XCTAssertEqual(coordinator.stackCount, 1)
    }

    func testContainsRoute() {
        coordinator.route(to: \.stepA)

        XCTAssertTrue(coordinator.contains(\.stepA))
        XCTAssertFalse(coordinator.contains(\.stepB))
    }

    func testContainsRouteWithInput() {
        coordinator.route(to: \.detail, 42)

        XCTAssertTrue(coordinator.contains(\.detail, 42))
        XCTAssertFalse(coordinator.contains(\.detail, 99))
    }

    func testFirstIndexOfRoute() {
        coordinator.route(to: \.stepA).route(to: \.stepB)

        XCTAssertEqual(coordinator.firstIndex(of: \.stepB), 1)
        XCTAssertNil(coordinator.firstIndex(of: \.stepC))
    }

    func testFirstIndexWithInputDisambiguatesDuplicates() {
        coordinator.route(to: \.detail, 1)
        coordinator.route(to: \.detail, 2)

        XCTAssertEqual(coordinator.firstIndex(of: \.detail, 2), 1)
        XCTAssertEqual(
            coordinator.firstIndex(of: \.detail, 2, comparator: { $0 == $1 }),
            1
        )
        XCTAssertNil(coordinator.firstIndex(of: \.detail, 3))
    }

    func testFirstIndexComposesWithRemove() {
        coordinator.route(to: \.stepA).route(to: \.stepB).route(to: \.stepC)

        if let index = coordinator.firstIndex(of: \.stepB) {
            coordinator.remove(at: index)
        }

        XCTAssertEqual(keyPathHashes(), [
            (\StackTestCoordinator.stepA).hashValue,
            (\StackTestCoordinator.stepC).hashValue,
        ])
    }

    // MARK: Dismissal actions across mutations

    /// Under index-keyed actions, inserting below shifted the registered action
    /// onto the wrong item; UUID keying keeps it attached.
    func testDismissalActionSurvivesInsertBelow() {
        let aggregator = makeAggregator()
        let expectation = expectation(description: "onDismiss fired")
        coordinator.route(to: \.stepC, onDismiss: { expectation.fulfill() })
        _ = aggregator

        coordinator.insert(\.stepA, at: 0)
        coordinator.popLast()

        wait(for: [expectation], timeout: 1)
    }

    func testRemoveFiresRemovedItemsDismissalAction() {
        let aggregator = makeAggregator()
        let expectation = expectation(description: "onDismiss fired")
        coordinator.route(to: \.stepB, onDismiss: { expectation.fulfill() })
        coordinator.route(to: \.stepC)
        _ = aggregator

        coordinator.remove(at: 0)

        wait(for: [expectation], timeout: 1)
    }

    func testRemoveDoesNotFireOtherItemsActions() {
        let aggregator = makeAggregator()
        let expectation = expectation(description: "onDismiss fired")
        expectation.isInverted = true
        coordinator.route(to: \.stepA, onDismiss: { expectation.fulfill() })
        coordinator.route(to: \.stepB)
        _ = aggregator

        coordinator.remove(at: 1)

        wait(for: [expectation], timeout: 0.2)
    }

    // MARK: Router identity across mutations

    /// Under positional ids, popping from a router created before an insert
    /// below it popped to the wrong index (clearing the stack); item identity
    /// resolves the current position.
    func testRouterPopResolvesIndexAfterInsertBelow() {
        let coordinator: StackTestCoordinator = self.coordinator
        coordinator.route(to: \.stepC)
        let router = NavigationRouter(
            id: 0,
            itemID: coordinator.stack.value[0].id,
            coordinator: coordinator
        )

        coordinator.insert(\.stepA, at: 0)
        router.pop()

        XCTAssertEqual(keyPathHashes(), [(\StackTestCoordinator.stepA).hashValue])
    }

    func testRouterPopIsNoOpWhenItemAlreadyRemoved() {
        let coordinator: StackTestCoordinator = self.coordinator
        coordinator.route(to: \.stepC)
        let router = NavigationRouter(
            id: 0,
            itemID: coordinator.stack.value[0].id,
            coordinator: coordinator
        )

        coordinator.popToRoot()
        coordinator.route(to: \.stepA)
        router.pop()

        XCTAssertEqual(keyPathHashes(), [(\StackTestCoordinator.stepA).hashValue])
    }
}
