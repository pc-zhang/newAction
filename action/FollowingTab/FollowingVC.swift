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

class FollowingVC: UITableViewController {
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    var userRecord: CKRecord?
    var artworkRecords: [CKRecord] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    let refresh: UIRefreshControl = UIRefreshControl()
    var isFetchingData: Bool = false
    var artworkInfosDict: [CKRecord:[String:Any]] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.estimatedRowHeight = view.bounds.height
        
        refresh.addTarget(self, action: #selector(fetchData), for: .valueChanged)
        tableView.addSubview(refresh)
        fetchData()
    }
    
    @objc open func fetchData()  {
        artworkRecords = []
        refresh.endRefreshing()
        isFetchingData = true
        
        let query = CKQuery(recordType: "Artwork", predicate: NSPredicate(value: true))
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [byCreation]
        let queryArtworksOp = CKQueryOperation(query: query)
    
        queryArtworksOp.desiredKeys = ["video", "title"]
        queryArtworksOp.resultsLimit = 3
        queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
            if let ckasset = artworkRecord["video"] as? CKAsset {
                let savedURL = ckasset.fileURL.appendingPathExtension("mp4")
                try? FileManager.default.moveItem(at: ckasset.fileURL, to: savedURL)
            }
            
            self.artworkRecords.append(artworkRecord)
            
            self.queryArtworkOtherInfo(artworkRecord: artworkRecord)
        }
        queryArtworksOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            self.cursor = cursor
        }
        queryArtworksOp.database = self.database
        self.operationQueue.addOperation(queryArtworksOp)
    
        DispatchQueue.global().async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            DispatchQueue.main.async {
                self.isFetchingData = false
                self.tableView.reloadData()
            }
        }
        
    }
    
    // MARK: - UITableViewDelegate
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }()
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row >= artworkRecords.count {
            return
        }
        
        let artworkRecord = artworkRecords[indexPath.row]
        if let playViewCell = cell as? FollowingViewCell, let ckasset = artworkRecord["video"] as? CKAsset {
            playViewCell.url = ckasset.fileURL.appendingPathExtension("mp4")
            let playerItem = AVPlayerItem(url: playViewCell.url!)
            playViewCell.player.replaceCurrentItem(with: playerItem)
            playViewCell.player.seek(to: .zero)
            if let date = artworkRecord.creationDate {
                playViewCell.createTimeV.text = dateFormatter.string(from: date)
            }
            playViewCell.titleV.text = artworkRecord["title"] as? String
            
            let likesCount = (artworkInfosDict[artworkRecord]?["Likes"] as? [CKRecord])?.count ?? 0
            let reviewsCount = (artworkInfosDict[artworkRecord]?["Reviews"] as? [CKRecord])?.count ?? 0
            let sharesCount = 0
            playViewCell.likesAndReviews.text = "❤️\(likesCount)   💬\(reviewsCount)   🔗\(sharesCount)"
        }
    }
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let playViewCell = cell as? FollowingViewCell {
            playViewCell.player.pause()
            playViewCell.player.replaceCurrentItem(with: nil)
        }
    }
    
    
    // MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if cursor != nil || artworkRecords.count == 0 {
            return artworkRecords.count + 1
        } else {
            return artworkRecords.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var identifier: String
        
        if indexPath.row == artworkRecords.count, let cursor = cursor {
            identifier = "NextPageLoaderCell"
            if !isFetchingData {
                isFetchingData = true
                
                let recordsCountBefore = self.artworkRecords.count
            
                let queryArtworksOp = CKQueryOperation(cursor: cursor)
                queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
                    if let ckasset = artworkRecord["video"] as? CKAsset {
                        let savedURL = ckasset.fileURL.appendingPathExtension("mp4")
                        try? FileManager.default.moveItem(at: ckasset.fileURL, to: savedURL)
                    }
                    
                    self.artworkRecords.append(artworkRecord)
                    
                    self.queryArtworkOtherInfo(artworkRecord: artworkRecord)
                }
                queryArtworksOp.queryCompletionBlock = { (cursor, error) in
                    guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
                    self.cursor = cursor
                }
                queryArtworksOp.database = self.database
                self.operationQueue.addOperation(queryArtworksOp)
            
                DispatchQueue.global().async {
                    self.operationQueue.waitUntilAllOperationsAreFinished()
                    DispatchQueue.main.async {
                        let indexPaths = (recordsCountBefore ..< self.artworkRecords.count).map {
                            IndexPath(row: $0, section: 0)
                        }
                        
                        self.isFetchingData = false
                        if self.cursor == nil {
                            self.tableView.performBatchUpdates({
                                self.tableView.deleteRows(at: [IndexPath(row: recordsCountBefore, section: 0)], with: .fade)
                                self.tableView.insertRows(at: indexPaths, with: .fade)
                            }, completion: nil)
                        } else {
                            self.tableView.insertRows(at: indexPaths, with: .fade)
                        }
                        
                    }
                }
            }
        } else {
            identifier = FollowingViewCell.reuseIdentifier
        }
        
        if artworkRecords.count == 0 {
            identifier = "NextPageLoaderCell"
        }
        
        return tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        
    }
    
    func queryArtworkOtherInfo(artworkRecord: CKRecord)
    {
        artworkInfosDict[artworkRecord] = [:]
        var likes: [CKRecord] = []
        var reviews: [CKRecord] = []
        if let artistID = artworkRecord.creatorUserRecordID {
            let fetchArtistOp = CKFetchRecordsOperation(recordIDs: [artistID])
            fetchArtistOp.desiredKeys = ["avatarImage", "nickName"]
            fetchArtistOp.fetchRecordsCompletionBlock = { (recordsByRecordID, error) in
                guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
                
                self.artworkInfosDict[artworkRecord]?["artist"] = recordsByRecordID?[artistID]
            }
            fetchArtistOp.database = self.database
            self.operationQueue.addOperation(fetchArtistOp)
        }

        let query = CKQuery(recordType: "Like", predicate: NSPredicate(format: "artwork = %@", artworkRecord.recordID))
        let queryLikesOp = CKQueryOperation(query: query)
        queryLikesOp.resultsLimit = 10
        queryLikesOp.recordFetchedBlock = { (likeRecord) in
            likes.append(likeRecord)
        }
        queryLikesOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }

            self.artworkInfosDict[artworkRecord]?["Likes"] = likes
        }
        queryLikesOp.database = self.database
        self.operationQueue.addOperation(queryLikesOp)

        let reviewQuery = CKQuery(recordType: "Review", predicate: NSPredicate(format: "artwork = %@", artworkRecord.recordID))
        let queryReviewsOp = CKQueryOperation(query: reviewQuery)
        queryReviewsOp.resultsLimit = 10
        queryReviewsOp.recordFetchedBlock = { (reviewRecord) in
            reviews.append(reviewRecord)
        }
        queryReviewsOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }

            self.artworkInfosDict[artworkRecord]?["Reviews"] = reviews
        }
        queryReviewsOp.database = self.database
        self.operationQueue.addOperation(queryReviewsOp)
    }
    
}

