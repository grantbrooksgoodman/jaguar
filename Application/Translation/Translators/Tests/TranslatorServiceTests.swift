//
//  TranslatorServiceTests.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 29/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import XCTest

final class TranslatorServiceTests: XCTestCase {
    
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
    
    func testTranslateToEnglish() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        TranslatorService.main.translate(TranslationInput("Hola mi amigo."),
                                         with: LanguagePair(from: "es",
                                                            to: "en")) { (returnedTranslation,
                                                                          errorDescriptor) in
            guard returnedTranslation != nil || errorDescriptor != nil else {
                XCTFail("An unknown error occurred.")
                return
            }
            
            guard let translation = returnedTranslation else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                XCTFail(error)
                return
            }
            
            print(translation.output)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testAddRemoveTranslations() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        //Test used alternate.
        let input = TranslationInput("Hello!")
        let pair = LanguagePair(from: "en",
                                to: "es")
        let translation = Translation(input: input,
                                      output: "¡Hola!",
                                      languagePair: pair)
        
        TranslationSerializer.uploadTranslation(translation) { (errorDescriptor) in
            guard let error = errorDescriptor else {
                TranslationSerializer.removeTranslation(for: input,
                                                        languagePair: pair) { (errorDescriptor) in
                    guard let error = errorDescriptor else {
                        expectation.fulfill()
                        return
                    }
                    
                    Logger.log(errorDescriptor ?? "An unknown error occurred.",
                               metadata: [#file, #function, #line])
                }
                
                return
            }
            
            XCTFail(error)
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testBlankInputReturnsBlankString() {
        let blankInput = TranslationInput("")
        let sampleLanguagePair = LanguagePair(from: "es",
                                              to: "de")
        
        TranslatorService.main.translate(blankInput,
                                         with: sampleLanguagePair,
                                         requiresHUD: false,
                                         using: .google) { (returnedTranslation,
                                                            errorDescriptor) in
            guard let translation = returnedTranslation else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                XCTFail(error)
                return
            }
            
            XCTAssertEqual(translation.output, "")
        }
    }
    
    func testUploadWithDifferentLanguagePairs() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        let spanishTranslation = Translation(input: TranslationInput("Hello!"),
                                             output: "¡Hola!",
                                             languagePair: LanguagePair(from: "en",
                                                                        to: "es"))
        
        let portugueseTranslation = Translation(input: TranslationInput("Hello!"),
                                                output: "Ola!",
                                                languagePair: LanguagePair(from: "en",
                                                                           to: "pt"))
        
        TranslationSerializer.uploadTranslations([spanishTranslation, portugueseTranslation]) { (errorDescriptor) in
            guard let error = errorDescriptor else {
                expectation.fulfill()
                return
            }
            
            XCTFail(error)
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testYandexTranslator() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        TranslatorService.main.translate(TranslationInput("This is a test."),
                                         with: LanguagePair(from: "en",
                                                            to: "ru"),
                                         using: .yandex) { (returnedTranslation,
                                                            errorDescriptor) in
            guard let translation = returnedTranslation else {
                let error = errorDescriptor ?? "An unknown error occurred."
                
                Logger.log(error,
                           metadata: [#file, #function, #line])
                XCTFail(error)
                return
            }
            
            print(translation.output)
            expectation.fulfill()
            
        }
        
        wait(for: [expectation], timeout: 10)
    }
}
