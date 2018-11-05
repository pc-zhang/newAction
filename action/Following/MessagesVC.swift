//
//  TCVodPlayViewController.swift
//  TXXiaoShiPinDemo
//
//  Created by zpc on 2018/9/24.
//  Copyright © 2018年 tencent. All rights reserved.
//


import UIKit
import AVFoundation
import CloudKit

class MessagesVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    
    // MARK: - Models
    
    var gifs : [CKAsset] = []
    @IBOutlet weak var collectionV: UICollectionView!
    
    // MARK: - ViewController Life Cycles
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionV.decelerationRate = .fast
        
        CKContainer.default().fetchUserRecordID { (recordID, error) in
            if (error != nil) {
                // Error handling for failed fetch from public database
            }
            else {
                guard let recordID = recordID else {
                    return
                }
                
                CKContainer.default().publicCloudDatabase.fetch(withRecordID: recordID) { (record, error) in
                    if (error != nil) {
                        // Error handling for failed fetch from public database
                    }
                    else {
                        guard let record = record, let gifs = record["gifs"] as? [CKAsset] else {
                            return
                        }
                        self.gifs = gifs
                        DispatchQueue.main.async {
                            self.collectionV.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return gifs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GifViewCell", for: indexPath)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.row < gifs.count {
            let imageData = try? Data(contentsOf: (gifs[indexPath.row] as CKAsset).fileURL)
            let advTimeGif = UIImage.gifImageWithData(imageData!)
            
            if let cell = cell as? GifViewCell {
                cell.imageV.image = advTimeGif
            }
        }
    }
    
}

