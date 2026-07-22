//
//  LoginCoordinator.swift
//  MVVM (iOS)
//
//  Created by Narek Mailian on 2021-10-28.
//

import Foundation
import SwiftUI
import Stinsen

final class DefaultLoginCoordinator: LoginCoordinator, NavigationCoordinatable {
    var stack: Stinsen.NavigationStack<DefaultLoginCoordinator> = Stinsen.NavigationStack(initial: \.start)
    @Root var start = makeStart
    @Root var authenticated = makeAuthenticated
    
    private let api = DefaultAPI()

    func makeStart() -> some View {
        return LoginView(viewModel: DefaultLoginViewModel(api: api, coordinator: self))
    }
    
    func makeAuthenticated() -> DefaultAuthenticatedCoordinator {
        return DefaultAuthenticatedCoordinator()
    }
    
    func routeToAuthenticated() {
        self.root(\.authenticated)
    }
}
