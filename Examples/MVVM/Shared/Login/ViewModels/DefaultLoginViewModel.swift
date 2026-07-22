//
//  DefaultLoginViewModel.swift
//  MVVM (iOS)
//
//  Created by Narek Mailian on 2021-10-28.
//

import Foundation
import Stinsen

final class DefaultLoginViewModel: LoginViewModel {
    @Published var username: String = ""
    @Published var password: String = ""

    // The coordinator is injected on creation (weak, since the coordinator
    // indirectly retains the view that owns this view model). Injecting —
    // whether manually like here or through a dependency injection framework —
    // keeps the dependency explicit and testable, unlike resolving it from a
    // global store.
    private weak var coordinator: LoginCoordinator?

    fileprivate let api: API

    func login() async throws {
        try await api.login(username: username, password: password)
        await coordinator?.routeToAuthenticated()
    }

    init(api: API, coordinator: LoginCoordinator) {
        self.api = api
        self.coordinator = coordinator
    }
}
