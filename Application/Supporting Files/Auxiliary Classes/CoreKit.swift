//
//  CoreKit.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

/* Third-party Frameworks */
import AlertKit
#if !EXTENSION
import ProgressHUD
#endif

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
    
    /* MARK: - Private Methods */
    
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
        
        /* MARK: - Public Methods */
        
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
        
        /* MARK: - Public Methods */
        
        public func hide(delay: Double? = nil) {
#if !EXTENSION
            guard let delay = delay else {
                ProgressHUD.dismiss()
                Core.gcd.after(milliseconds: 500) { ProgressHUD.remove() }
                return
            }
            
            let millisecondDelay = Int(delay * 1000)
            Core.gcd.after(milliseconds: millisecondDelay) {
                ProgressHUD.dismiss()
                Core.gcd.after(milliseconds: 500) { ProgressHUD.remove() }
            }
#endif
        }
        
        public func showProgress(delay: Double? = nil, text: String? = nil) {
#if !EXTENSION
            guard let delay = delay else {
                DispatchQueue.main.async {
                    ProgressHUD.show(text ?? nil)
                }
                
                return
            }
            
            let millisecondDelay = Int(delay * 1000)
            Core.gcd.after(milliseconds: millisecondDelay) {
                ProgressHUD.show(text ?? nil)
            }
#endif
        }
        
        public func showSuccess(text: String? = nil) {
#if !EXTENSION
            ProgressHUD.showSucceed(text)
#endif
        }
    }
    
    //==================================================//
    
    /* MARK: - Core UI */
    public class UICore {
        
        //==================================================//
        
        /* MARK: - Properties */
        
        public static let shared = UICore()
        private var topmostVC: UIViewController? {
            get {
#if !EXTENSION
                // Use connectedScenes to find the .foregroundActive rootViewController
                var rootViewController: UIViewController?
                
                for scene in UIApplication.shared.connectedScenes {
                    if scene.activationState == .foregroundActive {
                        rootViewController = (scene.delegate as? UIWindowSceneDelegate)?.window!!.rootViewController
                        break
                    }
                }
                
                // Then, find the topmost presentedVC from it.
                var presentedViewController = rootViewController
                while presentedViewController?.presentedViewController != nil {
                    presentedViewController = presentedViewController?.presentedViewController
                }
                
                guard let presented = presentedViewController else { return nil }
                return presented
#else
                return nil
#endif
            }
        }
        
        //==================================================//
        
        /* MARK: - First Responder Methods */
        
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
        
        //==================================================//
        
        /* MARK: - Navigation Bar Appearance */
        
        public func resetNavigationBarAppearance() {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UITraitCollection.current.userInterfaceStyle == .dark ? .black : .white
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        
        public func setNavigationBarAppearance(backgroundColor: UIColor,
                                               titleColor: UIColor) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = backgroundColor
            
            appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
            appearance.titleTextAttributes = [.foregroundColor: titleColor]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        
        //==================================================//
        
        /* MARK: - View Controller Presentation */
        
        public func present(viewController: UIViewController) {
            Core.hud.hide()
            
            guard let presented = topmostVC else {
                politelyPresent(viewController: viewController)
                return
            }
            
            presented.present(viewController, animated: true)
        }
        
        public func politelyPresent(viewController: UIViewController) {
#if !EXTENSION
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
#endif
        }
        
        //==================================================//
        
        /* MARK: - Other Methods */
        
        public func nameTag(for viewNamed: String) -> Int {
            var finalValue: Float = 1.0
            
            for character in String(viewNamed.unicodeScalars.filter(CharacterSet.letters.contains)).characterArray {
                finalValue += (finalValue / Float(character.alphabeticalPosition))
            }
            
            return Int(String(finalValue).replacingOccurrences(of: ".", with: "")) ?? Int().random(min: 5, max: 10)
        }
    }
}
