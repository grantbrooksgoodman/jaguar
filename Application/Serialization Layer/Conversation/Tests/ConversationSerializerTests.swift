//
//  ConversationSerializerTests.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 04/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import XCTest

final class ConversationSerializerTests: XCTestCase {
    
    //==================================================//
    
    /* MARK: Overridden Functions */
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    //==================================================//
    
    /* MARK: Testing Functions */
    
    func testGetConversation() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        ConversationSerializer.shared.getConversation(withIdentifier: "") { (returnedConversation, errorDescriptor) in
            guard returnedConversation != nil else {
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
    
    func testGetConversations() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        ConversationSerializer.shared.getConversations(withIdentifiers: []) { (returnedConversations, errorDescriptor) in
            guard returnedConversations != nil else {
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
}
