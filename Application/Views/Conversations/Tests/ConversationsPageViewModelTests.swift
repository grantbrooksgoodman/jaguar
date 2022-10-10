//
//  ConversationsPageViewModelTests.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 04/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import XCTest
import SwiftUI
import Foundation
import UIKit

final class ConversationsPageViewModelTests: XCTestCase {
    
    //==================================================//
    
    /* MARK: Overridden Functions */
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    //==================================================//
    
    /* MARK: Retrieval Tests */
    
    func testGetEnglishUser() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        let englishUserID = ""
        UserSerializer.shared.getUser(withIdentifier: englishUserID) { (returnedUser,
                                                                        errorDescriptor) in
            guard returnedUser != nil else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                XCTFail(error)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testGetSpanishUser() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        let spanishUserID = ""
        UserSerializer.shared.getUser(withIdentifier: spanishUserID) { (returnedUser,
                                                                        errorDescriptor) in
            guard returnedUser != nil else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                XCTFail(error)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    //==================================================//
    
    /* MARK: Translation Tests */
    
    func testTranslateStrings() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        let conversationsPVM = ConversationsPageViewModel()
        
        let dataModel = PageViewDataModel(inputs: conversationsPVM.inputs)
        
        dataModel.translateStrings { (returnedTranslations,
                                      errorDescriptor) in
            guard returnedTranslations != nil else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                XCTFail(error)
                return
            }
            
            print("\(#function.components(separatedBy: "(")[0]): Finished!")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 200)
    }
    
    //==================================================//
    
    /* MARK: Conversation Updating Tests */
    
    func testUpdateConversationsForEnglishUser() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        let dispatchGroup = DispatchGroup()
        
        let englishUserID = ""
        //        let spanishUserID = ""
        
        dispatchGroup.enter()
        UserSerializer.shared.getUser(withIdentifier: englishUserID) { (returnedUser,
                                                                        errorDescriptor) in
            guard let user = returnedUser else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                dispatchGroup.leave()
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                XCTFail(error)
                return
            }
            
            RuntimeStorage.store(user, as: .currentUser)
            RuntimeStorage.store(englishUserID, as: .currentUserID)
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            let conversationsPVM = ConversationsPageViewModel()
            conversationsPVM.updateConversations { (returnedConversations,
                                                    errorDescriptor) in
                guard returnedConversations != nil else {
                    let error = errorDescriptor ?? "An unknown error occurred."
                    
                    Logger.log(error,
                               metadata: [#file, #function, #line])
                    XCTFail(error)
                    return
                }
                
                print("\(#function.components(separatedBy: "(")[0]): Finished!")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 30)
    }
    
    func testUpdateConversationsForSpanishUser() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        let dispatchGroup = DispatchGroup()
        
        //        let englishUserID = ""
        let spanishUserID = ""
        
        dispatchGroup.enter()
        UserSerializer.shared.getUser(withIdentifier: spanishUserID) { (returnedUser,
                                                                        errorDescriptor) in
            guard let user = returnedUser else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                dispatchGroup.leave()
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                XCTFail(error)
                return
            }
            
            RuntimeStorage.store(user, as: .currentUser)
            RuntimeStorage.store(spanishUserID, as: .currentUserID)
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            let conversationsPVM = ConversationsPageViewModel()
            conversationsPVM.updateConversations { (returnedConversations,
                                                    errorDescriptor) in
                guard returnedConversations != nil else {
                    let error = errorDescriptor ?? "An unknown error occurred."
                    
                    Logger.log(error,
                               metadata: [#file, #function, #line])
                    XCTFail(error)
                    return
                }
                
                print("\(#function.components(separatedBy: "(")[0]): Finished!")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 30)
    }
}
