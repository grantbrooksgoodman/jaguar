//
//  String+Extensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 26/02/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

public extension String {
    func messagesAttributedString(separationIndex: Int) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: self)
        
        let boldAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12),
                                                             .foregroundColor: UIColor.gray]
        
        let regularAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12),
                                                                .foregroundColor: UIColor.lightGray]
        
        attributedString.addAttributes(boldAttributes, range: NSRange(location: 0,
                                                                      length: separationIndex))
        
        attributedString.addAttributes(regularAttributes, range: NSRange(location: separationIndex,
                                                                         length: attributedString.length - separationIndex))
        
        return attributedString
    }
}
