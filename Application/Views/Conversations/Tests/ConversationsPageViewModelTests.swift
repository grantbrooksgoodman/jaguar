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
    
    /* MARK: Overridden Methods */
    
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
                                                                        exception) in
            guard returnedUser != nil else {
                let error = exception ?? Exception(metadata: [#file, #function, #line])
                
                Logger.log(error)
                XCTFail(error.descriptor)
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
                                                                        exception) in
            guard returnedUser != nil else {
                let error = exception ?? Exception(metadata: [#file, #function, #line])
                
                Logger.log(error)
                XCTFail(error.descriptor)
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
                                      exception) in
            guard returnedTranslations != nil else {
                let error = exception ?? Exception(metadata: [#file, #function, #line])
                
                Logger.log(error)
                XCTFail(error.descriptor)
                return
            }
            
            print("\(#function.components(separatedBy: "(")[0]): Finished!")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 200)
    }
}
