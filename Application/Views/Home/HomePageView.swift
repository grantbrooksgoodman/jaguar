//
//  HomePageView.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 30/06/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

//==================================================//

/* MARK: - Views */

public struct HomePageView: View {
    @StateObject public var viewModel: HomePageViewModel
    @StateObject public var viewRouter: ViewRouter
    
    //==================================================//
    
    /* MARK: - Views */
    
    public var body: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.onAppear(perform: viewModel.load)
        case .loading:
            ProgressView("Loading...")
        case .loaded(let translations):
            NavigationView {
                List {
                    ForEach(0..<20, id: \.self, content: { i in
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 60))
                                .frame(width: 60, height: 60)
                                .cornerRadius(10)
                                //                                .overlay(Circle()
                                //                                            .stroke(Color.gray, lineWidth: 2))
                                .foregroundColor(Color.gray)
                            
                            VStack(alignment: .leading) {
                                Text("John Appleseed")
                                    .bold()
                                    .padding(.bottom, 0.1)
                                
                                Text("Lorem ipsum dolor sit er elit lamet, consectetaur cillium adipisicing pecu, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Nam liber te conscient to factor tum poen legum odioque civiuda.")
                                    .foregroundColor(.gray)
                                    .font(Font.system(size: 12))
                                    .padding(.top, 0.1)
                                    .lineLimit(2)
                                
                            }
                            
                            //NavigationLink("", destination: EmptyView())
                        }
                    })
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {}) {
                            Label("Compose", systemImage: "square.and.pencil")
                        }
                    }
                }
                .navigationBarTitle(translations["messages"]!.output)
            }
        case .failed(let errorDescriptor):
            Text(errorDescriptor)
        }
    }
}
