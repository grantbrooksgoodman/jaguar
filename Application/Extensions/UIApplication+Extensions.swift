//
//  UIApplication+Extensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 07/03/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

public extension UIApplication {
#if !EXTENSION
    class func topViewController(_ base: UIViewController? = UIApplication.shared.windows.first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(selected)
            }
        }
        
        if let presented = base?.presentedViewController {
            return topViewController(presented)
        }
        
        return base
    }
#else
    class func topViewController(_ base: UIViewController? = nil) -> UIViewController? {
        return base
    }
#endif
}
