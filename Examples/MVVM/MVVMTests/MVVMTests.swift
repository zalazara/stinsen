//
//  MVVMTests.swift
//  MVVMTests
//
//  Created by Narek Mailian on 2021-10-28.
//

import XCTest
@testable import MVVM

import Stinsen

class MVVMTests: XCTestCase {

    override func setUpWithError() throws {

    }

    override func tearDownWithError() throws {

    }

    @MainActor func testLoginSuccessfulViewModel() async throws {
        let mockAPI = MockAPI()
        let mockCoordinator = MockLoginCoordinator()

        XCTAssert(!mockCoordinator.routed)

        // The coordinator is injected directly: no global router store needed,
        // and the test cannot accidentally resolve someone else's router.
        let loginViewModel = DefaultLoginViewModel(api: mockAPI, coordinator: mockCoordinator)

        try await loginViewModel.login()

        XCTAssert(mockCoordinator.routed)
    }
}
