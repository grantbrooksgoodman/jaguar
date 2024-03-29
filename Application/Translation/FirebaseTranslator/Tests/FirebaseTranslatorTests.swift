//
//  FirebaseTranslatorTests.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 29/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import XCTest

/* Third-party Frameworks */
import Translator

final class FirebaseTranslatorTests: XCTestCase {
    
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
    
    func testTranslateToEnglish() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        FirebaseTranslator.shared.translate(TranslationInput("Hola mi amigo."),
                                            with: LanguagePair(from: "es",
                                                               to: "en")) { (returnedTranslation,
                                                                             exception) in
            guard let translation = returnedTranslation else {
                let error = exception ?? Exception(metadata: [#file, #function, #line])
                
                Logger.log(error)
                XCTFail(error.descriptor)
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
        
        TranslationSerializer.uploadTranslation(translation) { (exception) in
            guard let error = exception else {
                TranslationSerializer.removeTranslation(for: input,
                                                        languagePair: pair) { (exception) in
                    guard exception != nil else {
                        expectation.fulfill()
                        return
                    }
                    
                    Logger.log(exception ?? Exception(metadata: [#file, #function, #line]))
                }
                
                return
            }
            
            XCTFail(error.descriptor)
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testBlankInputReturnsBlankString() {
        let blankInput = TranslationInput("")
        let sampleLanguagePair = LanguagePair(from: "es",
                                              to: "de")
        
        FirebaseTranslator.shared.translate(blankInput,
                                            with: sampleLanguagePair,
                                            using: .google) { (returnedTranslation,
                                                               exception) in
            guard let translation = returnedTranslation else {
                let error = exception ?? Exception(metadata: [#file, #function, #line])
                
                Logger.log(error)
                XCTFail(error.descriptor)
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
        
        TranslationSerializer.uploadTranslations([spanishTranslation, portugueseTranslation]) { (exception) in
            guard let error = exception else {
                expectation.fulfill()
                return
            }
            
            XCTFail(error.descriptor)
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testYandexTranslator() {
        let expectation = XCTestExpectation(description: "No error returned")
        
        FirebaseTranslator.shared.translate(TranslationInput("This is a test."),
                                            with: LanguagePair(from: "en",
                                                               to: "ru"),
                                            using: .yandex) { (returnedTranslation,
                                                               exception) in
            guard let translation = returnedTranslation else {
                let error = exception ?? Exception(metadata: [#file, #function, #line])
                
                Logger.log(error)
                XCTFail(error.descriptor)
                return
            }
            
            print(translation.output)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
}
