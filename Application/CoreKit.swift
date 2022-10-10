//
//  CoreKit.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 07/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import AlertKit
import PKHUD

public enum Core {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static let gcd = GCDCore.shared
    public static let hud = HUDCore.shared
    public static let ui = UICore.shared
    
    public static var currentCalendar: Calendar! { get { return getCurrentCalendar() } }
    public static var masterDateFormatter: DateFormatter! { get { return getMasterDateFormatter() } }
    public static var secondaryDateFormatter: DateFormatter! { get { return getSecondaryDateFormatter() } }
    
    //==================================================//
    
    /* MARK: - Private Functions */
    
    private static func getCurrentCalendar() -> Calendar {
        var currentCalendar = Calendar(identifier: .gregorian)
        currentCalendar.timeZone = TimeZone(abbreviation: "GMT")!
        
        return currentCalendar
    }
    
    private static func getMasterDateFormatter() -> DateFormatter {
        let masterDateFormatter = DateFormatter()
        masterDateFormatter.dateFormat = "yyyy-MM-dd"
        masterDateFormatter.locale = Locale(identifier: "en_GB")
        
        return masterDateFormatter
    }
    
    private static func getSecondaryDateFormatter() -> DateFormatter {
        let secondaryDateFormatter = DateFormatter()
        secondaryDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        secondaryDateFormatter.locale = Locale(identifier: "en_GB")
        
        return secondaryDateFormatter
    }
    
    //==================================================//
    
    /* MARK: - Core GCD */
    public class GCDCore {
        
        //==================================================//
        
        /* MARK: - Properties */
        
        public static let shared = GCDCore()
        
        //==================================================//
        
        /* MARK: - Public Functions */
        
        public func after(milliseconds: Int, do: @escaping () -> Void = {}) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds)) {
                `do`()
            }
        }
        
        public func after(seconds: Int, do: @escaping () -> Void = {}) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(seconds)) {
                `do`()
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Core HUD */
    public class HUDCore {
        
        //==================================================//
        
        /* MARK: - Properties */
        
        public static let shared = HUDCore()
        
        //==================================================//
        
        /* MARK: - Public Functions */
        
        public func hide(delay: Double? = nil) {
            guard let delay = delay else {
                if PKHUD.sharedHUD.isVisible {
                    PKHUD.sharedHUD.hide(true)
                }
                
                return
            }
            
            let millisecondDelay = Int(delay * 1000)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(millisecondDelay)) {
                if PKHUD.sharedHUD.isVisible {
                    PKHUD.sharedHUD.hide(true)
                }
            }
        }
        
        public func showProgress(delay: Double? = nil, text: String? = nil) {
            guard let delay = delay else {
                DispatchQueue.main.async {
                    if !PKHUD.sharedHUD.isVisible {
                        PKHUD.sharedHUD.contentView = PKHUDProgressView(title: nil, subtitle: text ?? nil)
                        PKHUD.sharedHUD.show(onView: AKCore.shared.getFrontmostVC().view)
                    }
                }
                
                return
            }
            
            let millisecondDelay = Int(delay * 1000)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(millisecondDelay)) {
                if !PKHUD.sharedHUD.isVisible {
                    PKHUD.sharedHUD.contentView = PKHUDProgressView(title: nil, subtitle: text ?? nil)
                    PKHUD.sharedHUD.show(onView: AKCore.shared.getFrontmostVC().view)
                }
            }
        }
    }
    
    //==================================================//
    
    /* MARK: - Core UI */
    public class UICore {
        
        //==================================================//
        
        /* MARK: - Properties */
        
        public static let shared = UICore()
        
        //==================================================//
        
        /* MARK: - Public Functions */
        
        public func findAndResignFirstResponder() {
            DispatchQueue.main.async {
                if let firstResponder = self.findFirstResponder(inView: AKCore.shared.getFrontmostVC().view) {
                    firstResponder.resignFirstResponder()
                }
            }
        }
        
        public func findFirstResponder(inView view: UIView) -> UIView? {
            for subview in view.subviews {
                if subview.isFirstResponder {
                    return subview
                }
                
                if let recursiveSubview = findFirstResponder(inView: subview) {
                    return recursiveSubview
                }
            }
            
            return nil
        }
        
        public func nameTag(for viewNamed: String) -> Int {
            var finalValue: Float = 1.0
            
            for character in String(viewNamed.unicodeScalars.filter(CharacterSet.letters.contains)).characterArray {
                finalValue += (finalValue / Float(character.alphabeticalPosition))
            }
            
            return Int(String(finalValue).replacingOccurrences(of: ".", with: "")) ?? Int().random(min: 5, max: 10)
        }
        
        public func politelyPresent(viewController: UIViewController) {
            Core.hud.hide()
            
            let keyWindow = UIApplication.shared.windows.filter { $0.isKeyWindow }.first
            
            if var topController = keyWindow?.rootViewController {
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }
                
                if topController.presentedViewController == nil, !topController.isKind(of: UIAlertController.self) {
                    topController = AKCore.shared.getFrontmostVC()
                    
                    if !Thread.isMainThread {
                        DispatchQueue.main.sync {
                            topController.present(viewController, animated: true)
                        }
                    } else {
                        topController.present(viewController, animated: true)
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                        self.politelyPresent(viewController: viewController)
                    }
                }
            }
        }
    }
}
