//
//  AzureTranslator.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/**
 Lorem ipsum dolor sit **CLASS**, consectetur adipiscing elit, sed do.
 
 - Parameter lorem: Lorem ipsum dolor sit **Amet**.
 - Parameter completion: Upon success, returns –––––. Upon failure, a string describing the error(s) encountered.
 
 - Note: Completion variables are **NOT** *mutually exclusive*.
 - Returns: Upon success, returns a deserialized **X** object. Upon failure, a string describing the error(s) encountered.
 - Requires: The **X's** associated **X** (if applicable) to have more than just the specified **X** in its list of *teamIdentifiers.*
 - Warning: Dumps errors to console.
 
 ~~~
 completion(returnedX, errorDescriptor)
 ~~~
 */

/* First-party Frameworks */
import Foundation

public class AzureTranslator: Translatorable {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    private let apiKey = ""
    
    //==================================================//
    
    /* MARK: Public Functions */
    
    public func instance() -> Translatorable {
        return AzureTranslator()
    }
    
    public func translate(_ text: String,
                          from: String,
                          to: String,
                          using: TranslationPlatform = .azure,
                          completion: @escaping(_ returnedResult: String?,
                                                _ errorDescriptor: String?) -> Void) {
        guard text.lowercasedTrimmingWhitespace != "" else {
            completion("", nil)
            return
        }
        
        if let translationRequest = getTranslationRequest(text,
                                                          from: from,
                                                          to: to) {
            executeTranslationRequest(translationRequest) { (data, response, error) in
                if let error = error {
                    completion(nil, errorInfo(error))
                } else if let data = data {
                    let parsedData = self.parseJsonData(data)
                    
                    if let translationResult = parsedData.parsedText {
                        completion(translationResult, nil)
                    } else {
                        if let error = parsedData.errorDescriptor {
                            completion(nil, error)
                        }
                        
                        completion(nil, "An unknown error occurred.")
                    }
                }
            }
        } else {
            completion(nil, "Unable to create Azure translation request.")
        }
    }
    
    //==================================================//
    
    /* MARK: Private Functions */
    
    private func executeTranslationRequest(_ request: URLRequest,
                                           completion: @escaping(_ data: Data?,
                                                                 _ response: URLResponse?,
                                                                 _ error: Error?) -> Void) {
        let sessionConfiguration = URLSessionConfiguration.default
        let urlSession = URLSession(configuration: sessionConfiguration)
        
        let dataTask = urlSession.dataTask(with: request) { (data, response, error) in
            completion(data, response, error)
        }
        
        dataTask.resume()
    }
    
    private func getTranslationRequest(_ text: String,
                                       from: String,
                                       to: String) -> URLRequest? {
        let jsonEncoder = JSONEncoder()
        
        let hostUrlString = "api.cognitive.microsofttranslator.com"
        let apiUrlString = "https://\(hostUrlString)/translate?api-version=3.0&from=" + from + "&to=" + to
        
        guard let requestURL = URL(string: apiUrlString) else {
            log("Unable to convert API URL string to URL.",
                metadata: [#file, #function, #line])
            return nil
        }
        
        let jsonToTranslate = try? jsonEncoder.encode([["text": text]])
        var urlRequest = URLRequest(url: requestURL)
        
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        urlRequest.addValue("centralus", forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("ff93555a-766e-4cfa-ae43-1543ab6a86d4", forHTTPHeaderField: "X-ClientTraceID")
        urlRequest.addValue(hostUrlString, forHTTPHeaderField: "Host")
        urlRequest.addValue(String(describing: jsonToTranslate?.count), forHTTPHeaderField: "Content-Length")
        urlRequest.httpBody = jsonToTranslate
        
        return urlRequest
    }
    
    private func parseJsonData(_ data: Data) -> (parsedText: String?,
                                                 errorDescriptor: String?) {
        struct TranslationStrings: Codable {
            var text: String
            var to: String
        }
        
        struct ReturnedJsonStructure: Codable {
            var translations: [TranslationStrings]
        }
        
        let jsonDecoder = JSONDecoder()
        
        do {
            let translationData = try jsonDecoder.decode(Array<ReturnedJsonStructure>.self,
                                                         from: data)
            return (translationData[0].translations[0].text, nil)
        } catch {
            return (nil, "Unable to decode JSON data.")
        }
    }
}
