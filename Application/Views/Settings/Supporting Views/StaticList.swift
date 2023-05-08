//
//  StaticList.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 13/04/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import SwiftUI

public struct StaticList: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public var items: [StaticListItem]
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .center, spacing: 0) {
                List {
                    ForEach(0..<items.count, id: \.self, content: { index in
                        Button {
                            items[index].action()
                        } label: {
                            HStack {
                                items[index].imageData.image
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(7)
                                    .foregroundColor(items[index].imageData.color)
                                    .frame(width: 30, height: 30)
                                
                                Text(items[index].title)
                                    .foregroundColor(.titleTextColor)
                                    .padding(.leading, 5)
                                
                                Spacer()
                            }
                        }
                    })
                }
                .scrollDisabled(true)
                .onAppear {
                    proxy.scrollTo(0, anchor: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: (36.0 * CGFloat(items.count)) + (10 * CGFloat(items.count)))
    }
}

public struct StaticListItem {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    private(set) var action: (()->())
    private(set) var imageData: (image: Image, color: Color)
    private(set) var title: String
    
    //==================================================//
    
    /* MARK: - Constructor */
    
    public init(title: String,
                imageData: (image: Image, color: Color),
                action: @escaping () -> Void) {
        self.title = title
        self.imageData = imageData
        self.action = action
    }
}

