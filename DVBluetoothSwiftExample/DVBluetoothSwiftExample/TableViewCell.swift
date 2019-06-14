//
//  TableViewCell.swift
//  DVBluetoothSwiftExample
//
//  Created by 何定飞 on 2019/6/13.
//  Copyright © 2019 Devine.cn. All rights reserved.
//

import UIKit

class TableViewCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var uuidLbl: UILabel!
    @IBOutlet weak var servicesLbl: UILabel!
    @IBOutlet weak var rssiLbl: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}
