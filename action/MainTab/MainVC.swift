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
    var seconds: CKRecord? = nil
    var reviews: CKRecord? = nil
    var chorus: CKRecord? = nil
}

class MainVC: UIViewController, UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching, SecondsDelegate {
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
    
    func addSeconds(_ cell: UITableViewCell) {
        guard let row = tableView.indexPath(for: cell)?.row, let secondsRecord = artworkRecords[row].seconds else {
            return
        }
        secondsPlus(secondsRecord) { newSecondsRecord in
            DispatchQueue.main.sync {
                self.artworkRecords[row].seconds = newSecondsRecord
                if let seconds = newSecondsRecord["seconds"] as? Int64 {
                    self.reloadVisibleRow(row, type: 0, value: seconds)
                }
            }
        }
    }
    
    func secondsPlus(_ secondsRecord: CKRecord, _ succeedHandler: @escaping (_ secondsRecord: CKRecord) -> Void) {
        guard let secondsCount = secondsRecord["seconds"] as? Int64 else {
            return
        }
        
        secondsRecord["seconds"] = secondsCount + 10
        
        let operation = CKModifyRecordsOperation(recordsToSave: [secondsRecord], recordIDsToDelete: nil)
        
        operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
            guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil) == nil else {
                
                if let newRecord = records?.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                        self.secondsPlus(newRecord, succeedHandler)
                    })
                }
                
                return
            }
            
            if let newRecord = records?.first {
                succeedHandler(newRecord)
            }
            
        }
        operation.database = self.database
        
        self.operationQueue.addOperation(operation)
    }
    
    @IBAction func done(bySegue: UIStoryboardSegue) {
        if bySegue.identifier == "review to main" {
            if let row = tableView.indexPathsForVisibleRows?.first?.row {
                queryReviews(row)
            }
        }
        if bySegue.identifier == "action to main" {
            if let row = tableView.indexPathsForVisibleRows?.first?.row {
                queryChorus(row)
            }
        }
    }
    
    @IBAction func swipeRight(_ sender: Any) {
        cancel(sender)
    }
    
    func secondsToHoursMinutesSeconds (seconds : Int64) -> String {
        let (h,m,s) = (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
        let (Y,D,H) = (h/(365*24), (h%(365*24))/24, (h%(365*24))%24)
        if Y/100>0 {
            return "\(Y/100)世纪"
        }
        if Y>0 {
            return "\(Y)年"
        }
        if D>0 {
            return "\(D)天"
        }
        if H>0 {
            return "\(H)时"
        }
        if m>0 {
            return "\(m)分"
        }
        if s>=0 {
            return "\(s)秒"
        }
        
        return ""
    }
    
    func reloadVisibleRow(_ row: Int, type: Int, value: Int64) {
        let indexPath = IndexPath(row: row, section: 0)

        if tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false {
            switch(type) {
            case 0:
                (tableView.cellForRow(at: indexPath) as? MainViewCell)?.secondsLabel.text = "\(secondsToHoursMinutesSeconds(seconds: value))"
            case 1:
                (tableView.cellForRow(at: indexPath) as? MainViewCell)?.reviewsLabel.text = "\(value)"
            case 2:
                (tableView.cellForRow(at: indexPath) as? MainViewCell)?.chorusLabel.text = "\(value)"
            default:
                tableView.reloadRows(at: [indexPath], with: .none)
                if isAppearing {
                    (tableView.visibleCells.first as? MainViewCell)?.player.play()
                }
            }
        }
    }
    
    func querySeconds(_ row: Int)
    {
        guard let artworkRecord = artworkRecords[row].artwork, let infoID = (artworkRecord["seconds"] as? CKRecord.Reference)?.recordID else {
            return
        }
        
        let fetchInfoOp = CKFetchRecordsOperation(recordIDs: [infoID])

        fetchInfoOp.fetchRecordsCompletionBlock = { (recordsByRecordID, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            if let infoRecord = recordsByRecordID?[infoID] {
                DispatchQueue.main.sync {
                    self.artworkRecords[row].seconds = infoRecord
                    if let seconds = infoRecord["seconds"] as? Int64 {
                        self.reloadVisibleRow(row, type: 0, value: seconds)
                    }
                }
            }
        }
        fetchInfoOp.database = self.database
        self.operationQueue.addOperation(fetchInfoOp)
    }
    
    func queryReviews(_ row: Int)
    {
        guard let artworkRecord = artworkRecords[row].artwork, let infoID = (artworkRecord["reviews"] as? CKRecord.Reference)?.recordID else {
            return
        }
        
        let fetchInfoOp = CKFetchRecordsOperation(recordIDs: [infoID])
        
        fetchInfoOp.fetchRecordsCompletionBlock = { (recordsByRecordID, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            if let infoRecord = recordsByRecordID?[infoID] {
                DispatchQueue.main.sync {
                    self.artworkRecords[row].reviews = infoRecord
                    if let reviews = infoRecord["reviews"] as? Int64 {
                        self.reloadVisibleRow(row, type: 1, value: reviews)
                    }
                }
            }
        }
        fetchInfoOp.database = self.database
        self.operationQueue.addOperation(fetchInfoOp)
    }
    
    func queryChorus(_ row: Int)
    {
        guard let artworkRecord = artworkRecords[row].artwork, let infoID = (artworkRecord["chorus"] as? CKRecord.Reference)?.recordID else {
            return
        }
        
        let fetchInfoOp = CKFetchRecordsOperation(recordIDs: [infoID])
        
        fetchInfoOp.fetchRecordsCompletionBlock = { (recordsByRecordID, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            if let infoRecord = recordsByRecordID?[infoID] {
                DispatchQueue.main.sync {
                    self.artworkRecords[row].chorus = infoRecord
                    if let chorus = infoRecord["chorus"] as? Int64 {
                        self.reloadVisibleRow(row, type: 2, value: chorus)
                    }
                }
            }
        }
        fetchInfoOp.database = self.database
        self.operationQueue.addOperation(fetchInfoOp)
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

                        self.reloadVisibleRow(row, type: 3, value: 0)
                    }
                }
            }
            
        }
        fetchArtworkOp.database = self.database
        self.operationQueue.addOperation(fetchArtworkOp)
        
        querySeconds(row)
        queryReviews(row)
        queryChorus(row)
        
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
        
        queryArtworksOp.desiredKeys = ["seconds", "reviews", "chorus", "nickName", "avatar", "title", "cover"]
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
        let secondsRecord = artworkRecords[indexPath.row].seconds
        let reviewsRecord = artworkRecords[indexPath.row].reviews
        let chorusRecord = artworkRecords[indexPath.row].chorus
        let artwork = artworkRecords[indexPath.row].artwork
        
        playViewCell.secondsLabel.text = "\(secondsToHoursMinutesSeconds(seconds: secondsRecord?["seconds"] ?? 0))"
        playViewCell.reviewsLabel.text = "\(reviewsRecord?["reviews"] ?? 0)"
        playViewCell.chorusLabel.text = "\(chorusRecord?["chorus"] ?? 0)"
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
            queryArtworksOp.desiredKeys = ["seconds", "reviews", "chorus", "nickName", "avatar", "title", "cover"]
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
        let playViewCell = cell as! MainViewCell
        
        playViewCell.secondsLabel.text = ""
        playViewCell.reviewsLabel.text = ""
        playViewCell.chorusLabel.text = ""
        playViewCell.titleLabel.text = ""
        playViewCell.nickNameLabel.text = "@卓别林"
        playViewCell.avatarV.image = #imageLiteral(resourceName: "avatar")
        playViewCell.url = nil
        playViewCell.coverV.image = nil
        playViewCell.progressV.progress = 0
        
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
        
        cell.delegate = self
        
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "action segue" {
            if let actionVC = segue.destination as? ActionVC, let currentCell = tableView.visibleCells.first as? MainViewCell, let currentIndex = tableView.indexPath(for: currentCell), let artworkRecord = artworkRecords[currentIndex.row].artwork {
                actionVC.url = currentCell.url
                actionVC.chorusRef = artworkRecord["chorus"] as? CKRecord.Reference
                currentCell.player.pause()
            }
        } else if segue.identifier == "artist segue" {
            if let userInfoVC = segue.destination as? UserInfoVC, let row = tableView.indexPathsForVisibleRows?.first?.row {
                userInfoVC.userID = artworkRecords[row].artwork?.creatorUserRecordID
            }
        } else if segue.identifier == "reviews segue", let row = self.tableView.indexPathsForVisibleRows?.first?.row {
            if let reviewsVC = (segue.destination as? UINavigationController)?.topViewController as? ReviewsVC {
                reviewsVC.artworkID = artworkRecords[row].artwork?.recordID
                reviewsVC.reviewsID = artworkRecords[row].reviews?.recordID
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
        
        let times = (1..<240).map {
            CMTime(seconds: Double($0)/4, preferredTimescale: 600) as NSValue
        }
        
        player.addBoundaryTimeObserver(forTimes: times, queue: nil, using: {
            let playerTime = self.player.currentTime()
            
            if Int(playerTime.seconds) % 10 == 0, Int(playerTime.seconds) == Int(playerTime.seconds+0.9) {
                self.delegate?.addSeconds(self)
            }
            if let duration = self.player.currentItem?.duration {
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
    @IBOutlet weak var progressV: UIProgressView!
    
    static let reuseIdentifier = "TCPlayViewCell"
    var player = AVPlayer()
    var url : URL?
    weak open var delegate: SecondsDelegate?
}

public protocol SecondsDelegate : NSObjectProtocol {
    func addSeconds(_ cell: UITableViewCell)
}
