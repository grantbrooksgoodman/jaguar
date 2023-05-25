//
//  Date+Extensions.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 26/02/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation

public extension Date {
    func separatorDateString() -> NSAttributedString {
        let calendar = Calendar.current
        let dateDifference = calendar.startOfDay(for: Date()).distance(to: calendar.startOfDay(for: self))
        
        let timeString = DateFormatter.localizedString(from: self,
                                                       dateStyle: .none,
                                                       timeStyle: .short)
        
        let overYearFormatter = DateFormatter()
        overYearFormatter.locale = Locale(identifier: RuntimeStorage.languageCode!)
        overYearFormatter.dateFormat = Locale.preferredLanguages[0] == "en-US" ? "MMM dd yyyy, " : "dd MMM yyyy, "
        
        let overYearString = overYearFormatter.string(from: self)
        
        let regularFormatter = DateFormatter()
        regularFormatter.locale = Locale(identifier: RuntimeStorage.languageCode!)
        regularFormatter.dateFormat = "yyyy-MM-dd"
        
        let underYearFormatter = DateFormatter()
        underYearFormatter.locale = Locale(identifier: RuntimeStorage.languageCode!)
        underYearFormatter.dateFormat = Locale.preferredLanguages[0] == "en-US" ? "E MMM d, " : "E d MMM, "
        
        let underYearString = underYearFormatter.string(from: self)
        
        if dateDifference == 0 {
            let separatorString = LocalizedString.today
            return "\(separatorString) \(timeString)".messagesAttributedString(separationIndex: separatorString.count)
        } else if dateDifference == -86400 {
            let separatorString = LocalizedString.yesterday
            return "\(separatorString) \(timeString)".messagesAttributedString(separationIndex: separatorString.count)
        } else if dateDifference >= -604800 {
            guard let selfWeekday = self.dayOfWeek,
                  let currentWeekday = Date().dayOfWeek else {
                return (overYearString + timeString).messagesAttributedString(separationIndex: overYearString.components(separatedBy: ",")[0].count + 1)
            }
            
            if selfWeekday != currentWeekday {
                return "\(selfWeekday) \(timeString)".messagesAttributedString(separationIndex: selfWeekday.count)
            } else {
                return (underYearString + timeString).messagesAttributedString(separationIndex: underYearString.components(separatedBy: ",")[0].count + 1)
            }
        } else if dateDifference < -604800 && dateDifference > -31540000 {
            return (underYearString + timeString).messagesAttributedString(separationIndex: underYearString.components(separatedBy: ",")[0].count + 1)
        }
        
        return (overYearString + timeString).messagesAttributedString(separationIndex: overYearString.components(separatedBy: ",")[0].count + 1)
    }
}
