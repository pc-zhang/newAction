//
//  FollowingVC.swift
//  action
//
//  Created by zpc on 2018/11/10.
//  Copyright © 2018 zpc. All rights reserved.
//

import UIKit
import CloudKit

class FollowingVC : UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
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
        spinner.startAnimating()
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
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var artworksCount = 0
        userCacheOrNil?.performReaderBlockAndWait {
            artworksCount = userCacheOrNil!.artworkThumbnails.count
        }
        return artworksCount
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GifViewCell", for: indexPath)
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        var artworkGifs : [CKAsset]? = nil
        userCacheOrNil?.performReaderBlockAndWait {
            artworkGifs = userCacheOrNil!.artworkThumbnails
        }
        if let artworkGifs = artworkGifs, let imageData = try? Data(contentsOf: artworkGifs[indexPath.row].fileURL), let cell = cell as? GifViewCell {
            cell.imageV.image = UIImage.gifImageWithData(imageData)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellWidth = (collectionView.bounds.width - 2) / 3
        return CGSize(width: cellWidth, height: cellWidth / 3.0 * 4)
    }
    
}


