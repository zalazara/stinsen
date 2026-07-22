import Foundation
import SwiftUI
import Stinsen

extension TestbedEnvironmentObjectCoordinator {
    @ViewBuilder func makePushScreen() -> some View {
        TestbedEnvironmentObjectScreen()
    }
    
    @ViewBuilder func makeModalScreen() -> some View {
        NavigationView {
            TestbedEnvironmentObjectScreen()
        }
    }
    
    func makePushCoordinator() -> TestbedEnvironmentObjectCoordinator {
        return TestbedEnvironmentObjectCoordinator()
    }
    
    func makeModalCoordinator() -> NavigationViewCoordinator<TestbedEnvironmentObjectCoordinator> {
        return NavigationViewCoordinator(TestbedEnvironmentObjectCoordinator())
    }
    
    @ViewBuilder func makeStart() -> some View {
        TestbedEnvironmentObjectScreen()
    }

    @ViewBuilder func makeStackStepA() -> some View {
        StackManipulationStepScreen(step: .a)
    }

    @ViewBuilder func makeStackStepB() -> some View {
        StackManipulationStepScreen(step: .b)
    }

    @ViewBuilder func makeStackStepC() -> some View {
        StackManipulationStepScreen(step: .c)
    }
}
