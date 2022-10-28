//
//  MessageSerializerTests.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 04/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import XCTest

final class MessageSerializerTests: XCTestCase {
    
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
    
    func testGetMessages() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        let messageIdentifiers = [String]()
        MessageSerializer.shared.getMessages(withIdentifiers: messageIdentifiers) { (returnedMessages,
                                                                                     exception) in
            guard returnedMessages != nil else {
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
