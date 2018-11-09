//
//  UserInfoVC.swift
//  NIM
//
//  Created by zpc on 2018/10/16.
//  Copyright © 2018年 Netease. All rights reserved.
//

import Foundation
import CloudKit
import UIKit

class UserInfoVC : UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    lazy var spinner: UIActivityIndicatorView = {
        return UIActivityIndicatorView(style: .gray)
    }()
    

    var userRecordID: CKRecord.ID?
    
    
    private var userCacheOrNil: UserLocalCache? {
        return (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self, selector: #selector(type(of:self).userCacheDidChange(_:)),
            name: .userCacheDidChange, object: nil)
        view.addSubview(spinner)
        view.bringSubviewToFront(spinner)
        spinner.hidesWhenStopped = true
        spinner.color = .blue
//        spinner.startAnimating()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        spinner.center = CGPoint(x: view.frame.size.width / 2,
                                 y: view.frame.size.height / 2)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func userCacheDidChange(_ notification: Notification) {
        
        self.collectionView.reloadData()
        
        spinner.stopAnimating()
    }
    
    @IBAction func done(bySegue: UIStoryboardSegue) {
        if bySegue.identifier == "" {
//            saveRecord()
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerV = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "UserInfo Header", for: indexPath)
        if let userCache = userCacheOrNil, let headerV = headerV as? UserInfoHeaderV {
            userCache.performReaderBlockAndWait {
                if let imagePath = userCache.avatarImage?.fileURL.path {
                    let advTimeGif = UIImage(contentsOfFile: imagePath)
                    headerV.avatarV.image = advTimeGif
                }

                headerV.nickNameV.text = userCache.nickName
                headerV.signV.text = userCache.sign
            }
            
        }
        return headerV
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 2
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GifViewCell", for: indexPath)
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let gifs = userCacheOrNil?.gifs else {
            return
        }
        if indexPath.row < gifs.count {
            let imageData = try? Data(contentsOf: (gifs[indexPath.row] as CKAsset).fileURL)
            let advTimeGif = UIImage.gifImageWithData(imageData!)
            
            if let cell = cell as? GifViewCell {
                cell.imageV.image = advTimeGif
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellWidth = (collectionView.bounds.width - 10) / 3
        return CGSize(width: cellWidth, height: cellWidth / 9.0 * 16)
    }
    
}


class GifViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageV: UIImageView!
    
}

class UserInfoHeaderV: UICollectionReusableView {
    
    @IBOutlet weak var avatarV: UIImageView! {
        didSet {
            avatarV.contentMode = .scaleAspectFill
            avatarV.layer.cornerRadius = avatarV.bounds.width/10
            avatarV.layer.masksToBounds = true
            avatarV.layer.borderColor = #colorLiteral(red: 0.3529411765, green: 0.3450980392, blue: 0.4235294118, alpha: 1)
            avatarV.layer.borderWidth = 1
        }
    }
    
    @IBOutlet weak var nickNameV: UILabel!
    @IBOutlet weak var idV: UILabel!
    @IBOutlet weak var friendsV: UILabel!
    @IBOutlet weak var signV: UILabel!
    @IBOutlet weak var positionV: UILabel!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit() {
        
    }
}
