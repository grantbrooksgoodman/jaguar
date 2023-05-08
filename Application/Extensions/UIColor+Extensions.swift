//
//  UIColor+Extensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 05/05/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

public extension UIColor {
    func darker(by percentage: CGFloat = 30.0) -> UIColor? {
        return adjust(by: -1 * abs(percentage))
    }
    
    func lighter(by percentage: CGFloat = 30.0) -> UIColor? {
        return adjust(by: abs(percentage))
    }
    
    private func adjust(by percentage: CGFloat = 30.0) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return UIColor(red: min(red + percentage / 100, 1.0),
                       green: min(green + percentage / 100, 1.0),
                       blue: min(blue + percentage / 100, 1.0),
                       alpha: alpha)
    }
}
