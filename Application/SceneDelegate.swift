//
//  SceneDelegate.swift
//  Application
//
//  Created by Grant Brooks Goodman on 23/04/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI
import UIKit

/* Third-party Frameworks */
import Firebase
import FirebaseDatabase

public class SceneDelegate: UIResponder, UIWindowSceneDelegate, UIGestureRecognizerDelegate {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    // UIWindows
    public var window: UIWindow?
    
    private var buildInfoOverlayWindow: UIWindow!
    private var expiryOverlayWindow: UIWindow!
    
    // Other
    private var scene: UIScene!
    private var touchTimer: Timer?
    
    //==================================================//
    
    /* MARK: - Scene Control Functions */
    
    public func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        
        UserTestingSerializer.shared.getRandomUserID { (returnedIdentifier,
                                                        errorDescriptor) in
            guard let identifier = returnedIdentifier else {
                Logger.log(errorDescriptor ?? "An unknown error occurred.",
                           metadata: [#file, #function, #line])
                return
            }
            
            RuntimeStorage.store(identifier, as: .currentUserID)
            self.connectScene(scene)
        }
    }
    
    public func sceneDidDisconnect(_: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }
    
    public func sceneDidBecomeActive(_: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }
    
    public func sceneWillResignActive(_: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }
    
    public func sceneWillEnterForeground(_: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }
    
    public func sceneDidEnterBackground(_: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    //==================================================//
    
    /* MARK: - Gesture Recognizer Functions */
    
    public func gestureRecognizer(_: UIGestureRecognizer, shouldReceive _: UITouch) -> Bool {
        touchTimer?.invalidate()
        touchTimer = nil
        
        UIView.animate(withDuration: 0.2, animations: {
            self.buildInfoOverlayWindow.alpha = 0.35
        }) { _ in
            if self.touchTimer == nil {
                self.touchTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.touchTimerAction), userInfo: nil, repeats: true)
            }
        }
        
        return false
    }
    
    @objc private func touchTimerAction() {
        UIView.animate(withDuration: 0.2, animations: {
            if self.touchTimer != nil {
                self.buildInfoOverlayWindow.alpha = 1
                
                self.touchTimer?.invalidate()
                self.touchTimer = nil
            }
        })
    }
    
    //==================================================//
    
    /* MARK: - Other Functions */
    
    private func connectScene(_ scene: UIScene) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = RouterView(viewRouter: ViewRouter())
        
        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
            
            let tapGesture = UITapGestureRecognizer(target: self, action: nil)
            tapGesture.delegate = self
            window.addGestureRecognizer(tapGesture)
            
            let bounds = UIScreen.main.bounds
            
            buildInfoOverlayWindow = UIWindow()
            buildInfoOverlayWindow.frame = CGRect(x: 0,
                                                  y: bounds.maxY - 100,
                                                  width: bounds.size.width,
                                                  height: 100)
            buildInfoOverlayWindow.rootViewController = UIHostingController(rootView: BuildInfoOverlayView())
            buildInfoOverlayWindow.isHidden = false
            buildInfoOverlayWindow.tag = Core.ui.nameTag(for: "buildInfoOverlayWindow")
            
            if Build.stage != .generalRelease {
                window.addSubview(buildInfoOverlayWindow)
            }
            
            if Build.expiryDate == Date().comparator,
               Build.stage != .generalRelease,
               Build.timebombActive
            {
                expiryOverlayWindow = UIWindow()
                expiryOverlayWindow.frame = CGRect(x: 0,
                                                   y: 0,
                                                   width: bounds.size.width,
                                                   height: bounds.size.height)
                expiryOverlayWindow.rootViewController = UIHostingController(rootView: ExpiryOverlayView())
                expiryOverlayWindow.isHidden = false
                expiryOverlayWindow.tag = Core.ui.nameTag(for: "expiryOverlayWindow")
                
                window.addSubview(self.expiryOverlayWindow)
            }
            
            RuntimeStorage.store(self.window!, as: .topWindow)
        }
    }
}
