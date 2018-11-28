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
    var artwork: CKRecord? = nil
    var info: CKRecord? = nil
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
    var isAppearing: Bool = false
    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func swipeRight(_ sender: Any) {
        cancel(sender)
    }
    
    func reloadVisibleRow(_ row: Int) {
        let indexPath = IndexPath(row: row, section: 0)
        if artworkRecords[row].isFullArtwork && artworkRecords[row].info != nil {
                if tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false {
                    tableView.reloadRows(at: [indexPath], with: .fade)
                    
                    if isAppearing {
                        (tableView.visibleCells.first as? MainViewCell)?.player.play()
                    }
            }
        }
    }
    
    func queryFullArtwork(_ row: Int)
    {
        guard let artworkRecord = artworkRecords[row].artwork else {
            return
        }

        if artworkRecords[row].isPrefetched == true {
            return
        }
        artworkRecords[row].isPrefetched = true
        
        let fetchArtworkOp = CKFetchRecordsOperation(recordIDs: [artworkRecord.recordID])
        fetchArtworkOp.fetchRecordsCompletionBlock = { (recordsByRecordID, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            if let artworkRecord = recordsByRecordID?[artworkRecord.recordID] {
                
                if let ckasset = artworkRecord["video"] as? CKAsset {
                    let savedURL = ckasset.fileURL.appendingPathExtension("mov")
                    try? FileManager.default.moveItem(at: ckasset.fileURL, to: savedURL)
                    DispatchQueue.main.sync {
                        self.artworkRecords[row].artwork = artworkRecord
                        self.artworkRecords[row].isFullArtwork = true
                        self.reloadVisibleRow(row)
                    }
                }
            }
            
        }
        fetchArtworkOp.database = self.database
        self.operationQueue.addOperation(fetchArtworkOp)
        
        if let infoID = (artworkRecord["info"] as? CKRecord.Reference)?.recordID {
            let fetchInfoOp = CKFetchRecordsOperation(recordIDs: [infoID])
            fetchInfoOp.desiredKeys = ["seconds", "reviews", "chorus"]
            fetchInfoOp.fetchRecordsCompletionBlock = { (recordsByRecordID, error) in
                guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
                
                if let infoRecord = recordsByRecordID?[infoID] {
                    DispatchQueue.main.sync {
                        self.artworkRecords[row].info = infoRecord
                        self.reloadVisibleRow(row)
                    }
                }
            }
            fetchInfoOp.database = self.database
            self.operationQueue.addOperation(fetchInfoOp)
        }
    }
    
    @IBAction func fetchData(_ sender: Any) {
        artworkRecords = []
        operationQueue.cancelAllOperations()
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
        
        queryArtworksOp.desiredKeys = ["info", "nickName", "avatar", "title", "cover"]
        queryArtworksOp.resultsLimit = (selectedRow ?? 0) + 1
        queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
            var artWorkInfo = ArtWorkInfo()
            artWorkInfo.artwork = artworkRecord
            tmpArtworkRecords.append(artWorkInfo)
        }
        queryArtworksOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            self.cursor = cursor
            
            DispatchQueue.main.sync {
                self.artworkRecords.append(contentsOf: tmpArtworkRecords)
                self.isFetchingData = false
                self.tableView.reloadData()
                self.tableView.scrollToRow(at: IndexPath(row: self.selectedRow ?? 0, section: 0), at: .middle, animated: false)
                self.refreshControl.endRefreshing()
            }
        }
        queryArtworksOp.database = self.database
        self.operationQueue.addOperation(queryArtworksOp)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(type(of: self).fetchData(_:)), for: UIControl.Event.valueChanged)
        tableView.addSubview(refreshControl)
        
        fetchData(0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isAppearing = true
        (tableView.visibleCells.first as? MainViewCell)?.player.play()
    }
    
    override func viewDidLayoutSubviews() {
        tableView.rowHeight = tableView.bounds.height
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isAppearing = false
        for cell in tableView.visibleCells {
            (cell as? MainViewCell)?.player.pause()
        }
    }

    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        queryFullArtwork(indexPath.row)
        
        let playViewCell = cell as! MainViewCell
        let info = artworkRecords[indexPath.row].info
        let artwork = artworkRecords[indexPath.row].artwork
        
        playViewCell.secondsLabel.text = "\(info?["seconds"] ?? 0)"
        playViewCell.reviewsLabel.text = "\(info?["reviews"] ?? 0)"
        playViewCell.chorusLabel.text = "\(info?["chorus"] ?? 0)"
        playViewCell.titleLabel.text = "\(artwork?["title"] ?? "")"
        
        if let avatarImageAsset = artwork?["avatar"] as? CKAsset {
            playViewCell.avatarV.image = UIImage(contentsOfFile: avatarImageAsset.fileURL.path)
        }
        if let coverImageAsset = artwork?["cover"] as? CKAsset {
            playViewCell.coverV.image = UIImage(contentsOfFile: coverImageAsset.fileURL.path)
        }
        if let nickName = artwork?["nickName"] as? String {
            playViewCell.nickNameLabel.text = "@\(nickName)"
        }
        
        let surplus = artworkRecords.count - (indexPath.row + 1)
        if let cursor = cursor, !isFetchingData, surplus < 1 {
            isFetchingData = true
            
            let recordsCountBefore = artworkRecords.count
            var tmpArtworkRecords:[ArtWorkInfo] = []
            
            let queryArtworksOp = CKQueryOperation(cursor: cursor)
            queryArtworksOp.desiredKeys = ["info", "nickName", "avatar", "title", "cover"]
            queryArtworksOp.resultsLimit = 1 - surplus
            queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
                var artWorkInfo = ArtWorkInfo()
                artWorkInfo.artwork = artworkRecord
                DispatchQueue.main.sync {
                    tmpArtworkRecords.append(artWorkInfo)
                }
            }
            queryArtworksOp.queryCompletionBlock = { (cursor, error) in
                guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
                self.cursor = cursor
                
                DispatchQueue.main.sync {
                    self.artworkRecords.append(contentsOf: tmpArtworkRecords)
                    let indexPaths = (recordsCountBefore ..< self.artworkRecords.count).map {
                        IndexPath(row: $0, section: 0)
                    }
                    
                    self.isFetchingData = false
                    self.tableView.insertRows(at: indexPaths, with: .fade)
                }
            }
            queryArtworksOp.database = self.database
            self.operationQueue.addOperation(queryArtworksOp)
            
        }

        
        playViewCell.url = (artworkRecords[indexPath.row].artwork?["video"] as? CKAsset)?.fileURL.appendingPathExtension("mov")
        if let url = playViewCell.url {
            let playerItem = AVPlayerItem(url: url)
            playViewCell.player.replaceCurrentItem(with: playerItem)
            playViewCell.player.seek(to: .zero)
        }
        
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let playViewCell = cell as! MainViewCell
        
        playViewCell.secondsLabel.text = ""
        playViewCell.reviewsLabel.text = ""
        playViewCell.chorusLabel.text = ""
        playViewCell.titleLabel.text = ""
        playViewCell.nickNameLabel.text = "@卓别林"
        playViewCell.avatarV.image = #imageLiteral(resourceName: "avatar")
        playViewCell.url = nil
        playViewCell.coverV.image = nil
        
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
            queryFullArtwork(indexPath.row)
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
        } else if segue.identifier == "reviews segue", let row = self.tableView.indexPathsForVisibleRows?.first?.row {
            if let reviewsVC = (segue.destination as? UINavigationController)?.topViewController as? ReviewsVC {
                reviewsVC.artworkID = artworkRecords[row].artwork?.recordID
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


class MainViewCell: UITableViewCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.playerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(MainViewCell.tapPlayViewCell(_:))))
        
        playerView.player = player
    }
    
    @IBAction func tapPlayViewCell(_ sender: Any) {
        if player.rate == 0 {
            // Not playing forward, so play.
            if player.currentTime() == player.currentItem?.duration {
                // At end, so got back to begining.
                player.seek(to: .zero)
            }
            
            player.play()
        }
        else {
            // Playing, so pause.
            player.pause()
        }
        
    }
    
    // MARK: Properties
    @IBOutlet weak var coverV: UIImageView!
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var chorus: UIButton!
    @IBOutlet weak var avatarV: UIImageView!
    @IBOutlet weak var nickNameLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var secondsLabel: UILabel!
    @IBOutlet weak var reviewsLabel: UILabel!
    @IBOutlet weak var chorusLabel: UILabel!
    
    static let reuseIdentifier = "TCPlayViewCell"
    var player = AVPlayer()
    var url : URL?
}
