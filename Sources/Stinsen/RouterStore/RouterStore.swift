import Foundation

/// Resolves "the first stored router of this type" from a global registry.
/// With more than one coordinator of the same type alive (two tabs sharing a
/// flow, a coordinator pushing itself), it can silently return the wrong one.
@available(*, deprecated, message: "Use @EnvironmentObject var router: MyCoordinator.Router inside views, or inject the coordinator/router where you need it outside the view tree. RouterObject resolves ambiguously when several coordinators of the same type are alive.")
@MainActor @propertyWrapper public struct RouterObject<Value: Routable> {
    private var storage: RouterStore
    private var retreived: Value?
    
    public var wrappedValue: Value? {
        mutating get {
            guard let currentValue: Value = self.retreived else {
                self.retreived = storage.retrieve()
                return self.retreived
            }
            return currentValue
        }
        @available(*, unavailable, message: "RouterObject cannot be set") set {
            fatalError()
        }
    }
    
    public init() {
        self.storage = RouterStore.shared
    }
}

@MainActor public class RouterStore {
    public static let shared = RouterStore()
    
    // an array of weak references
    private var routers = [WeakRef<AnyObject>]()
}

public extension RouterStore {
    func store<T: Routable>(router: T) {
        cleanupRouterStore()
        let ref = WeakRef<AnyObject>(value: router)
        self.routers.insert(ref, at: 0)
    }
    
    func retrieve<T: Routable>() -> T? {
        for router in self.routers {
            if let foundRouter = router.value as? T, router.value != nil {
                return foundRouter
            }
        }
        
        return nil
    }
    
    /// Removes all nil weak references
    private func cleanupRouterStore() {
        let notNilRouters = self.routers.filter({ $0.value != nil })
        self.routers = notNilRouters
    }
}
