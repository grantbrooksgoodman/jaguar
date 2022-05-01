//
//  YandexTranslator.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit
import WebKit

public class YandexTranslator: NSObject, Translatorable {
    
    //==================================================//
    
    /* MARK: - Class-level Variable Declarations */
    
    //Strings
    private var errorDescriptor = ""
    private var textToTranslate = ""
    private var translatedText = ""
    
    //Other Declarations
    private let dispatchGroup = DispatchGroup()
    private var leftDispatchGroup = false
    private var timesEvaluated = 0
    private let webView = WKWebView()
    
    //==================================================//
    
    /* MARK: - Public Functions */
    
    public func instance() -> Translatorable {
        return YandexTranslator()
    }
    
    public func translate(_ text: String,
                          from: String,
                          to: String,
                          using: TranslationPlatform = .yandex,
                          completion: @escaping(_ returnedResult: String?,
                                                _ errorDescriptor: String?) -> Void) {
        guard text.lowercasedTrimmingWhitespace != "" else {
            completion("", nil)
            return
        }
        
        textToTranslate = text
        
        if webView.isLoading {
            after(seconds: 3) {
                self.translate(text,
                               from: from,
                               to: to) { (returnedResult, errorDescriptor) in
                    completion(returnedResult, errorDescriptor)
                }
            }
        } else {
            let parsedText = text.replacingOccurrences(of: " ", with: "+")
            
            let url = URL(string: "https://translate.yandex.com/?lang=\(from)-\(to)&text=\(parsedText)")!
            
            TranslatorService.main.removeCookies()
            
            let urlRequest = URLRequest(url: url)
            webView.navigationDelegate = self
            webView.load(urlRequest)
            
            dispatchGroup.enter()
            
            dispatchGroup.notify(queue: .main) {
                completion(self.translatedText == "" ? nil : self.translatedText,
                           self.errorDescriptor == "" ? nil : self.errorDescriptor)
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private func conditionallyLeaveGroup() {
        if !self.leftDispatchGroup {
            self.dispatchGroup.leave()
            self.leftDispatchGroup = true
        }
    }
    
    private func evaluateJavaScript() {
        self.webView.evaluateJavaScript("document.getElementsByClassName('translation')[0].innerText;") { (data, error) in
            if let error = error {
                guard self.timesEvaluated > 99 else {
                    self.timesEvaluated += 1
                    after(milliseconds: 100) {
                        self.evaluateJavaScript()
                    }
                    return
                }
                
                self.errorDescriptor = errorInfo(error)
                self.conditionallyLeaveGroup()
            } else if let text = data as? String,
                      text.lowercasedTrimmingWhitespace != "" {
                self.translatedText = text.removingOccurrences(of: ["\n"])
                self.conditionallyLeaveGroup()
            } else {
                after(milliseconds: 100) {
                    self.evaluateJavaScript()
                }
            }
        }
    }
}

//==================================================//

/* MARK: Extensions */

/**/

/* MARK: WKNavigationDelegate */
extension YandexTranslator: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView.url!.absoluteString.hasPrefix("https://translate.yandex.com/showcaptcha") {
            errorDescriptor = "Can't use Yandex Translate right now; try again later."
            log(errorDescriptor,
                metadata: [#file, #function, #line])
            conditionallyLeaveGroup()
        } else {
            evaluateJavaScript()
        }
    }
}
