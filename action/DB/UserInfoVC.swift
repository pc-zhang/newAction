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

class UserInfoVC : SpinnerViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var userRecordID: CKRecord.ID?
    @IBOutlet weak var avatarV: UIImageView! {
        didSet {
            avatarV.layer.cornerRadius = 8
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
    @IBOutlet weak var collectionV: UICollectionView!
    
    private var userCacheOrNil: UserLocalCache? {
        return (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self, selector: #selector(type(of:self).userCacheDidChange(_:)),
            name: .userCacheDidChange, object: nil)
        spinner.startAnimating()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func userCacheDidChange(_ notification: Notification) {
        
        if let userCache = userCacheOrNil {
            userCache.performReaderBlockAndWait {
                if let imagePath = userCache.avatarURL?.path {
                    let advTimeGif = UIImage(contentsOfFile: imagePath)
                    self.avatarV.image = advTimeGif
                }
                
                self.nickNameV.text = userCache.nickName
                self.signV.text = userCache.sign
            }
            
            self.collectionV.reloadData()
        }
        
        spinner.stopAnimating()
    }
    
    @IBAction func done(bySegue: UIStoryboardSegue) {
        if bySegue.identifier == "" {
//            saveRecord()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return userCacheOrNil?.gifs.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GifViewCell", for: indexPath)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
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

class SpinnerViewController: UITableViewController {
    
    lazy var spinner: UIActivityIndicatorView = {
        return UIActivityIndicatorView(style: .gray)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(spinner)
        view.bringSubviewToFront(spinner)
        spinner.hidesWhenStopped = true
        spinner.color = .blue
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        spinner.center = CGPoint(x: view.frame.size.width / 2,
                                 y: view.frame.size.height / 2)
    }
}
