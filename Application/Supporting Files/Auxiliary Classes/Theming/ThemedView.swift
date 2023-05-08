//
//  ThemedView.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import SwiftUI

public struct ThemedView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @ObservedObject private var colorProvider = ColorProvider.shared
    @State public var onAppearanceChange: (()->())? = nil
    public var reloadsForUpdates = false
    public var viewBody: (()->(any View))
    
    @State private var forceAppearanceUpdate = UUID()
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        AnyView(viewBody())
            .id(forceAppearanceUpdate)
            .onChange(of: colorProvider.currentThemeName) { _ in respondToAppearanceChange() }
            .onChange(of: colorProvider.interfaceStyle) { _ in respondToAppearanceChange() }
    }
    
    //==================================================//
    
    /* MARK: - Appearance Change Handler */
    
    private func respondToAppearanceChange() {
        colorProvider.updateColorState()
        Core.ui.setNavigationBarAppearance(backgroundColor: .navigationBarBackgroundColor, titleColor: .navigationBarTitleColor)
        
        onAppearanceChange?()
        
        guard reloadsForUpdates else { return }
        forceAppearanceUpdate = UUID()
    }
}

