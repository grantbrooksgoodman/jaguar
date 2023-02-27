//
//  RegionMenu.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 09/07/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import SwiftUI

public struct RegionMenu: View {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    @Binding public var selectedRegion: String
    @State private var expanded = false
    
    //==================================================//
    
    /* MARK: - View Body */
    
    public var body: some View {
        ScrollViewReader { proxy in
            //            Menu {
            var mutableConversation = RegionDetailServer.regionTitleArray()
            let conversationBinding = Binding(get: { mutableConversation },
                                              set: { mutableConversation = $0 })
            Button {
                expanded.toggle()
            } label: {
                VStack {
                    Image(uiImage: RegionDetailServer.getImage(for: .regionCode,
                                                               with: selectedRegion) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30,
                           height: 30)
                    Text("+\(RuntimeStorage.callingCodeDictionary![selectedRegion] ?? "1")")
                        .multilineTextAlignment(.center)
                        .scaledToFill()
                }
            }
            .popover(isPresented: $expanded) {
                MyPicker(values: conversationBinding, selected: $selectedRegion, isExpanded: $expanded)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            //                        .foregroundColor(Color.black)
            //                Picker("\(RegionDetailServer.getRegionTitle(forRegionCode: selectedRegion).capitalized)",
            //                       selection: $selectedRegion) {
            //                    ForEach(RegionDetailServer.regionTitleArray().reversed(),
            //                            id: \.self) { title in
            //                        Button {
            //                            selectedRegion = RegionDetailServer.getRegionCode(forRegionTitle: title) ?? "US"
            //                        } label: {
            //                            HStack {
            //                                if let regionTitle = RegionDetailServer.getRegionTitle(forRegionCode: selectedRegion),
            //                                   title == regionTitle {
            //                                    Image(systemName: "checkmark.circle")
            //                                }
            //
            //                                Image(uiImage: RegionDetailServer.getImage(for: .regionTitle,
            //                                                                           with: title) ?? UIImage())
            //                                Text(title.components(separatedBy: "+")[0].trimmingBorderedWhitespace)
            //                            }
            //                        }
            //                    }
            //                }
            //            } label: {
            //                VStack {
            //                    Image(uiImage: RegionDetailServer.getImage(for: .regionCode,
            //                                                               with: selectedRegion) ?? UIImage())
            //                    .resizable()
            //                    .aspectRatio(contentMode: .fit)
            //                    .frame(width: 30,
            //                           height: 30)
            //                    Text("+\(RuntimeStorage.callingCodeDictionary![selectedRegion] ?? "1")")
            //                        .multilineTextAlignment(.center)
            //                        .scaledToFill()
            //                }
            //            }
            //            .multilineTextAlignment(.center)
            //            .background(RoundedRectangle(cornerRadius: 6)
            //                .foregroundColor(.white)
            //                .shadow(radius: 2)
            //                .padding(.all, -3))
            //            .onAppear(perform: {
            //                selectedRegion = RuntimeStorage.selectedRegionCode ?? Locale.current.regionCode ?? "US"
            //                //                proxy.scrollTo(selectedRegion, anchor: .bottom)
            //            })
            //            .pickerStyle(.menu)
        }
    }
}

struct MyPicker : View {
    
    @Namespace var namespace
    
    @Binding var values : [String]
    @Binding var selected : String
    @Binding var isExpanded : Bool
    
    var body: some View {
        if isExpanded {
            ScrollViewReader { proxy in
                Text("Select Region Code")
                    .font(Font.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity,
                           maxHeight: 44)
                    .background(Color(uiColor: UIColor(hex: 0xF8F8F8)))
                
                List(RegionDetailServer.regionTitleArray().reversed(),
                     id: \.self) { title in
                    Button {
                        selected = RegionDetailServer.getRegionCode(forRegionTitle: title) ?? "US"
                        isExpanded = false
                    } label: {
                        HStack {
                            Image(uiImage: RegionDetailServer.getImage(for: .regionTitle,
                                                                       with: title) ?? UIImage())
                            .resizable()
                            .frame(width: 40, height: 30)
                            .cornerRadius(5)
                            .aspectRatio(contentMode: .fit)
                            
                            Text(title)
                                .foregroundColor(.black)
                            
                            if let regionTitle = RegionDetailServer.getRegionTitle(forRegionCode: selected),
                               title == regionTitle {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .background(Color(uiColor: UIColor(hex: 0xF8F8F8)))
                    }
                    .background(Color(uiColor: UIColor(hex: 0xF8F8F8)))
                }.onAppear {
                    Core.gcd.after(milliseconds: 500) {
                        withAnimation {
                            proxy.scrollTo(RegionDetailServer.getRegionTitle(forRegionCode: selected), anchor: .top)
                        }
                    }
                }
                //                .listStyle(.plain)
                .padding(.top, -3)
            }
            
            //            List(values, id: \.self) { value in
            //
            //                Text("\(value)")
            //                    .foregroundColor(Color.black)
            //                    .contentShape(Rectangle())
            //                    .onTapGesture {
            //                        withAnimation {
            //                            selected = value
            //                            isExpanded.toggle()
            //                        }
            //                    }
            //
            //                    .listRowBackground(selected == value ? Color.green.opacity(0.3) : Color.white)
            //
            //
            //            }.matchedGeometryEffect(id: "menu", in: namespace)
        } else {
            EmptyView()
            //            VStack {
            //                Image(uiImage: RegionDetailServer.getImage(for: .regionCode,
            //                                                           with: selected) ?? UIImage())
            //                .resizable()
            //                .aspectRatio(contentMode: .fit)
            //                .frame(width: 30,
            //                       height: 30)
            //                Text("+\(RuntimeStorage.callingCodeDictionary![selected] ?? "1")")
            //                    .multilineTextAlignment(.center)
            //                    .scaledToFill()
            //            }
            //            Text("\(selected != "" ? selected : values.first!)").padding()
            //                .frame(maxWidth: .infinity, alignment: .leading)
            //
            //                .background(Rectangle().foregroundColor(.green.opacity(0.3)).cornerRadius(5))
            //                .matchedGeometryEffect(id: "menu", in: namespace)
            //                .foregroundColor(Color.black)
            //                .padding()
            
        }
        
    }
}
