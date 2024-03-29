//
//  Extensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import UIKit
import SwiftUI

/* Third-party Frameworks */
import Translator

//==================================================//

/* MARK: - Array Extensions */

public extension Array {
    var randomElement: Element {
        return self[Int(arc4random_uniform(UInt32(count)))]
    }
    
    var shuffled: [Element] {
        var elements = self
        
        for index in 0 ..< elements.count {
            elements.swapAt(index, Int(arc4random_uniform(UInt32(elements.count - index))) + index)
        }
        
        return elements
    }
}

public extension Array where Element == String {
    /* MARK: - Methods */
    
    func containsAny(in: [String]) -> Bool {
        for value in `in` {
            if contains(value) {
                return true
            }
        }
        
        return false
    }
    
    func containsAll(in: [String]) -> Bool {
        var bools = [Bool]()
        
        for value in `in` {
            if contains(value) {
                bools.append(true)
            }
        }
        
        guard !bools.isEmpty else { return false }
        
        return bools.allSatisfy({ $0 == true })
    }
    
    func count(of: String) -> Int {
        var count = 0
        
        for string in self {
            count += string == of ? 1 : 0
        }
        
        return count
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var duplicates: [String]? {
        let duplicates = Array(Set(filter({ (s: String) in filter({ $0 == s }).count > 1})))
        return duplicates.isEmpty ? nil : duplicates
    }
}

public extension Array where Element == Translation {
    func homogeneousLanguagePairs() -> Bool {
        var pairs = [String]()
        
        for element in self {
            pairs.append(element.languagePair.asString())
            pairs = pairs.unique()
        }
        
        return !(pairs.count > 1)
    }
    
    func languagePairs() -> [LanguagePair] {
        var pairStrings = [String]()
        
        for element in self {
            pairStrings.append(element.languagePair.asString())
        }
        
        pairStrings = pairStrings.unique()
        
        var pairs = [LanguagePair]()
        
        //        #warning("Think about whether this should be optional return.")
        for pairString in pairStrings {
            if let languagePair = pairString.asLanguagePair() {
                pairs.append(languagePair)
            }
        }
        
        return pairs
    }
    
    func matchedTo(_ inputs: [String: TranslationInput]) -> [String: Translation]? {
        var translationDictionary = [String: Translation]()
        
        for translation in self {
            if let matchingInput = translation.matchingInput(inputs: inputs) {
                translationDictionary[matchingInput.key] = matchingInput.translation
            }
        }
        
        return translationDictionary.count != inputs.count ? nil : translationDictionary
    }
    
    func `where`(languagePair: LanguagePair) -> [Translation] {
        var matching = [Translation]()
        
        for element in self {
            if element.languagePair.asString() == languagePair.asString() {
                matching.append(element)
            }
        }
        
        return matching
    }
}

//==================================================//

/* MARK: - Date Extensions */

public extension Date {
    /* MARK: - Methods */
    
    func elapsedInterval() -> String {
        let interval = Core.currentCalendar!.dateComponents([.year, .month, .day, .hour, .minute], from: self, to: Date())
        
        if let yearsPassed = interval.year,
           yearsPassed > 0 {
            return "\(yearsPassed)y"
        } else if let monthsPassed = interval.month,
                  monthsPassed > 0 {
            return "\(monthsPassed)mo"
        } else if let daysPassed = interval.day,
                  daysPassed > 0 {
            return "\(daysPassed)d"
        } else if let hoursPassed = interval.hour,
                  hoursPassed > 0 {
            return "\(hoursPassed)h"
        } else if let minutesPassed = interval.minute,
                  minutesPassed > 0 {
            return "\(minutesPassed)m"
        }
        
        return "now"
    }
    
    ///Function that gets a nicely formatted date string from a provided Date.
    func formattedString() -> String {
        let distance = Date().distance(to: self)
        
        let formatter = DateFormatter()
        formatter.locale = RuntimeStorage.languageCode == "en" ? .current : Locale(identifier: RuntimeStorage.languageCode!)
        formatter.dateStyle = .short
        
        switch true {
        case Calendar.current.isDateInToday(self):
            return DateFormatter.localizedString(from: self, dateStyle: .none, timeStyle: .short)
        case Calendar.current.isDateInYesterday(self):
            return LocalizedString.yesterday
        case Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear) || distance >= -604_800:
            guard let dayOfWeek else { return formatter.string(from: self) }
            return dayOfWeek
        default:
            return formatter.string(from: self)
        }
    }
    
    func seconds(from date: Date) -> Int {
        return Core.currentCalendar!.dateComponents([.second], from: date, to: self).second ?? 0
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var comparator: Date {
        let calendar = Core.currentCalendar!
        return calendar.date(bySettingHour: 12, minute: 00, second: 00, of: calendar.startOfDay(for: self))!
    }
    
    var dayOfWeek: String? {
        switch Calendar.current.component(.weekday, from: self) {
        case 1:
            return LocalizedString.sunday
        case 2:
            return LocalizedString.monday
        case 3:
            return LocalizedString.tuesday
        case 4:
            return LocalizedString.wednesday
        case 5:
            return LocalizedString.thursday
        case 6:
            return LocalizedString.friday
        case 7:
            return LocalizedString.saturday
        default:
            return nil
        }
    }
}

//==================================================//

/* MARK: - Dictionary Extensions */

public extension Dictionary {
    mutating func switchKey(fromKey: Key, toKey: Key) {
        if let dictionaryEntry = removeValue(forKey: fromKey) {
            self[toKey] = dictionaryEntry
        }
    }
}

public extension Dictionary where Value: Equatable {
    func allKeys(forValue: Value) -> [Key] {
        return filter { $1 == forValue }.map { $0.0 }
    }
}

//==================================================//

/* MARK: - Float Extensions */

public extension Float {
    var durationString: String {
        var returnValue = "0:00"
        
        if self < 60 {
            returnValue = String(format: "0:%.02d", Int(self.rounded(.up)))
        } else if self < 3600 {
            returnValue = String(format: "%.02d:%.02d", Int(self / 60), Int(self) % 60)
        } else {
            let hours = Int(self / 3600)
            let remainingMinutesInSeconds = Int(self) - hours * 3600
            
            returnValue = String(format: "%.02d:%.02d:%.02d",
                                 hours,
                                 Int(remainingMinutesInSeconds / 60),
                                 Int(remainingMinutesInSeconds) % 60)
        }
        
        return returnValue
    }
}

//==================================================//

/* MARK: - Int Extensions */

public extension Int {
    /* MARK: - Methods */
    
    ///Returns a random integer value.
    func random(min: Int, max: Int) -> Int {
        return min + Int(arc4random_uniform(UInt32(max - min + 1)))
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var ordinalValue: String {
        var determinedSuffix = "th"
        
        switch self % 10 {
        case 1:
            determinedSuffix = "st"
        case 2:
            determinedSuffix = "nd"
        case 3:
            determinedSuffix = "rd"
        default: ()
        }
        
        if (self % 100) > 10 && (self % 100) < 20 {
            determinedSuffix = "th"
        }
        
        return String(self) + determinedSuffix
    }
}

//==================================================//

/* MARK: - Sequence Extensions */

public extension Sequence where Iterator.Element: Hashable {
    func unique() -> [Iterator.Element] {
        var seen = Set<Iterator.Element>()
        
        return filter { seen.insert($0).inserted }
    }
}

//==================================================//

/* MARK: - String Extensions */

public extension String {
    /* MARK: - Methods */
    
    func asLanguagePair() -> LanguagePair? {
        let components = self.components(separatedBy: "-")
        
        guard components.count > 1 else { return nil }
        
        return LanguagePair(from: components[0],
                            to: components[1...components.count - 1].joined(separator: "-"))
    }
    
    func attributed(mainAttributes: [NSAttributedString.Key: Any],
                    alternateAttributes: [NSAttributedString.Key: Any],
                    alternateAttributeRange: [String]) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: self, attributes: mainAttributes)
        
        for string in alternateAttributeRange {
            let currentRange = (self as NSString).range(of: (string as NSString) as String)
            
            attributedString.addAttributes(alternateAttributes, range: currentRange)
        }
        
        return attributedString
    }
    
    func ciphered(by modifier: Int) -> String {
        var shiftedCharacters = [Character]()
        
        for utf8Value in utf8 {
            let shiftedValue = Int(utf8Value) + modifier
            
            let wrapAroundBy = shiftedValue > 97 + 25 ? -26 : (shiftedValue < 97 ? 26 : 0)
            
            shiftedCharacters.append(Character(UnicodeScalar(shiftedValue + wrapAroundBy)!))
        }
        
        return String(shiftedCharacters)
    }
    
    func containsAnyCharacter(in: String) -> Bool {
        var count = 0
        
        for find in `in`.map({ String($0) }) {
            count += map { String($0) }.filter { $0 == find }.count
        }
        
        return count != 0
    }
    
    func dropPrefix(_ dropping: Int = 1) -> String {
        guard count > dropping else { return "" }
        return String(suffix(from: index(startIndex, offsetBy: dropping)))
    }
    
    func dropSuffix(_ dropping: Int = 1) -> String {
        guard count > dropping else { return "" }
        return String(prefix(count - dropping))
    }
    
    func isAny(in: [String]) -> Bool {
        for value in `in` {
            if self == value {
                return true
            }
        }
        
        return false
    }
    
    func randomlyCapitalized(with modifider: Int) -> String? {
        var returnedString = ""
        var incrementCount = count
        
        for character in self {
            incrementCount = incrementCount - 1
            
            if ((modifider + incrementCount) % 2) == 0 {
                returnedString = returnedString + String(character).uppercased()
            } else {
                returnedString = returnedString + String(character).lowercased()
            }
            
            if incrementCount == 0 {
                return returnedString
            }
        }
        
        return nil
    }
    
    func removingOccurrences(of: [String]) -> String {
        var mutable = self
        
        for remove in of {
            mutable = mutable.replacingOccurrences(of: remove, with: "")
        }
        
        return mutable
    }
    
    func snakeCase() -> String {
        var characters = self.characterArray
        
        for (index, character) in characters.enumerated() {
            if character.isUppercase && character.isAlphabetical {
                characters[index] = "_\(character.lowercased())"
            }
        }
        
        return characters.joined()
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var alphabeticalPosition: Int {
        guard count == 1 else {
            Logger.log("String length is greater than 1.",
                       with: .fatalAlert,
                       metadata: [#file, #function, #line])
            return -1
        }
        
        let alphabetArray = Array("abcdefghijklmnopqrstuvwxyz")
        
        guard alphabetArray.contains(Character(lowercased())) else {
            Logger.log("The character is non-alphabetical.",
                       with: .fatalAlert,
                       metadata: [#file, #function, #line])
            return -1
        }
        
        return ((alphabetArray.firstIndex(of: Character(lowercased())))! + 1)
    }
    
    var asEnvironment: GeneralSerializer.Environment? {
        switch self.lowercased() {
        case "prod":
            return .production
        case "stage":
            return .staging
        case "dev":
            return .development
        default:
            return nil
        }
    }
    
    var characterArray: [String] {
        return map { String($0) }
    }
    
    var firstUppercase: String {
        return prefix(1).uppercased() + dropFirst()
    }
    
    var firstLowercase: String {
        return prefix(1).lowercased() + dropFirst()
    }
    
    var isAlphabetical: Bool {
        return "A"..."Z" ~= self || "a"..."z" ~= self
    }
    
    var isLowercase: Bool {
        return self == self.lowercased()
    }
    
    var isUppercase: Bool {
        return self == self.uppercased()
    }
    
    var isValidEmail: Bool {
        return NSPredicate(format: "SELF MATCHES[c] %@", "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Z]{1,4}$").evaluate(with: self)
    }
    
    var languageName: String? {
        guard self != "",
              self.lowercasedTrimmingWhitespace != "",
              let languageCodes = RuntimeStorage.languageCodeDictionary,
              let name = languageCodes[self] else { return nil }
        
        let components = name.components(separatedBy: " (")
        guard !components.isEmpty else { return name }
        return components[0]
    }
    
    var localizedLanguageName: String? {
        guard let localizedName = RegionDetailServer.localizedLanguageName(for: self) else { return nil }
        let components = localizedName.components(separatedBy: " (")
        guard !components.isEmpty else { return localizedName }
        return components[0].trimmingTrailingWhitespace
    }
    
    var lowercasedTrimmingWhitespace: String {
        return trimmingCharacters(in: .whitespacesAndNewlines).lowercased().trimmingWhitespace
    }
    
    var sanitized: String {
        removingOccurrences(of: ["*", "⌘"])
    }
    
    var trimmingBorderedWhitespace: String {
        return trimmingLeadingWhitespace.trimmingTrailingWhitespace
    }
    
    var trimmingLeadingWhitespace: String {
        var mutableSelf = self
        
        while mutableSelf.hasPrefix(" ") || mutableSelf.hasPrefix("\u{00A0}") {
            mutableSelf = mutableSelf.dropPrefix(1)
        }
        
        return mutableSelf
    }
    
    var trimmingTrailingWhitespace: String {
        var mutableSelf = self
        
        while mutableSelf.hasSuffix(" ") || mutableSelf.hasSuffix("\u{00A0}") {
            mutableSelf = mutableSelf.dropSuffix(1)
        }
        
        return mutableSelf
    }
    
    var trimmingWhitespace: String {
        return replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00A0}", with: "")
    }
}

//==================================================//

/* MARK: - UIColor Extensions */

public extension UIColor {
    private convenience init(red: Int, green: Int, blue: Int, alpha: CGFloat = 1.0) {
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: alpha)
    }
    
    /**
     Creates a color object using the specified RGB/hexadecimal code.
     
     - Parameter rgb: A hexadecimal integer.
     - Parameter alpha: The opacity of the color, from 0.0 to 1.0.
     */
    convenience init(rgb: Int, alpha: CGFloat = 1.0) {
        self.init(red: (rgb >> 16) & 0xFF, green: (rgb >> 8) & 0xFF, blue: rgb & 0xFF, alpha: alpha)
    }
    
    /**
     Creates a color object using the specified hexadecimal code.
     
     - Parameter hex: A hexadecimal integer.
     */
    convenience init(hex: Int) {
        self.init(red: (hex >> 16) & 0xFF, green: (hex >> 8) & 0xFF, blue: hex & 0xFF, alpha: 1.0)
    }
}

//==================================================//

/* MARK: - UIImageView Extensions */

public extension UIImageView {
    func downloadedFrom(_ link: String, contentMode mode: UIView.ContentMode = .scaleAspectFit) {
        guard let url = URL(string: link) else {
            return
        }
        
        downloadedFrom(url: url, contentMode: mode)
    }
    
    func downloadedFrom(url: URL, contentMode mode: UIView.ContentMode = .scaleAspectFill) {
        contentMode = mode
        
        URLSession.shared.dataTask(with: url) { privateRetrievedData, privateUrlResponse, privateOccurredError in
            
            guard let urlResponse = privateUrlResponse as? HTTPURLResponse, urlResponse.statusCode == 200,
                  let mimeType = privateUrlResponse?.mimeType, mimeType.hasPrefix("image"),
                  let retrievedData = privateRetrievedData, privateOccurredError == nil,
                  let retrievedImage = UIImage(data: retrievedData) else {
                DispatchQueue.main.async {
                    self.image = UIImage(named: "Not Found")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.image = retrievedImage
            }
            
        }.resume()
    }
}

//==================================================//

/* MARK: - UILabel Extensions */

public extension UILabel {
    /* MARK: - Methods */
    
    func fontSizeThatFits(_ alternateText: String?) -> CGFloat {
        if let labelText = alternateText ?? text {
            let frameToUse = (superview as? UIButton != nil ? superview!.frame : frame)
            
            let mutableCopy = UILabel(frame: frameToUse)
            mutableCopy.font = font
            mutableCopy.lineBreakMode = lineBreakMode
            mutableCopy.numberOfLines = numberOfLines
            mutableCopy.text = labelText
            
            var initialSize = mutableCopy.text!.size(withAttributes: [NSAttributedString.Key.font: mutableCopy.font!])
            
            while initialSize.width > mutableCopy.frame.size.width {
                let newSize = mutableCopy.font.pointSize - 0.5
                
                if newSize > 0.0 {
                    mutableCopy.font = mutableCopy.font.withSize(newSize)
                    
                    initialSize = mutableCopy.text!.size(withAttributes: [NSAttributedString.Key.font: mutableCopy.font!])
                } else {
                    return 0.0
                }
            }
            
            return mutableCopy.font.pointSize
        } else {
            return font.pointSize
        }
    }
    
    func scaleToMinimum(alternateText: String?, originalText: String?, minimumSize: CGFloat) {
        if let labelText = originalText ?? text {
            if textWillFit(alternate: labelText, minimumSize: minimumSize) {
                font = font.withSize(fontSizeThatFits(labelText))
            } else {
                guard let labelText = alternateText else {
                    Logger.log("Original string didn't fit, no alternate provided.",
                               metadata: [#file, #function, #line])
                    return
                }
                
                guard textWillFit(alternate: labelText, minimumSize: minimumSize) else {
                    Logger.log("Neither the original nor alternate strings fit.",
                               metadata: [#file, #function, #line])
                    return
                }
                
                font = font.withSize(fontSizeThatFits(labelText))
            }
        }
    }
    
    func textWillFit(alternate: String?, minimumSize: CGFloat) -> Bool {
        return fontSizeThatFits(alternate) >= minimumSize
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var isTruncated: Bool {
        guard let labelText = text as NSString? else {
            return false
        }
        
        let contentSize = labelText.size(withAttributes: [.font: font!])
        
        return contentSize.width > bounds.width
    }
}

//==================================================//

/* MARK: - UITextView Extensions */

public extension UITextView {
    func fontSizeThatFits(_ alternateText: String?) -> CGFloat {
        if let labelText = alternateText ?? text {
            let frameToUse = (superview as? UIButton != nil ? superview!.frame : frame)
            
            let mutableCopy = UILabel(frame: frameToUse)
            mutableCopy.font = font
            mutableCopy.text = labelText
            
            var initialSize = mutableCopy.text!.size(withAttributes: [NSAttributedString.Key.font: mutableCopy.font!])
            
            while initialSize.width > mutableCopy.frame.size.width {
                let newSize = mutableCopy.font.pointSize - 0.5
                
                if newSize > 0.0 {
                    mutableCopy.font = mutableCopy.font.withSize(newSize)
                    
                    initialSize = mutableCopy.text!.size(withAttributes: [NSAttributedString.Key.font: mutableCopy.font!])
                } else {
                    return 0.0
                }
            }
            
            return mutableCopy.font.pointSize
        } else {
            return font!.pointSize
        }
    }
    
    func scaleToMinimum(alternateText: String?, originalText: String?, minimumSize: CGFloat) {
        if let labelText = originalText ?? text {
            if textWillFit(alternate: labelText, minimumSize: minimumSize) {
                font = font!.withSize(fontSizeThatFits(labelText))
            } else {
                guard let labelText = alternateText else { return }
                
                guard textWillFit(alternate: labelText, minimumSize: minimumSize) else {
                    Logger.log("Neither the original nor alternate strings fit.",
                               metadata: [#file, #function, #line])
                    return
                }
                
                font = font!.withSize(fontSizeThatFits(labelText))
            }
        }
    }
    
    func textWillFit(alternate: String?, minimumSize: CGFloat) -> Bool {
        return fontSizeThatFits(alternate) >= minimumSize
    }
}

//==================================================//

/* MARK: - UIView Extensions */

public extension UIView {
    /* MARK: - Methods */
    
    func addBlur(withActivityIndicator: Bool, withStyle: UIBlurEffect.Style, withTag: Int, alpha: CGFloat) {
        let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: withStyle))
        
        blurEffectView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        blurEffectView.frame = bounds
        blurEffectView.tag = withTag
        blurEffectView.alpha = alpha
        
        addSubview(blurEffectView)
        
        if withActivityIndicator {
            let activityIndicatorView = UIActivityIndicatorView(style: .medium)
            activityIndicatorView.center = center
            activityIndicatorView.color = .white
            activityIndicatorView.startAnimating()
            activityIndicatorView.tag = Core.ui.nameTag(for: "BLUR_INDICATOR")
            addSubview(activityIndicatorView)
        }
    }
    
    func addOverlay(alpha: CGFloat = 1,
                    color: UIColor? = nil,
                    showsActivityIndicator: Bool = false,
                    tag: Int? = nil) {
        let overlayView = UIView(frame: bounds)
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.backgroundColor = color ?? .black
        overlayView.tag = tag ?? Core.ui.nameTag(for: "OVERLAY_VIEW")
        overlayView.alpha = alpha
        
        addSubview(overlayView)
        
        guard showsActivityIndicator else { return }
        
        let indicatorView = UIActivityIndicatorView(style: .large)
        indicatorView.center = center
        indicatorView.color = .white
        indicatorView.startAnimating()
        indicatorView.tag = Core.ui.nameTag(for: "ACTIVITY_INDICATOR")
        addSubview(indicatorView)
    }
    
    /**
     Adds a shadow border around the view.
     
     - Parameter backgroundColor: The shadow border's desired background color.
     - Parameter borderColor: The shadow border's desired border color.
     - Parameter withFrame: An optional specifying an alternate frame to add the shadow to.
     - Parameter withTag: The tag to associate with the shadow border.
     */
    func addShadowBorder(backgroundColor: UIColor, borderColor: CGColor, withFrame: CGRect?, withTag: Int) {
        let borderFrame = UIView(frame: withFrame ?? frame)
        
        borderFrame.backgroundColor = backgroundColor
        
        borderFrame.layer.borderColor = borderColor
        borderFrame.layer.borderWidth = 2
        
        borderFrame.layer.cornerRadius = 10
        borderFrame.layer.masksToBounds = false
        
        borderFrame.layer.shadowColor = borderColor
        borderFrame.layer.shadowOffset = CGSize(width: 0, height: 4)
        borderFrame.layer.shadowOpacity = 1
        
        borderFrame.tag = withTag
        
        addSubview(borderFrame)
        sendSubviewToBack(borderFrame)
    }
    
    func removeBlur(withTag: Int) {
        for indivdualSubview in subviews {
            if indivdualSubview.tag == withTag || indivdualSubview.tag == Core.ui.nameTag(for: "BLUR_INDICATOR") {
                UIView.animate(withDuration: 0.2, animations: {
                    indivdualSubview.alpha = 0
                }) { _ in
                    indivdualSubview.removeFromSuperview()
                }
            }
        }
    }
    
    func removeOverlay(tag: Int? = nil, animated: Bool = true) {
        let tag = tag ?? Core.ui.nameTag(for: "OVERLAY_VIEW")
        let activityIndicatorTag = Core.ui.nameTag(for: "ACTIVITY_INDICATOR")
        
        guard let overlayView = subview(tag),
              let activityIndicatorView = subview(activityIndicatorTag) else { return }
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.2) {
                overlayView.alpha = 0
                activityIndicatorView.alpha = 0
            } completion: { _ in
                overlayView.removeFromSuperview()
                activityIndicatorView.removeFromSuperview()
            }
        }
    }
    
    /**
     Removes a subview for a given tag, if it exists.
     
     - Parameter withTag: The tag of the view to remove.
     */
    func removeSubview(_ withTag: Int, animated: Bool) {
        for individualSubview in subviews {
            if individualSubview.tag == withTag {
                DispatchQueue.main.async {
                    if animated {
                        UIView.animate(withDuration: 0.2, animations: {
                            individualSubview.alpha = 0
                        }) { _ in
                            individualSubview.removeFromSuperview()
                        }
                    } else {
                        individualSubview.removeFromSuperview()
                    }
                }
            }
        }
    }
    
    ///Sets the background image on a UIView.
    func setBackground(withImageNamed: String!) {
        UIGraphicsBeginImageContext(frame.size)
        
        UIImage(named: withImageNamed)?.draw(in: bounds)
        
        let imageToSet: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        
        UIGraphicsEndImageContext()
        
        backgroundColor = UIColor(patternImage: imageToSet)
    }
    
    func subview(for string: String) -> UIView? {
        for view in subviews {
            if view.tag == Core.ui.nameTag(for: string) {
                return view
            }
        }
        
        return nil
    }
    
    func subviews(for string: String) -> [UIView] {
        var matches = [UIView]()
        
        for view in subviews {
            if view.tag == Core.ui.nameTag(for: string) {
                matches.append(view)
            }
        }
        
        return matches
    }
    
    /**
     Attempts to find a subview for a given tag.
     
     - Parameter forTag: The tag by which to search for the view.
     */
    func subview(_ forTag: Int) -> UIView? {
        for individualSubview in subviews {
            if individualSubview.tag == forTag {
                return individualSubview
            }
        }
        
        return nil
    }
    
    /**
     Attempts to find a subview for a given tag.
     
     - Parameter forTag: The tag by which to search for the view.
     */
    func subviews(_ forTag: Int) -> [UIView]? {
        var matchingSubviews = [UIView]()
        
        for individualSubview in subviews {
            if individualSubview.tag == forTag {
                matchingSubviews.append(individualSubview)
            }
        }
        
        return !matchingSubviews.isEmpty ? matchingSubviews : nil
    }
    
    //--------------------------------------------------//
    
    /* MARK: - Variables */
    
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        
        while parentResponder != nil {
            parentResponder = parentResponder?.next
            
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        
        return nil
    }
}

//==================================================//

/* MARK: - View Extensions */

public extension View {
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}
