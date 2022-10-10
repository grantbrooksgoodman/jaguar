//
//  UserTests.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 25/08/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import XCTest

final class UserTests: XCTestCase {
    
    //==================================================//
    
    /* MARK: Overridden Functions */
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    //==================================================//
    
    /* MARK: Tests */
    
    func testDeSerializeConversations() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        UserSerializer.shared.getUser(withIdentifier: "QDpQ8qwwdMOS98QcEMjL9aV1oPn1") { (returnedUser,
                                                                                         errorDescriptor) in
            guard let user = returnedUser else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                XCTFail(error)
                return
            }
            
            user.deSerializeConversations { (returnedConversations,
                                             errorDescriptor) in
                guard let conversations = returnedConversations else {
                    let error = errorDescriptor ?? "An unknown error occurred."
                    
                    Logger.log(error,
                               metadata: [#file, #function, #line])
                    XCTFail(error)
                    return
                }
                
                expectation.fulfill()
                print(conversations.first?.identifier)
            }
        }
        
        wait(for: [expectation], timeout: 100)
    }
}