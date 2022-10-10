//
//  ShakeGesture.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 26/09/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI
import UIKit

public struct DeviceShakeViewModifier: ViewModifier {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public let action: () -> Void
    
    //==================================================//
    
    /* MARK: - Functions */
    
    public func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}

//==================================================//

/* MARK: - Extensions */

/**/

/* MARK: - UIDevice */
public extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

/* MARK: - UIWindow */
public extension UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}

/* MARK: - View */
public extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
}
