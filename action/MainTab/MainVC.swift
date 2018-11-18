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

fileprivate struct ArtWorkInfo {
    var isPrefetched: Bool = false
    var isFullArtwork: Bool = false
    var artist: CKRecord? = nil
    var artwork: CKRecord? = nil
    var likes: [CKRecord]? = nil
    var reviews: [CKRecord]? = nil
}

class MainVC: UIViewController, UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching {
    
    var userID: CKRecord.ID? = nil
    var selectedRow: Int? = nil
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    private var artworkRecords: [ArtWorkInfo] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    var isFetchingData: Bool = false
    var refreshControl = UIRefreshControl()
    @IBOutlet weak var tableView: UITableView!
    
    func reloadVisibleRow(_ row: Int) {
        let indexPath = IndexPath(row: row, section: 0)
        if artworkRecords[row].artist != nil && artworkRecords[row].isFullArtwork && artworkRecords[row].likes != nil && artworkRecords[row].reviews != nil {
                if tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false {
                    tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
    }
    
    func queryArtworkOtherInfo(_ row: Int)
    {
        guard let artworkRecord = artworkRecords[row].artwork else {
            return
        }

        if artworkRecords[row].isPrefetched == true {
            return
        }
        artworkRecords[row].isPrefetched = true
        
        var likes: [CKRecord] = []
        var reviews: [CKRecord] = []

        if let artistID = artworkRecord.creatorUserRecordID {
            let fetchArtistOp = CKFetchRecordsOperation(recordIDs: [artistID])
            fetchArtistOp.desiredKeys = ["avatarImage", "nickName"]
            fetchArtistOp.fetchRecordsCompletionBlock = { (recordsByRecordID, error) in
                guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
                
                DispatchQueue.main.async {
                    self.artworkRecords[row].artist = recordsByRecordID?[artistID]
                    self.reloadVisibleRow(row)
                }
            }
            fetchArtistOp.database = self.database
            self.operationQueue.addOperation(fetchArtistOp)
        }
        
        let query = CKQuery(recordType: "Like", predicate: NSPredicate(format: "artwork = %@", artworkRecord.recordID))
        let queryLikesOp = CKQueryOperation(query: query)
        queryLikesOp.desiredKeys = []
        queryLikesOp.resultsLimit = 10
        queryLikesOp.recordFetchedBlock = { (likeRecord) in
            likes.append(likeRecord)
        }
        queryLikesOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            DispatchQueue.main.async {
                self.artworkRecords[row].likes = likes
                self.reloadVisibleRow(row)
            }
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
            
            DispatchQueue.main.async {
                self.artworkRecords[row].reviews = reviews
                self.reloadVisibleRow(row)
            }
        }
        queryReviewsOp.database = self.database
        self.operationQueue.addOperation(queryReviewsOp)
        
        let fetchArtworkOp = CKFetchRecordsOperation(recordIDs: [artworkRecord.recordID])
        fetchArtworkOp.desiredKeys = ["title", "video"]
        fetchArtworkOp.fetchRecordsCompletionBlock = { (recordsByRecordID, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            if let artworkRecord = recordsByRecordID?[artworkRecord.recordID] {
                
                if let ckasset = artworkRecord["video"] as? CKAsset {
                    let savedURL = ckasset.fileURL.appendingPathExtension("mp4")
                    try? FileManager.default.moveItem(at: ckasset.fileURL, to: savedURL)
                    DispatchQueue.main.async {
                        self.artworkRecords[row].artwork = artworkRecord
                        self.artworkRecords[row].isFullArtwork = true
                        self.reloadVisibleRow(row)
                    }
                }
            }
            
        }
        fetchArtworkOp.database = self.database
        self.operationQueue.addOperation(fetchArtworkOp)
    }
    
    @IBAction func fetchData(_ sender: Any) {
        artworkRecords = []
        isFetchingData = true
        var tmpArtworkRecords:[ArtWorkInfo] = []
        
        var query: CKQuery
        if let userID = userID {
            query = CKQuery(recordType: "Artwork", predicate: NSPredicate(format: "creatorUserRecordID = %@", userID))
        } else {
            query = CKQuery(recordType: "Artwork", predicate: NSPredicate(value: true))
        }
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [byCreation]
        let queryArtworksOp = CKQueryOperation(query: query)
        
        queryArtworksOp.desiredKeys = []
        queryArtworksOp.resultsLimit = (selectedRow ?? 0) + 1
        queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
            var artWorkInfo = ArtWorkInfo()
            artWorkInfo.artwork = artworkRecord
            tmpArtworkRecords.append(artWorkInfo)
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
                self.artworkRecords.append(contentsOf: tmpArtworkRecords)
                self.isFetchingData = false
                self.tableView.reloadData()
                self.tableView.scrollToRow(at: IndexPath(row: self.selectedRow ?? 0, section: 0), at: .middle, animated: false)
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
        
        queryArtworkOtherInfo(indexPath.row)
        
        let playViewCell = cell as! MainViewCell
        
        playViewCell.likesLabel.text = "\(artworkRecords[indexPath.row].likes?.count ?? 0)"
        playViewCell.reviewsLabel.text = "\(artworkRecords[indexPath.row].reviews?.count ?? 0)"
        playViewCell.titleLabel.text = "\(artworkRecords[indexPath.row].artwork?["title"] ?? "")"
        
        if let artist = artworkRecords[indexPath.row].artist {
            if let avatarImageAsset = artist["avatarImage"] as? CKAsset {
                playViewCell.avatarV.image = UIImage(contentsOfFile: avatarImageAsset.fileURL.path)
            }
            if let nickName = artist["nickName"] as? String {
                playViewCell.nickNameLabel.text = "@\(nickName)"
            }
            
            if true {
                let surplus = artworkRecords.count - (indexPath.row + 1)
                
                if let cursor = cursor, !isFetchingData, surplus < 1 {
                    isFetchingData = true
                    
                    let recordsCountBefore = artworkRecords.count
                    var tmpArtworkRecords:[ArtWorkInfo] = []
                    
                    let queryArtworksOp = CKQueryOperation(cursor: cursor)
                    queryArtworksOp.desiredKeys = []
                    queryArtworksOp.resultsLimit = 1 - surplus
                    queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
                        var artWorkInfo = ArtWorkInfo()
                        artWorkInfo.artwork = artworkRecord
                        DispatchQueue.main.async {
                            tmpArtworkRecords.append(artWorkInfo)
                        }
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
                            self.artworkRecords.append(contentsOf: tmpArtworkRecords)
                            let indexPaths = (recordsCountBefore ..< self.artworkRecords.count).map {
                                IndexPath(row: $0, section: 0)
                            }
                            
                            self.isFetchingData = false
                            self.tableView.insertRows(at: indexPaths, with: .fade)
                            
                        }
                    }
                }
            }
        }
        
        playViewCell.url = (artworkRecords[indexPath.row].artwork?["video"] as? CKAsset)?.fileURL.appendingPathExtension("mp4")
        if let url = playViewCell.url {
            let playerItem = AVPlayerItem(url: url)
            playViewCell.player.replaceCurrentItem(with: playerItem)
            playViewCell.player.seek(to: .zero)
            playViewCell.player.play()
        }
        
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let playViewCell = cell as! MainViewCell
        
        playViewCell.likesLabel.text = ""
        playViewCell.reviewsLabel.text = ""
        playViewCell.titleLabel.text = ""
        playViewCell.nickNameLabel.text = "@代古拉"
        playViewCell.avatarV.image = #imageLiteral(resourceName: "avatar")
        playViewCell.url = nil
        
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
    
    // MARK: - UITableViewPrefetching
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            queryArtworkOtherInfo(indexPath.row)
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
        } else if segue.identifier == "artist segue" {
            if let userInfoVC = segue.destination as? UserInfoVC, let row = self.tableView.indexPathsForVisibleRows?.first?.row {
                userInfoVC.userID = artworkRecords[row].artwork?.creatorUserRecordID
            }
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "artist segue" {
            if let row = self.tableView.indexPathsForVisibleRows?.first?.row, let userID = userID, let creatorUserRecordID = artworkRecords[row].artwork?.creatorUserRecordID, creatorUserRecordID == userID {
                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: true)
                }
                return false
            }
        }
        
        return true
    }
    
    @IBAction func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
}
