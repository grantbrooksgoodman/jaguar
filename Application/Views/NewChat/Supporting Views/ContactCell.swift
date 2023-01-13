//
//  ContactCell.swift
//  Jaguar
//
//  Created by Grant Brooks Goodman on 21/11/2022.
//  Copyright © 2013-2022 NEOTechnica Corporation. All rights reserved.
//

/* First-party Frameworks */
import Foundation
import UIKit

public class ContactCell: UITableViewCell {
    
    //==================================================//
    
    /* MARK: - Properties */
    
    public lazy var nameLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: 30,
                                          y: 0,
                                          width: self.bounds.size.width,
                                          height: self.bounds.size.height))
        label.textColor = traitCollection.userInterfaceStyle == .dark ? .white : .black
        label.font = UIFont.systemFont(ofSize: 17)
        return label
    }()
    
    //==================================================//
    
    /* MARK: - Constructor Methods */
    
    public override init(style: UITableViewCell.CellStyle,
                         reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        addSubview(nameLabel)
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: topAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            nameLabel.rightAnchor.constraint(equalTo: rightAnchor),
            nameLabel.widthAnchor.constraint(equalTo: nameLabel.heightAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //==================================================//
    
    /* MARK: - Appearance Updating */
    
    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        self.nameLabel.textColor = traitCollection.userInterfaceStyle == .dark ? .white : .black
    }
}
