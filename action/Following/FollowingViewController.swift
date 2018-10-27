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

class FollowingViewController: UIViewController, FSPagerViewDataSource, FSPagerViewDelegate {
    
    // MARK: - Models
    
    var works : [NSString] = []
    var isLoading: Bool = false
    
    // MARK: - ViewController Life Cycles
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
                            self.pagerView.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let index = self.typeIndex
        self.typeIndex = index // Manually trigger didSet
    }
    
    fileprivate let imageNames = ["1.jpg","2.jpg","3.jpg","4.jpg","5.jpg","6.jpg","7.jpg"]
    fileprivate let transformerNames = ["coverflow"]
    fileprivate let transformerTypes: [FSPagerViewTransformerType] = [.coverFlow]
    fileprivate var typeIndex = 0 {
        didSet {
            let type = self.transformerTypes[typeIndex]
            self.pagerView.transformer = FSPagerViewTransformer(type:type)
            switch type {
            case .crossFading, .zoomOut, .depth:
                self.pagerView.itemSize = FSPagerView.automaticSize
                self.pagerView.decelerationDistance = 1
            case .linear, .overlap:
                let transform = CGAffineTransform(scaleX: 0.6, y: 0.75)
                self.pagerView.itemSize = self.pagerView.frame.size.applying(transform)
                self.pagerView.decelerationDistance = FSPagerView.automaticDistance
            case .ferrisWheel, .invertedFerrisWheel:
                self.pagerView.itemSize = CGSize(width: 180, height: 140)
                self.pagerView.decelerationDistance = FSPagerView.automaticDistance
            case .coverFlow:
                self.pagerView.itemSize = CGSize(width: pagerView.bounds.width / 2.3, height: pagerView.bounds.width / 2.3 * 16.0 / 9.0)
                self.pagerView.decelerationDistance = FSPagerView.automaticDistance
            case .cubic:
                let transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                self.pagerView.itemSize = self.pagerView.frame.size.applying(transform)
                self.pagerView.decelerationDistance = 1
            }
        }
    }
    
    @IBOutlet weak var pagerView: FSPagerView! {
        didSet {
            self.pagerView.register(FSPagerViewCell.self, forCellWithReuseIdentifier: "cell")
            self.typeIndex = 0
        }
    }
    
    
    // MARK:- FSPagerViewDataSource
    
    public func numberOfItems(in pagerView: FSPagerView) -> Int {
        return works.count
    }
    
    public func pagerView(_ pagerView: FSPagerView, cellForItemAt index: Int) -> FSPagerViewCell {
        let cell = pagerView.dequeueReusableCell(withReuseIdentifier: "cell", at: index)
        return cell
    }
    
    func pagerView(_ pagerView: FSPagerView, didSelectItemAt index: Int) {
        pagerView.deselectItem(at: index, animated: true)
        pagerView.scrollToItem(at: index, animated: true)
    }
    
    func pagerView(_ pagerView: FSPagerView, willDisplay cell: FSPagerViewCell, forItemAt index: Int) {
        
        if index < works.count {
            let playerItem = AVPlayerItem(url: URL(string: works[index] as String)!)
            cell.player.replaceCurrentItem(with: playerItem)
            cell.player.seek(to: .zero)
        }
    }
    
    func pagerView(_ pagerView: FSPagerView, didEndDisplaying cell: FSPagerViewCell, forItemAt index: Int) {
        
        cell.player.pause()
        cell.player.replaceCurrentItem(with: nil)
    }
    
    func pagerViewDidEndDecelerating(_ pagerView: FSPagerView) {
        if let cell = pagerView.collectionView.visibleCells[1] as? FSPagerViewCell {
            cell.player.play()
        }
        if let cell = pagerView.collectionView.visibleCells[0] as? FSPagerViewCell {
            cell.player.pause()
        }
        if let cell = pagerView.collectionView.visibleCells[2] as? FSPagerViewCell {
            cell.player.pause()
        }
    }
    
}

