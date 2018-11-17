//
//  TCVodPlayViewController.swift
//  TXXiaoShiPinDemo
//
//  Created by zpc on 2018/9/24.
//  Copyright © 2018年 tencent. All rights reserved.
//

import UIKit
import CloudKit
import AVFoundation

class MainVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    var userRecord: CKRecord?
    var artworkRecords: [CKRecord] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    var isFetchingData: Bool = false
    var isFirstFetched: Bool = false
    var artworkInfosDict: [CKRecord:[String:Any]] = [:]
    var refreshControl = UIRefreshControl()
    @IBOutlet weak var tableView: UITableView!
    
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
            
            self.artworkInfosDict[artworkRecord]?["likes"] = likes
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
            
            self.artworkInfosDict[artworkRecord]?["reviews"] = reviews
        }
        queryReviewsOp.database = self.database
        self.operationQueue.addOperation(queryReviewsOp)
    }
    
    @IBAction func fetchData(_ sender: Any) {
        artworkRecords = []
        isFetchingData = true
        
        let query = CKQuery(recordType: "Artwork", predicate: NSPredicate(value: true))
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [byCreation]
        let queryArtworksOp = CKQueryOperation(query: query)
        
        queryArtworksOp.desiredKeys = ["video", "title"]
        queryArtworksOp.resultsLimit = 1
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
                self.isFirstFetched = true
                self.tableView.reloadData()
            }
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(fetchData(_:)), for: UIControl.Event.valueChanged)
        tableView.addSubview(refreshControl)
        
        fetchData(0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        (tableView.visibleCells.first as? MainViewCell)?.player.play()
    }
    
    override func viewDidLayoutSubviews() {
        tableView.rowHeight = tableView.bounds.height
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        for cell in tableView.visibleCells {
            (cell as? MainViewCell)?.player.pause()
        }
    }

    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let playViewCell = cell as! MainViewCell
        let artworkRecord = artworkRecords[indexPath.row]
        
        if indexPath.row >= artworkRecords.count {
            return
        }
        
        let likesCount = (artworkInfosDict[artworkRecord]?["likes"] as? [CKRecord])?.count ?? 0
        let reviewsCount = (artworkInfosDict[artworkRecord]?["reviews"] as? [CKRecord])?.count ?? 0
        let sharesCount = 0
        
        playViewCell.likesLabel.text = "\(likesCount)"
        playViewCell.reviewsLabel.text = "\(reviewsCount)"
        
        if let artist = artworkInfosDict[artworkRecord]?["artist"] as? CKRecord {
            if let avatarImageAsset = artist["avatarImage"] as? CKAsset {
                playViewCell.avatarV.image = UIImage(contentsOfFile: avatarImageAsset.fileURL.path)
            }
            if let nickName = artist["nickName"] as? String {
                playViewCell.nickNameV.text = "@\(nickName)"
            }
        }
        
        playViewCell.url = (artworkRecords[indexPath.row]["video"] as? CKAsset)?.fileURL.appendingPathExtension("mp4")
        let playerItem = AVPlayerItem(url: playViewCell.url!)
        playViewCell.player.replaceCurrentItem(with: playerItem)
        playViewCell.player.seek(to: .zero)
        if isFirstFetched {
            playViewCell.player.play()
            isFirstFetched = false
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let playViewCell = cell as! MainViewCell
        
        playViewCell.player.pause()
        playViewCell.player.replaceCurrentItem(with: nil)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let tableView = scrollView as? UITableView {
            if let playViewCell = tableView.visibleCells.first as? MainViewCell {
                playViewCell.player.play()
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return artworkRecords.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let surplus = artworkRecords.count - (indexPath.row + 1)
        
        if let cursor = cursor, !isFetchingData, surplus < 2 {
            isFetchingData = true
            
            let recordsCountBefore = artworkRecords.count
            
            let queryArtworksOp = CKQueryOperation(cursor: cursor)
            queryArtworksOp.resultsLimit = 2 - surplus
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
                    self.tableView.insertRows(at: indexPaths, with: .fade)
                    
                }
            }
        }
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MainViewCell.reuseIdentifier, for: indexPath) as? MainViewCell else {
            fatalError("Expected `\(MainViewCell.self)` type for reuseIdentifier \(MainViewCell.reuseIdentifier). Check the configuration in Main.storyboard.")
        }
                
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "action segue" {
            if let actionVC = segue.destination as? ActionVC, let currentCell = self.tableView.visibleCells.first as? MainViewCell {
                actionVC.url = currentCell.url
                currentCell.player.pause()
            }
        }
    }
    
    @IBAction func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
}
