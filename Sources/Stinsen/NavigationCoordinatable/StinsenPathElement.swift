import Foundation

/// A `Hashable` token representing one pushed `NavigationStackItem` inside a
/// `SwiftUI.NavigationStack` path. Identity is the item's unique id, so popping
/// and re-routing to the same route produces a distinct element.
struct StinsenPathElement: Hashable {
    let itemID: UUID
    let ownerID: ObjectIdentifier
    let index: Int

    static func == (lhs: StinsenPathElement, rhs: StinsenPathElement) -> Bool {
        lhs.itemID == rhs.itemID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(itemID)
    }
}
