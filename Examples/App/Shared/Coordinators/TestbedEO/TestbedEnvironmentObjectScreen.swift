import Foundation
import SwiftUI
import Stinsen

struct TestbedEnvironmentObjectScreen: View {
    @EnvironmentObject var testbed: TestbedEnvironmentObjectCoordinator.Router
    @State var text: String = ""
    
    var body: some View {
        ScrollView {
            VStack {
                Text("Number in coordinator stack: " + String(testbed.id))
                TextField("Textfield", text: $text)
                RoundedButton("Modal screen") {
                    testbed.route(to: \.modalScreen)
                }
                RoundedButton("Push screen") {
                    testbed.route(to: \.pushScreen)
                }
                /*
                if #available(iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
                    RoundedButton("Cover screen") {
                        testbed.route(to: .coverScreen)
                    }
                }
                 */
                RoundedButton("Modal coordinator") {
                    testbed.route(to: \.modalCoordinator)
                }
                RoundedButton("Push coordinator") {
                    testbed.route(to: \.pushCoordinator)
                }
                /*
                if #available(iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
                    RoundedButton("Cover coordinator") {
                        testbed.route(to: .coverCoordinator)
                    }
                }
                 */
                RoundedButton("Dismiss coordinator") {
                    testbed.dismissCoordinator {
                        print("bye!")
                    }
                }
                .disabled(!testbed.canDismiss)
                InfoText("Stack manipulation demo:")
                RoundedButton("Push steps A → B → C") {
                    testbed
                        .route(to: \.stackStepA)
                        .route(to: \.stackStepB)
                        .route(to: \.stackStepC)
                }
                RoundedButton("Deep link straight to step C") {
                    testbed.route(to: \.stackStepC)
                }
            }
        }
    }
}

/// Demonstrates the UINavigationController-style stack manipulation API:
/// `insert`/`insertBelowTop`, `remove`/`removeFirst` and the read-only
/// introspection (`stackCount`, `contains`, `firstIndex(of:)`).
struct StackManipulationStepScreen: View {
    enum Step: String {
        case a = "A"
        case b = "B"
        case c = "C"
    }

    @EnvironmentObject var testbed: TestbedEnvironmentObjectCoordinator.Router
    let step: Step

    var body: some View {
        ScrollView {
            VStack {
                InfoText("Step \(step.rawValue) — the stack has \(testbed.stackCount) items")
                switch step {
                case .a:
                    RoundedButton("Push step B") {
                        testbed.route(to: \.stackStepB)
                    }
                case .b:
                    RoundedButton("Push step C") {
                        testbed.route(to: \.stackStepC)
                    }
                case .c:
                    // removeFirst: A → B → C becomes A → C, so back skips B.
                    RoundedButton("Remove step B (back will land on A)") {
                        try? testbed.removeFirst(\.stackStepB)
                    }
                    // insertBelowTop: fabricates a back destination that was
                    // never visited, e.g. after the deep link straight to C.
                    RoundedButton("Insert step B below (back will land on B)") {
                        if !testbed.contains(\.stackStepB) {
                            testbed.insertBelowTop(\.stackStepB)
                        }
                    }
                    // firstIndex(of:) + remove(at:): index-based manipulation,
                    // the counterpart of searching UINavigationController's
                    // viewControllers array.
                    RoundedButton("Remove step A via firstIndex(of:)") {
                        if let index = testbed.firstIndex(of: \.stackStepA) {
                            testbed.remove(at: index)
                        }
                    }
                    // insert(_:at:): rebuild the stack at any position.
                    RoundedButton("Insert step A at the bottom") {
                        if !testbed.contains(\.stackStepA) {
                            testbed.insert(\.stackStepA, at: 0)
                        }
                    }
                    RoundedButton("Pop") {
                        testbed.pop()
                    }
                }
            }
        }
    }
}
