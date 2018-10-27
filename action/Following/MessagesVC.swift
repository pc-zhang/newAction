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
    
    var works : [NSString] = []
    var isLoading: Bool = false
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
                        guard let record = record, let works = record["works"] as? [NSString] else {
                            return
                        }
                        self.works = works
                        DispatchQueue.main.async {
                            self.collectionV.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return works.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlayerViewCell", for: indexPath)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.row < works.count {
            let playerItem = AVPlayerItem(url: URL(string: works[indexPath.row] as String)!)
            if let cell = cell as? PlayerViewCell {
                cell.player.replaceCurrentItem(with: playerItem)
                cell.player.seek(to: .zero)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? PlayerViewCell {
            cell.player.pause()
            cell.player.replaceCurrentItem(with: nil)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//        if let cell = pagerView.collectionView.visibleCells[1] as? FSPagerViewCell {
//            cell.player.play()
//        }
//        if let cell = pagerView.collectionView.visibleCells[0] as? FSPagerViewCell {
//            cell.player.pause()
//        }
//        if let cell = pagerView.collectionView.visibleCells[2] as? FSPagerViewCell {
//            cell.player.pause()
//        }
    }
    
}

