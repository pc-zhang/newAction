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

class FollowingVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    var userRecord: CKRecord?
    var artworkRecords: [ArtWorkInfo] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    let refresh: UIRefreshControl = UIRefreshControl()
    var isFetchingData: Bool = false
    var artworkInfosDict: [CKRecord:[String:Any]] = [:]
    @IBOutlet weak var tableView: UITableView!
    
    override func awakeFromNib() {
//        tabBarItem.badgeValue = "3"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.estimatedRowHeight = view.bounds.height
        
        refresh.addTarget(self, action: #selector(fetchData), for: .valueChanged)
        tableView.addSubview(refresh)
        fetchData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        for cell in tableView.visibleCells {
            (cell as? FollowingViewCell)?.player.pause()
        }
    }
    
    @objc open func fetchData()  {
        artworkRecords = []
        operationQueue.cancelAllOperations()
        
        guard let myID = (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord?.recordID else {
            return
        }
        
        isFetchingData = true
        var followRecords:[CKRecord] = []
        
        let query = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "creatorUserRecordID = %@", myID))
        
        let queryFollowersOp = CKQueryOperation(query: query)
        
        queryFollowersOp.recordFetchedBlock = { (followRecord) in
            followRecords.append(followRecord)
        }
        queryFollowersOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            var tmpArtworkRecords:[ArtWorkInfo] = []
            
            var query = CKQuery(recordType: "ArtworkInfo", predicate: NSPredicate(format: "creatorUserRecordID in %@", followRecords.compactMap {($0["followed"] as? CKRecord.Reference)?.recordID}))
            let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
            query.sortDescriptors = [byCreation]
            
            let queryInfoOp = CKQueryOperation(query: query)
            queryInfoOp.resultsLimit = 6
            queryInfoOp.recordFetchedBlock = { (infoRecord) in
                var artWorkInfo = ArtWorkInfo()
                artWorkInfo.info = infoRecord
                tmpArtworkRecords.append(artWorkInfo)
            }
            queryInfoOp.queryCompletionBlock = { (cursor, error) in
                DispatchQueue.main.sync {
                    self.refresh.endRefreshing()
                }
                guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
                self.cursor = cursor
                
                DispatchQueue.main.sync {
                    self.artworkRecords.append(contentsOf: tmpArtworkRecords)
                    self.isFetchingData = false
                    self.tableView.reloadData()
                }
            }
            queryInfoOp.database = self.database
            self.operationQueue.addOperation(queryInfoOp)
        }
        queryFollowersOp.database = self.database
        operationQueue.addOperation(queryFollowersOp)
    }
    
    // MARK: - UITableViewDelegate
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }()
    
    func reloadVisibleRow(_ row: Int, type: Int) {
        let indexPath = IndexPath(row: row, section: 0)
        
        if tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false {
            switch(type) {
            case 0:
                if let secondsValue = artworkRecords[row].info?["seconds"] as? Int64 {
                    (tableView.cellForRow(at: indexPath) as? FollowingViewCell)?.secondsLabel.text = "\(secondsValue.seconds2String())"
                }
                if let reviewsValue = artworkRecords[row].info?["reviews"] as? Int64 {
                    (tableView.cellForRow(at: indexPath) as? FollowingViewCell)?.reviewsLabel.text = "\(reviewsValue)"
                }
                if let chorusValue = artworkRecords[row].info?["chorus"] as? Int64 {
                    (tableView.cellForRow(at: indexPath) as? FollowingViewCell)?.chorusLabel.text = "\(chorusValue)"
                }
            default:
                tableView.reloadRows(at: [indexPath], with: .none)
            }
        }
    }
    
    func queryFullArtwork(_ row: Int)
    {
        guard let infoRecord = artworkRecords[row].info else {
            return
        }
        
        if artworkRecords[row].isPrefetched == true {
            return
        }
        artworkRecords[row].isPrefetched = true
        
        let query = CKQuery(recordType: "Artwork", predicate: NSPredicate(format: "info = %@", infoRecord.recordID))
        
        let queryArtworkOp = CKQueryOperation(query: query)
        queryArtworkOp.desiredKeys = ["info", "nickName", "avatar", "title", "cover"]
        queryArtworkOp.recordFetchedBlock = { (artworkRecord) in
            DispatchQueue.main.sync {
                self.artworkRecords[row].artwork = artworkRecord
                self.reloadVisibleRow(row, type: 1)
            }
        }
        queryArtworkOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
        }
        queryArtworkOp.database = self.database
        self.operationQueue.addOperation(queryArtworkOp)
        
        
        let queryFullArtworkOp = CKQueryOperation(query: query)
        queryFullArtworkOp.desiredKeys = ["video"]
        queryFullArtworkOp.recordFetchedBlock = { (artworkRecord) in
            if let ckasset = artworkRecord["video"] as? CKAsset {
                let savedURL = ckasset.fileURL.appendingPathExtension("mov")
                try? FileManager.default.moveItem(at: ckasset.fileURL, to: savedURL)
                DispatchQueue.main.sync {
                    self.artworkRecords[row].artwork?["video"] = ckasset
                    self.reloadVisibleRow(row, type: 1)
                }
            }
        }
        queryFullArtworkOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
        }
        queryFullArtworkOp.database = self.database
        queryFullArtworkOp.addDependency(queryArtworkOp)
        self.operationQueue.addOperation(queryFullArtworkOp)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        queryFullArtwork(indexPath.row)
        
        let playViewCell = cell as! FollowingViewCell
        let infoRecord = artworkRecords[indexPath.row].info
        let artwork = artworkRecords[indexPath.row].artwork
        
        playViewCell.secondsLabel.text = "\((infoRecord?["seconds"] as? Int64 ?? 0).seconds2String())"
        playViewCell.reviewsLabel.text = "\(infoRecord?["reviews"] ?? 0)"
        playViewCell.chorusLabel.text = "\(infoRecord?["chorus"] ?? 0)"
        playViewCell.titleLabel.text = "\(artwork?["title"] ?? "")"
        playViewCell.titleLabel.sizeToFit()
        
        if let avatarImageAsset = artwork?["avatar"] as? CKAsset {
            playViewCell.avatarV.setImage(UIImage(contentsOfFile: avatarImageAsset.fileURL.path), for: .normal)
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
            queryArtworksOp.resultsLimit = 1 - surplus
            queryArtworksOp.recordFetchedBlock = { (infoRecord) in
                var artWorkInfo = ArtWorkInfo()
                artWorkInfo.info = infoRecord
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
                    self.tableView.insertRows(at: indexPaths, with: .none)
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
        guard let playViewCell = cell as? FollowingViewCell else {
            return
        }
        
        playViewCell.secondsLabel.text = ""
        playViewCell.reviewsLabel.text = ""
        playViewCell.chorusLabel.text = ""
        playViewCell.titleLabel.text = ""
        playViewCell.nickNameLabel.text = "@卓别林"
        playViewCell.avatarV.setImage(#imageLiteral(resourceName: "avatar"), for: .normal)
        playViewCell.url = nil
        playViewCell.coverV.image = nil
        playViewCell.progressV.progress = 0
        
        playViewCell.player.pause()
        playViewCell.player.replaceCurrentItem(with: nil)
    }
    
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return artworkRecords.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        return tableView.dequeueReusableCell(withIdentifier: FollowingViewCell.reuseIdentifier, for: indexPath)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "following to artist" {
            if let userInfoVC = segue.destination as? UserInfoVC, let row = tableView.indexPathsForVisibleRows?.first?.row {
                userInfoVC.userID = artworkRecords[row].info?.creatorUserRecordID
            }
        } else if segue.identifier == "following to reviews", let row = self.tableView.indexPathsForVisibleRows?.first?.row {
            if let reviewsVC = (segue.destination as? UINavigationController)?.topViewController as? ReviewsVC {
                reviewsVC.artworkID = artworkRecords[row].artwork?.recordID
                reviewsVC.infoRecord = artworkRecords[row].info
            }
        } else if segue.identifier == "following to chorus", let row = self.tableView.indexPathsForVisibleRows?.first?.row {
            if let chorusVC = segue.destination as? ChorusVC {
                chorusVC.artworkID = artworkRecords[row].artwork?.recordID
            }
        }
        
    }
    
}

class FollowingViewCell: UITableViewCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.playerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(MainViewCell.tapPlayViewCell(_:))))
        
        playerView.player = player
        
        let times = (1..<240).map {
            CMTime(seconds: Double($0)/4, preferredTimescale: 600) as NSValue
        }
        
        player.addBoundaryTimeObserver(forTimes: times, queue: nil, using: {
            let playerTime = self.player.currentTime()
            guard playerTime.isValid else {
                return
            }
            
            if Int(playerTime.seconds) % 10 == 0, Int(playerTime.seconds) == Int(playerTime.seconds+0.9) {
                self.delegate?.addSeconds(self)
            }
            if let duration = self.player.currentItem?.duration, duration.isValid {
                self.progressV.progress = Float(playerTime.seconds / duration.seconds)
            }
        })
        
    }
    
    @IBAction func tapPlayViewCell(_ sender: Any) {
        if player.rate == 0 {
            // Not playing forward, so play.
            if player.currentTime() == player.currentItem?.duration {
                // At end, so got back to begining.
                player.seek(to: .zero)
            }
            
            player.play()
            playButton.isHidden = true
        }
        else {
            // Playing, so pause.
            player.pause()
            playButton.isHidden = false
        }
        
    }
    
    // MARK: Properties
    
    @IBOutlet weak var playButton: UIImageView!
    @IBOutlet weak var coverV: UIImageView!
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var chorus: UIButton!
    @IBOutlet weak var avatarV: UIButton!
    @IBOutlet weak var nickNameLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var secondsLabel: UILabel!
    @IBOutlet weak var reviewsLabel: UILabel!
    @IBOutlet weak var chorusLabel: UILabel!
    @IBOutlet weak var progressV: UIProgressView!
    
    static let reuseIdentifier = "FollowingViewCell"
    var player = AVPlayer()
    var url : URL?
    weak open var delegate: SecondsDelegate?
}
