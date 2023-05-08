//
//  UILabel+Extensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 05/05/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

extension UILabel {
    var maxNumberOfLines: Int {
        let maxSize = CGSize(width: frame.size.width, height: CGFloat(MAXFLOAT))
        let text = (self.text ?? "") as NSString
        let textHeight = text.boundingRect(with: maxSize,
                                           options: .usesLineFragmentOrigin,
                                           attributes: [.font: font as Any],
                                           context: nil).height
        let lineHeight = font.lineHeight
        return Int(ceil(textHeight / lineHeight))
    }
}
