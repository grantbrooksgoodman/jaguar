//
//  SectionIndexTitleView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/10/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

public struct SectionIndexTitleView: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public let proxy: ScrollViewProxy
    public let titles: [String]
    
    @GestureState private var dragLocation: CGPoint = .zero
    @StateObject private var indexState = IndexTitleState()
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        VStack {
            ForEach(titles, id: \.self) { title in
                Text(title)
                    .foregroundColor(.blue)
                    .modifier(SizeModifier())
                    .onPreferenceChange(SizePreferenceKey.self) { indexState.titleSize = $0 }
                    .onTapGesture { proxy.scrollTo(title,
                                                   anchor: .top) }
            }
        }
        .gesture(DragGesture(minimumDistance: indexState.titleSize.height,
                             coordinateSpace: .named(titles.first))
            .updating($dragLocation) { value, state, _ in
                state = value.location
                scrollTo(location: state)
            })
    }
    
    //==================================================//
    
    /* MARK: - Functions */
    
    private func scrollTo(location: CGPoint) {
        guard indexState.titleSize.height > 0 else { return }
        
        let index = Int(location.y / indexState.titleSize.height)
        guard index >= 0 && index < titles.count,
              indexState.currentTitleIndex != index else { return }
        
        indexState.currentTitleIndex = index
        
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            /*withAnimation {*/ proxy.scrollTo(titles[indexState.currentTitleIndex],
                                               anchor: .top) /*}*/
        }
    }
    
}

private class IndexTitleState: ObservableObject {
    
    /* MARK: - Properties */
    
    public var currentTitleIndex = 0
    public var titleSize: CGSize = .zero
}

private struct SizeModifier: ViewModifier {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private var sizeView: some View {
        GeometryReader { geometry in
            Color.clear.preference(key: SizePreferenceKey.self, value: geometry.size)
        }
    }
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public func body(content: Content) -> some View {
        content.background(sizeView)
    }
}

private struct SizePreferenceKey: PreferenceKey {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public static var defaultValue: CGSize = .zero
    
    //==================================================//
    
    /* MARK: - Functions */
    
    public static func reduce(value: inout CGSize,
                              nextValue: () -> CGSize) {
        value = nextValue()
    }
}
