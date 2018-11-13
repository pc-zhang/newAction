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

class FollowingVC: UITableViewController, UITableViewDataSourcePrefetching {
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    var userRecord: CKRecord?
    var artworkRecords: [CKRecord] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    let refresh: UIRefreshControl = UIRefreshControl()
    
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
//        hideNoResultsView()
//        hideErrorView()
//        hideNoResultsLoadingView()
//        showNoResultsLoadingView()
        isFetchingData = true
        
        CKContainer.default().fetchUserRecordID { (recordID, error) in
            if let recordID = recordID {
                let query = CKQuery(recordType: "Artwork", predicate: NSPredicate(format: "artist = %@", recordID))
                let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
                query.sortDescriptors = [byCreation]
                let queryArtworksOp = CKQueryOperation(query: query)
                
                queryArtworksOp.desiredKeys = ["video"]
                queryArtworksOp.resultsLimit = 1
                queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
                    if let ckasset = artworkRecord["video"] as? CKAsset {
                        let savedURL = ckasset.fileURL.appendingPathExtension("mp4")
                        try? FileManager.default.moveItem(at: ckasset.fileURL, to: savedURL)
                    }
                    
                    self.artworkRecords.append(artworkRecord)
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
        }
    }
    
    // MARK: - UITableViewDelegate
    
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
        if cursor != nil {
            return artworkRecords.count + 1
        } else {
            return artworkRecords.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell
        
        if indexPath.row == artworkRecords.count, let cursor = cursor {
            cell = tableView.dequeueReusableCell(withIdentifier: "NextPageLoaderCell", for: indexPath)
            
            if !isFetchingData {
                isFetchingData = true
                
                let recordsCountBefore = self.artworkRecords.count
            
                let queryArtworksOp = CKQueryOperation(cursor: cursor)
            
                queryArtworksOp.desiredKeys = ["video"]
                queryArtworksOp.resultsLimit = 3
                queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
                    if let ckasset = artworkRecord["video"] as? CKAsset {
                        let savedURL = ckasset.fileURL.appendingPathExtension("mp4")
                        try? FileManager.default.moveItem(at: ckasset.fileURL, to: savedURL)
                    }
                    
                    self.artworkRecords.append(artworkRecord)
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
                            self.tableView.deleteRows(at: [IndexPath(row: recordsCountBefore, section: 0)], with: .automatic)
                        }
                        self.tableView.insertRows(at: indexPaths, with: .fade)
                    }
                }
            }
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: FollowingViewCell.reuseIdentifier, for: indexPath) as! FollowingViewCell
        }
        
        return cell
    }
    
    // MARK: - UITableViewPrefetch
    
    var isFetchingData: Bool = false
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        
//        var fetchingIndexPaths : [IndexPath] = []
//        for index in indexPaths {
//            if artworkRecords[index] == nil {
//                fetchingIndexPaths.append(index)
//            }
//        }
//        for index in fetchingIndexPaths {
//            artworkRecords[index] = CKRecord(recordType: "Artwork")
//        }
//
//        if firstFetch {
//            firstFetch = false
//            CKContainer.default().fetchUserRecordID { (recordID, error) in
//                if let recordID = recordID {
//                    let query = CKQuery(recordType: "Artwork", predicate: NSPredicate(format: "artist = %@", recordID))
//                    let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
//                    query.sortDescriptors = [byCreation]
//                    let queryArtworksOp = CKQueryOperation(query: query)
//
//                    queryArtworksOp.desiredKeys = ["video"]
//                    queryArtworksOp.resultsLimit = fetchingIndexPaths.count
//                    queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
//                        if let ckasset = artworkRecord["video"] as? CKAsset {
//                            let savedURL = ckasset.fileURL.appendingPathExtension("mp4")
//                            try? FileManager.default.moveItem(at: ckasset.fileURL, to: savedURL)
//                        }
//
//                        if let indexPath = fetchingIndexPaths.first {
//                            self.artworkRecords[indexPath] = artworkRecord
//                            fetchingIndexPaths.removeFirst()
//                        }
//                    }
//                    queryArtworksOp.queryCompletionBlock = { (cursor, error) in
//                        guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
//                        self.cursor = cursor
//                    }
//                    queryArtworksOp.database = self.database
//                    self.operationQueue.addOperation(queryArtworksOp)
//
//                    DispatchQueue.global().async {
//                        self.operationQueue.waitUntilAllOperationsAreFinished()
//                        DispatchQueue.main.async {
//                            self.tableView.reloadData()
//                        }
//                    }
//                }
//            }
//
//            return
//        }
//
//
//        if let cursor = cursor {
//            let queryArtworksOp = CKQueryOperation(cursor: cursor)
//
//            queryArtworksOp.desiredKeys = ["video"]
//            queryArtworksOp.resultsLimit = fetchingIndexPaths.count
//            queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
//                if let ckasset = artworkRecord["video"] as? CKAsset {
//                    let savedURL = ckasset.fileURL.appendingPathExtension("mp4")
//                    try? FileManager.default.moveItem(at: ckasset.fileURL, to: savedURL)
//                }
//
//                if let indexPath = fetchingIndexPaths.first {
//                    self.artworkRecords[indexPath] = artworkRecord
//                    fetchingIndexPaths.removeFirst()
//                }
//            }
//            queryArtworksOp.queryCompletionBlock = { (cursor, error) in
//                guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
//                self.cursor = cursor
//            }
//            queryArtworksOp.database = self.database
//            self.operationQueue.addOperation(queryArtworksOp)
//
//        }
        
    }
    
}

