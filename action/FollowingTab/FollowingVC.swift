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

public protocol ActorCollectionViewDelegate : NSObjectProtocol {
    func changeActor(_ cell: UICollectionViewCell)
}

class FollowingVC: UIViewController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDataSourcePrefetching, ActorCollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
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
        
        tableView.estimatedRowHeight = view.bounds.height - 90
        tableView.rowHeight = view.bounds.height - 90
        
        refresh.addTarget(self, action: #selector(fetchData), for: .valueChanged)
        tableView.addSubview(refresh)
        fetchData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        for cell in tableView.visibleCells {
            (cell as? FollowingViewCell)?.player.pause()
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
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
            
            let query = CKQuery(recordType: "ArtworkInfo", predicate: NSPredicate(format: "creatorUserRecordID in %@ && reports < 5", followRecords.compactMap {($0["followed"] as? CKRecord.Reference)?.recordID}))
            let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
            query.sortDescriptors = [byCreation]
            
            let queryInfoOp = CKQueryOperation(query: query)
            queryInfoOp.resultsLimit = 6
            queryInfoOp.recordFetchedBlock = { (infoRecord) in
                var artWorkInfo = ArtWorkInfo()
                artWorkInfo.info = infoRecord
                self.artworkRecords.append(artWorkInfo)
            }
            queryInfoOp.queryCompletionBlock = { (cursor, error) in
                DispatchQueue.main.sync {
                    self.refresh.endRefreshing()
                }
                guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
                self.cursor = cursor
                
                DispatchQueue.main.sync {
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
    
    @IBAction func review(_ sender: Any) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "明明可以靠颜值，却偏偏靠实力！", style: .default, handler: { (action) in
        }))
        actionSheet.addAction(UIAlertAction(title: "其实，你是一个演员", style: .default, handler: { (action) in
        }))
        actionSheet.addAction(UIAlertAction(title: "人戏不分，本色出演", style: .default, handler: { (action) in
        }))
        actionSheet.addAction(UIAlertAction(title: "举手投足皆是戏，忽正忽邪尚有余", style: .default, handler: { (action) in
        }))
        actionSheet.addAction(UIAlertAction(title: "把角色演成自己，把自己演到失忆。", style: .default, handler: { (action) in
        }))
        actionSheet.addAction(UIAlertAction(title: "角色虽小，却难掩真情流露", style: .default, handler: { (action) in
        }))
        actionSheet.addAction(UIAlertAction(title: "一顾倾人城，再顾倾人国", style: .default, handler: { (action) in
        }))
        
        actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { (action) in
        }))
        
        present(actionSheet, animated: true)
        
    }
    
    // MARK: - UICollectionViewDelegate
    
    func changeActor(_ cell: UICollectionViewCell) {
        guard let collectionView = cell.superview as? NumberedCollectionView, let actorItem = collectionView.indexPath(for: cell)?.item, let followingCell = collectionView.superview?.superview as? FollowingViewCell, let row = collectionView.followingCellRow, row < artworkRecords.count, let actorButton = (cell as? FollowingActorCell)?.actorButton else {
            return
        }
        
        artworkRecords[row].info = artworkRecords[row].actors[actorItem].info
        artworkRecords[row].artwork = artworkRecords[row].actors[actorItem].artwork
        artworkRecords[row].isPrefetched = false
        tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .fade)
        
        let actor = UIButton()
        view.addSubview(actor)
        actor.frame = cell.convert(actorButton.frame, to: view)
        actor.clipsToBounds = true
        actor.layer.cornerRadius = actor.bounds.height / 2
        actor.setBackgroundImage(actorButton.currentBackgroundImage, for: .normal)
        
        UIView.animate(withDuration: 0.5, animations: {
            let avatarFrame = followingCell.convert(followingCell.avatarV.frame, to: self.view)
            actor.layer.frame = avatarFrame
        }) { (b) in
            actor.removeFromSuperview()
        }
        
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let row = (collectionView as? NumberedCollectionView)?.followingCellRow, row < artworkRecords.count else {
            return 0
        }
        
        return artworkRecords[row].actors.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let actorCell = collectionView.dequeueReusableCell(withReuseIdentifier: "following actor cell", for: indexPath) as! FollowingActorCell
        
        actorCell.delegate = self
        
        return actorCell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let row = (collectionView as? NumberedCollectionView)?.followingCellRow, row < artworkRecords.count else {
            return
        }
        
        if let actorCell = cell as? FollowingActorCell {
            queryAvatar(indexPath.item, row)
            
            if let avatarImageAsset = artworkRecords[row].actors[indexPath.item].artwork?["avatar"] as? CKAsset {
                actorCell.actorButton.setBackgroundImage(UIImage(contentsOfFile: avatarImageAsset.fileURL.path), for: .normal)
            }
            
            return
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard let row = (collectionView as? NumberedCollectionView)?.followingCellRow, row < artworkRecords.count else {
            return
        }
        
        for indexPath in indexPaths {
            queryAvatar(indexPath.item, row)
        }
    }
    
    // MARK: - UITableViewDelegate
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd HH:mm"
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
    
    func queryAvatar(_ item: Int, _ artworksRow: Int)
    {
        guard item < artworkRecords[artworksRow].actors.count, item >= 0, let infoRecord = artworkRecords[artworksRow].actors[item].info else {
            return
        }
        
        if artworkRecords[artworksRow].actors[item].isPrefetched == true {
            return
        }
        artworkRecords[artworksRow].actors[item].isPrefetched = true
        
        let query = CKQuery(recordType: "Artwork", predicate: NSPredicate(format: "info = %@", infoRecord.recordID))
        
        let queryArtworkOp = CKQueryOperation(query: query)
        queryArtworkOp.desiredKeys = ["avatar"]
        queryArtworkOp.recordFetchedBlock = { (artworkRecord) in
            DispatchQueue.main.sync {
                if item < self.artworkRecords[artworksRow].actors.count {
                    self.artworkRecords[artworksRow].actors[item].artwork = artworkRecord
                    if let collectionView = (self.tableView.cellForRow(at: IndexPath(row: artworksRow, section: 0)) as? FollowingViewCell)?.collectionView, collectionView.followingCellRow != nil {
                        collectionView.reloadData()
                    }
                }
            }
        }
        queryArtworkOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
        }
        queryArtworkOp.database = self.database
        self.operationQueue.addOperation(queryArtworkOp)
        
    }
    
    func queryFullArtwork(_ row: Int)
    {
        guard row < artworkRecords.count, row >= 0, let infoRecord = artworkRecords[row].info, let artworkID = (artworkRecords[row].info?["chorusFrom"] as? CKRecord.Reference)?.recordID else {
            return
        }
        
        if artworkRecords[row].isPrefetched == true {
            return
        }
        artworkRecords[row].isPrefetched = true
        
        var tmpActors:[ActorInfo] = []
        let queryChorus = CKQuery(recordType: "ArtworkInfo", predicate: NSPredicate(format: "chorusFrom = %@ && reports < 5", artworkID))

        queryChorus.sortDescriptors = [NSSortDescriptor(key: "seconds", ascending: false)]
        
        let queryChorusOp = CKQueryOperation(query: queryChorus)
        queryChorusOp.resultsLimit = 99
        queryChorusOp.recordFetchedBlock = { (infoRecord) in
            var tmpActor = ActorInfo()
            tmpActor.info = infoRecord
            tmpActors.append(tmpActor)
        }
        queryChorusOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            DispatchQueue.main.sync {
                self.artworkRecords[row].actors = tmpActors.map {$0}
                if let collectionView = (self.tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? FollowingViewCell)?.collectionView, collectionView.followingCellRow != nil {
                    collectionView.reloadData()
                }
            }
        }
        queryChorusOp.database = self.database
        self.operationQueue.addOperation(queryChorusOp)
        
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
                    self.artworkRecords[row].artwork?["video"] = CKAsset(fileURL: savedURL)
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
        queryFullArtwork(indexPath.row-1)
        queryFullArtwork(indexPath.row+1)
        
        let playViewCell = cell as! FollowingViewCell
        let infoRecord = artworkRecords[indexPath.row].info
        let artwork = artworkRecords[indexPath.row].artwork
        
        playViewCell.secondsLabel.text = "\((infoRecord?["seconds"] as? Int64 ?? 0).seconds2String())"
        playViewCell.reviewsLabel.text = "\(infoRecord?["reviews"] ?? 0)"
        playViewCell.chorusLabel.text = "\(infoRecord?["chorus"] ?? 0)"
        playViewCell.titleLabel.text = "\(artwork?["title"] ?? "")"
        if let date = artwork?.creationDate {
            playViewCell.timeLabel.text = dateFormatter.string(from: date)
        }
        
        if let avatarImageAsset = artwork?["avatar"] as? CKAsset {
            playViewCell.avatarV.setBackgroundImage(UIImage(contentsOfFile: avatarImageAsset.fileURL.path), for: .normal)
        }
        if let coverImageAsset = artwork?["cover"] as? CKAsset {
            playViewCell.coverV.image = UIImage(contentsOfFile: coverImageAsset.fileURL.path)
        }
        if let nickName = artwork?["nickName"] as? String {
            playViewCell.nickNameLabel.text = "@\(nickName)"
        }
        playViewCell.collectionView.followingCellRow = indexPath.row
        playViewCell.collectionView.reloadData()
        
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
        
        
        playViewCell.url = (artworkRecords[indexPath.row].artwork?["video"] as? CKAsset)?.fileURL
        if let url = playViewCell.url {
            let playerItem = AVPlayerItem(url: url)
            playViewCell.player.replaceCurrentItem(with: playerItem)
            playViewCell.player.seek(to: .zero)
            
            tableView.scrollRectToVisible(CGRect(origin: CGPoint(x: tableView.contentOffset.x, y: tableView.contentOffset.y + 1), size: tableView.bounds.size), animated: true)
        }
        
        tableView.setNeedsLayout()
        
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let playViewCell = cell as? FollowingViewCell else {
            return
        }
        
        playViewCell.secondsLabel.text = ""
        playViewCell.reviewsLabel.text = ""
        playViewCell.chorusLabel.text = ""
        playViewCell.titleLabel.text = ""
        playViewCell.nickNameLabel.text = ""
        playViewCell.avatarV.setBackgroundImage(#imageLiteral(resourceName: "avatar"), for: .normal)
        playViewCell.url = nil
        playViewCell.coverV.image = nil
        playViewCell.progressV.progress = 0
        playViewCell.collectionView.followingCellRow = nil
        
        playViewCell.player.pause()
        playViewCell.player.replaceCurrentItem(with: nil)
    }
    
    var flag = false
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if tableView == (scrollView as? UITableView), let firstCell = tableView.visibleCells.first as? FollowingViewCell, let lastCell = tableView.visibleCells.last as? FollowingViewCell, firstCell != lastCell {
            let center = firstCell.convert(firstCell.playerView.center, to: view)
            if (center.y > 0) == flag {
                return
            }
            flag = center.y > 0
            if center.y > 0 {
                if firstCell.player.currentTime() == firstCell.player.currentItem?.duration {
                    firstCell.player.seek(to: .zero)
                }
                if firstCell.player.rate == 0 {
                    firstCell.player.play()
                }
                if lastCell.player.rate == 1 {
                    lastCell.player.pause()
                }
            } else {
                if lastCell.player.currentTime() == lastCell.player.currentItem?.duration {
                    lastCell.player.seek(to: .zero)
                }
                if firstCell.player.rate == 1 {
                    firstCell.player.pause()
                }
                if lastCell.player.rate == 0 {
                    lastCell.player.play()
                }
            }
        }
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
            if let reviewsVC = segue.destination as? ReviewsVC {
                reviewsVC.artworkID = artworkRecords[row].artwork?.recordID
                reviewsVC.infoRecord = artworkRecords[row].info
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
            
            if let duration = self.player.currentItem?.duration, duration.isValid {
                self.progressV.progress = Float(playerTime.seconds / duration.seconds)
            }
        })
        
        player.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions(rawValue: NSKeyValueObservingOptions.new.rawValue | NSKeyValueObservingOptions.old.rawValue), context: nil)
        
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            if player.rate == 1  {
                playButton.isHidden = true
            }else{
                playButton.isHidden = false
            }
        }
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
    
    @IBOutlet weak var playButton: UIImageView!
    @IBOutlet weak var coverV: UIImageView!
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var avatarV: UIButton! {
        didSet {
            avatarV.layer.cornerRadius = avatarV.bounds.height / 2
        }
    }
    @IBOutlet weak var nickNameLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var secondsLabel: UILabel!
    @IBOutlet weak var reviewsLabel: UILabel!
    @IBOutlet weak var chorusLabel: UILabel!
    @IBOutlet weak var progressV: UIProgressView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var collectionView: NumberedCollectionView!
    
    
    static let reuseIdentifier = "FollowingViewCell"
    var player = AVPlayer()
    var url : URL?
    weak open var delegate: ArtworksTableViewDelegate?
}

class NumberedCollectionView : UICollectionView {
    var followingCellRow: Int? = nil
}

class FollowingActorCell: UICollectionViewCell {
    
    @IBOutlet weak var actorButton: UIButton! {
        didSet {
            actorButton.layer.cornerRadius = 20
        }
    }
    
    @IBAction func changeActor(_ sender: Any) {
        self.delegate?.changeActor(self)
    }
    weak open var delegate: ActorCollectionViewDelegate?
}
