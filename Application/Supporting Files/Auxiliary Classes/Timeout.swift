//
//  Timeout.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Third-party Frameworks */
import AlertKit

public class Timeout {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private var callback: (() -> Void)?
    private var metadata: [Any]?
    private var timer: Timer?
    
    //==================================================//
    
    /* MARK: - Constructor Methods */
    
    public init(after: Double,
                _ callback: @escaping () -> Void = {}) {
        self.callback = callback
        
        self.timer = Timer.scheduledTimer(timeInterval: after,
                                          target: self,
                                          selector: #selector(invoke),
                                          userInfo: nil,
                                          repeats: false)
    }
    
    public init(alertingAfter: Double,
                metadata: [Any],
                _ callback: @escaping () -> Void = {}) {
        self.callback = callback
        self.metadata = metadata
        self.timer = Timer.scheduledTimer(timeInterval: alertingAfter,
                                          target: self,
                                          selector: #selector(presentTimeoutAlert),
                                          userInfo: nil,
                                          repeats: false)
    }
    
    //==================================================//
    
    /* MARK: - Other Methods */
    
    public func cancel() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    //==================================================//
    
    /* MARK: - Private Methods */
    
    @objc private func invoke() {
        self.callback?()
        
        // Discard callback and timer.
        self.callback = nil
        self.timer = nil
    }
    
    @objc private func presentTimeoutAlert() {
        callback?()
        
        let message = LocalizedString.timedOut ?? "The operation timed out. Please try again later."
        let exception = Exception(message,
                                  metadata: metadata!)
        
        AKErrorAlert(error: exception.asAkError(),
                     shouldTranslate: [Build.isOnline ? .actions(indices: nil) : .none]).present()
    }
}
