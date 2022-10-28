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
    
    /* MARK: Creation Tests */
    
    func testCreateConversation() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        let participants = [String]()
        
        ConversationSerializer.shared.createConversation(initialMessageIdentifier: "!",
                                                         participants: participants) { (returnedIdentifier, exception) in
            guard let identifier = returnedIdentifier else {
                let error = exception ?? Exception(metadata: [#file, #function, #line])
                
                Logger.log(error)
                XCTFail(error.descriptor)
                return
            }
            
            print(identifier)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    //==================================================//
    
    /* MARK: Retrieval Tests */
    
    func testGetConversation() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        ConversationSerializer.shared.getConversation(withIdentifier: "") { (returnedConversation, exception) in
            guard returnedConversation != nil else {
                let error = exception ?? Exception(metadata: [#file, #function, #line])
                
                Logger.log(error)
                XCTFail(error.descriptor)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testGetConversations() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        ConversationSerializer.shared.getConversations(withIdentifiers: []) { (returnedConversations, exception) in
            guard returnedConversations != nil else {
                let error = exception ?? Exception(metadata: [#file, #function, #line])
                
                Logger.log(error)
                XCTFail(error.descriptor)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
}
