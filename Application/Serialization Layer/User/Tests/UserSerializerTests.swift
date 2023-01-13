//
//  UserSerializerTests.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 04/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import XCTest

/* Third-party Frameworks */
import Firebase

final class UserSerializerTests: XCTestCase {
    
    //==================================================//
    
    /* MARK: Overridden Methods */
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    //==================================================//
    
    /* MARK: Testing Methods */
    
    func testCreateUser() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        guard let generatedKey = Database.database().reference().child("/test/users/").childByAutoId().key else {
            
            XCTFail("Unable to generate key for new user.")
            return
        }
        
        var phoneNumberString = ""
        for _ in 0...9 {
            phoneNumberString += "\(Int().random(min: 0, max: 9))"
        }
        
        UserSerializer.shared.createUser(generatedKey,
                                         callingCode: "1",
                                         languageCode: ["af", "ga", "sq", "it", "ar", "ja", "az", "kn", "eu", "ko", "bn", "la", "be", "lv", "bg", "lt", "ca", "mk", "zh-CN", "ms", "zh-TW", "mt", "hr", "no", "cs", "fa", "da", "pl", "nl", "pt", "ro", "eo", "ru", "et", "sr", "tl", "sk", "fi", "sl", "fr", "es", "gl", "sw", "ka", "sv", "de", "ta", "el", "te", "gu", "th", "ht", "tr", "iw", "uk", "hi", "ur", "hu", "vi", "is", "cy", "id", "yi"].randomElement()!,
                                         phoneNumber: phoneNumberString.digits,
                                         pushTokens: nil,
                                         region: Array(RuntimeStorage.callingCodeDictionary!.keys).randomElement()!) { (exception) in
            guard let error = exception else {
                expectation.fulfill()
                return
            }
            
            XCTFail(error.descriptor)
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testGetUser() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        UserSerializer().getUser(withIdentifier: "") { (returnedUser,
                                                        exception) in
            guard let user = returnedUser else {
                Logger.log(exception ?? Exception(metadata: [#file, #function, #line]))
                XCTFail(exception?.descriptor ?? "Couldn't get user.")
                
                return
            }
            
            user.deSerializeConversations { (returnedConversations,
                                             exception) in
                guard returnedConversations != nil else {
                    Logger.log(exception ?? Exception(metadata: [#file, #function, #line]))
                    XCTFail(exception?.descriptor ?? "An unknown error occurred.")
                    
                    return
                }
                
                expectation.fulfill()
            }
        }
    }
}
