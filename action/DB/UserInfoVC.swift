//
//  UserInfoVC.swift
//  NIM
//
//  Created by zpc on 2018/10/16.
//  Copyright © 2018年 Netease. All rights reserved.
//

import Foundation
import CloudKit

class UserInfoVC : UIViewController {

    @IBOutlet weak var avatarV: UIImageView!
    @IBOutlet weak var nickNameV: UILabel!
    @IBOutlet weak var idV: UILabel!
    @IBOutlet weak var friendsV: UILabel!
    @IBOutlet weak var signV: UILabel!
    @IBOutlet weak var positionV: UILabel!
    
    override func viewDidLoad() {
        let publicDatabase = CKContainer.default().publicCloudDatabase
        let predicate = NSPredicate(format: "sign = %@", "Show must go on !")
        let query = CKQuery(recordType: "ActionUser", predicate: predicate)
        publicDatabase.perform(query, inZoneWith: nil) { (records, error) in
            if (error != nil) {
                // Error handling for failed fetch from public database
            }
            else {
                // Display the fetched records
                guard let records = records else {
                    return
                }
                if let record = records.first {
                    DispatchQueue.main.async {
                        self.avatarV.downloaded(from: record["avatarURL"] ?? "")
                        self.avatarV.layer.cornerRadius = 8
                        self.avatarV.layer.masksToBounds = true
                        self.avatarV.layer.borderColor = #colorLiteral(red: 0.3529411765, green: 0.3450980392, blue: 0.4235294118, alpha: 1)
                        self.avatarV.layer.borderWidth = 1
                        
                        self.nickNameV.text = record["nickName"]
//                        self.idV.text = record["nickName"]
//                        self.friendsV.text = record["nickName"]
                        self.signV.text = record["sign"]
                    }
                }
            }
        }
    }
}

extension UIImageView {
    func downloaded(from url: URL, contentMode mode: UIView.ContentMode = .scaleAspectFill) {
        contentMode = mode
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil,
                let image = UIImage(data: data)
                else { return }
            DispatchQueue.main.async() {
                self.image = image
            }
            }.resume()
    }
    func downloaded(from link: String, contentMode mode: UIView.ContentMode = .scaleAspectFill) {
        guard let url = URL(string: link) else { return }
        downloaded(from: url, contentMode: mode)
    }
}
