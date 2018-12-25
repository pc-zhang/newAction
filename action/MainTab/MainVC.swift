//
//  TCVodPlayViewController.swift
//  TXXiaoShiPinDemo
//
//  Created by zpc on 2018/9/24.
//  Copyright © 2018年 tencent. All rights reserved.
//

// ExpressVPN, activate code: EDP7WQC4GPLOOIMVV78M5AN

import UIKit
import CloudKit
import AVFoundation

struct ActorInfo {
    var isPrefetched: Bool = false
    var artwork: CKRecord? = nil
    var info: CKRecord? = nil
}

struct ArtWorkInfo {
    var isPrefetched: Bool = false
    var artwork: CKRecord? = nil
    var info: CKRecord? = nil
    var followRecord: CKRecord? = nil
    var isFollowRecordFetched: Bool = false
    var actors: [ActorInfo] = []
}

class MainVC: UIViewController, UITableViewDataSource, UITableViewDelegate, ArtworksTableViewDelegate, ActorTableViewDelegate, UITableViewDataSourcePrefetching {

    var userID: CKRecord.ID? = nil
    var selectedRow: Int? = nil
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    var artworkRecords: [ArtWorkInfo] = []
    
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    var isFetchingData: Bool = false
    var refreshControl = UIRefreshControl()
    var isAppearing: Bool = false

    @IBOutlet weak var artworksTableView: UITableView!
    @IBOutlet weak var actorsTableView: UITableView!
    @IBOutlet weak var tableViewTrailingWidth: NSLayoutConstraint!
    @IBOutlet weak var locationSegment: UIButton!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func changeActor(_ cell: UITableViewCell) {
        guard let actorRow = actorsTableView.indexPath(for: cell)?.row, let row = artworksTableView.indexPathsForVisibleRows?.first?.row, let mainCell = (artworksTableView.cellForRow(at: IndexPath(row: row, section: 0)) as? MainViewCell), let button = (cell as? ActorCell)?.actorButton else {
            return
        }
        
        artworkRecords[row].info = artworkRecords[row].actors[actorRow].info
        artworkRecords[row].artwork = artworkRecords[row].actors[actorRow].artwork
        artworkRecords[row].isPrefetched = false
        syncTableViewWithArtworkRecords()
        artworksTableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .fade)
        
        let actor = UIButton()
        view.addSubview(actor)
        actor.frame = cell.convert(button.frame, to: view)
        actor.clipsToBounds = true
        actor.layer.cornerRadius = actor.bounds.height / 2
        actor.setBackgroundImage(button.currentBackgroundImage, for: .normal)
        button.isHidden = true
        
        UIView.animate(withDuration: 0.5, animations: {
            var avatarFrame = mainCell.avatarV.convert(mainCell.avatarV.frame, to: self.view)
            avatarFrame.origin.x += 85
            actor.layer.frame = avatarFrame
            self.tableViewTrailingWidth.constant = 0
            self.view.layoutIfNeeded()
        }) { (b) in
            actor.removeFromSuperview()
            button.isHidden = false
        }

        artworksTableView.isScrollEnabled = true
    }
    
    func addSeconds() {
        guard let row = artworksTableView.indexPathsForVisibleRows?.first?.row, let infoRecord = artworkRecords[row].info, let seconds = (artworksTableView.cellForRow(at: IndexPath(row: row, section: 0)) as? MainViewCell)?.player.currentItem?.duration.seconds else {
            return
        }
        
        secondsPlus(infoRecord, Int64(seconds)) { newInfoRecord in
            DispatchQueue.main.sync {
                self.artworkRecords[row].info = newInfoRecord
                self.reloadVisibleRow(row, type: 0)
            }
        }
    }
    
    func addReports() {
        guard let row = artworksTableView.indexPathsForVisibleRows?.first?.row, let infoRecord = artworkRecords[row].info else {
            return
        }
        
        reportsPlus(infoRecord) { newInfoRecord in
            DispatchQueue.main.sync {
                self.artworkRecords[row].info = newInfoRecord
                self.reloadVisibleRow(row, type: 0)
            }
        }
    }
    
    @IBAction func action(_ sender: Any) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if isPopings {
            actionSheet.addAction(UIAlertAction(title: "弹幕关", style: .default, handler: { (action) in
                self.isPopings = false
                self.view.layer.removeAllAnimations()
                self.view.layoutIfNeeded()
            }))
        } else {
            actionSheet.addAction(UIAlertAction(title: "弹幕开", style: .default, handler: { (action) in
                self.isPopings = true
                self.reviewsFly()
            }))
        }
        actionSheet.addAction(UIAlertAction(title: "举报", style: .default, handler: { (action) in
            self.addReports()
        }))
        actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { (action) in
        }))
        
        present(actionSheet, animated: true)
        
    }
    
    @IBAction func review(_ sender: Any) {
        guard let row = artworksTableView.indexPathsForVisibleRows?.first?.row, let artworkID = artworkRecords[row].artwork?.recordID, let infoRecord = artworkRecords[row].info else {
            return
        }
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let reviewTexts = ["明明可以靠颜值，却偏偏靠实力！", "其实，你是一个演员", "人戏不分，本色出演", "举手投足皆是戏，忽正忽邪尚有余", "把角色演成自己，把自己演到失忆。", "角色虽小，却难掩真情流露", "一顾倾人城，再顾倾人国", ]
        
        for review in reviewTexts {
            actionSheet.addAction(UIAlertAction(title: review, style: .default, handler: { (action) in
                self.sendReview(artworkID, infoRecord, review)
            }))
        }
        
        actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { (action) in
        }))
        
        present(actionSheet, animated: true)
        
    }
    
    
    func secondsPlus(_ infoRecord: CKRecord, _ seconds: Int64, _ succeedHandler: @escaping (_ secondsRecord: CKRecord) -> Void) {
        guard let secondsCount = infoRecord["seconds"] as? Int64 else {
            return
        }
        
        infoRecord["seconds"] = secondsCount + seconds
        
        let operation = CKModifyRecordsOperation(recordsToSave: [infoRecord], recordIDsToDelete: nil)
        
        operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
            guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil) == nil else {
                
                if let newRecord = records?.first {
                    DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                        self.secondsPlus(newRecord, seconds, succeedHandler)
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
    
    func reportsPlus(_ infoRecord: CKRecord, _ succeedHandler: @escaping (_ secondsRecord: CKRecord) -> Void) {
        guard let reportsCount = infoRecord["reports"] as? Int64 else {
            return
        }
        
        infoRecord["reports"] = reportsCount + 1
        
        let operation = CKModifyRecordsOperation(recordsToSave: [infoRecord], recordIDsToDelete: nil)
        
        operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
            guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil) == nil else {
                
                if let newRecord = records?.first {
                    DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                        self.reportsPlus(newRecord, succeedHandler)
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
    
    func queryInfo(_ row: Int)
    {
        guard let infoID = artworkRecords[row].info?.recordID else {
            return
        }
        
        let fetchInfoOp = CKFetchRecordsOperation(recordIDs: [infoID])
        
        fetchInfoOp.fetchRecordsCompletionBlock = { (recordsByRecordID, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            if let infoRecord = recordsByRecordID?[infoID] {
                DispatchQueue.main.sync {
                    self.artworkRecords[row].info = infoRecord
                    self.reloadVisibleRow(row, type: 0)
                }
            }
        }
        fetchInfoOp.database = self.database
        self.operationQueue.addOperation(fetchInfoOp)
    }
    
    @IBAction func done(bySegue: UIStoryboardSegue) {
        if bySegue.identifier == "review to main" {
            if let row = artworksTableView.indexPathsForVisibleRows?.first?.row {
                queryInfo(row)
            }
        }
        if bySegue.identifier == "action to main" {
            if let row = artworksTableView.indexPathsForVisibleRows?.first?.row {
                queryInfo(row)
            }
        }
    }
    
    func reloadVisibleRow(_ row: Int, type: Int) {
        let indexPath = IndexPath(row: row, section: 0)
        
        guard let playerCell = artworksTableView.cellForRow(at: indexPath) as? MainViewCell else {
            return
        }

        if artworksTableView.indexPathsForVisibleRows?.contains(indexPath) ?? false {
            switch(type) {
            case 0:
                if let secondsValue = artworkRecords[row].info?["seconds"] as? Int64 {
                    playerCell.secondsLabel.text = "\(secondsValue.seconds2String())"
                }
                if let reviewsValue = artworkRecords[row].info?["reviews"] as? Int64 {
                    playerCell.reviewsLabel.text = "\(reviewsValue)"
                }
                if let chorusValue = artworkRecords[row].info?["chorus"] as? Int64 {
                    playerCell.chorusLabel.text = "\(chorusValue)"
                }
                if artworkRecords[indexPath.row].isFollowRecordFetched {
                    playerCell.followButton.isHidden = false
                    if artworkRecords[indexPath.row].followRecord != nil {
                        playerCell.followButton.setTitle("已关注", for: .normal)
                    } else {
                        playerCell.followButton.setTitle("+关注", for: .normal)
                    }
                } else {
                    playerCell.followButton.isHidden = true
                }
                
            default:
                artworksTableView.reloadData()
                if isAppearing {
                    playerCell.player.play()
                }
            }
        }
    }
    
    
    func queryFullArtwork(_ row: Int)
    {
        guard row < artworkRecords.count, row >= 0, let infoRecord = artworkRecords[row].info else {
            return
        }

        if artworkRecords[row].isPrefetched == true {
            return
        }
        artworkRecords[row].isPrefetched = true
        
        if let artistID = infoRecord.creatorUserRecordID {
            queryFollowRecord(artistID, row)
        }
        
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
    
    private var reviewRecords: [CKRecord] = []
    
    func queryReviews(_ artworkID: CKRecord.ID) {
        reviewRecords = []
        
        let query = CKQuery(recordType: "Review", predicate: NSPredicate(format: "artwork = %@", artworkID))
        
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [byCreation]
        let queryReviewsOp = CKQueryOperation(query: query)
        
        queryReviewsOp.desiredKeys = ["text", "avatar", "nickName"]
        queryReviewsOp.resultsLimit = 99
        queryReviewsOp.recordFetchedBlock = { (reviewRecord) in
            DispatchQueue.main.sync {
                self.reviewRecords.append(reviewRecord)
            }
        }
        queryReviewsOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            DispatchQueue.main.sync {
                self.reviewsFly()
            }
        }
        queryReviewsOp.database = self.database
        self.operationQueue.addOperation(queryReviewsOp)
    }
    
    var isPopings = true
    
    func reviewsFly() {
        guard isPopings == true, let cell = artworksTableView.visibleCells.first as? MainViewCell, let duration = cell.player.currentItem?.duration.seconds else {
            return
        }
        
        self.view.layer.removeAllAnimations()
        self.view.layoutIfNeeded()
        
        let length : CGFloat = CGFloat(view.bounds.width) / CGFloat(5) * CGFloat(duration) / CGFloat(reviewRecords.count)
        var i: CGFloat = 0
        for review in reviewRecords {
            let text = review["text"] as? String
            let labelV = UILabel(frame: CGRect(x: view.bounds.width + 50 + i * length, y: 100 +  CGFloat(arc4random_uniform(UInt32(view.bounds.height - 300))), width: 10, height: 10))
            labelV.text = text
            labelV.textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            labelV.font = UIFont.boldSystemFont(ofSize: 25)
            labelV.sizeToFit()
            view.addSubview(labelV)
            
            UIView.animate(withDuration: duration, animations: {
                labelV.layer.position.x = labelV.layer.position.x - self.view.bounds.width - labelV.bounds.width - CGFloat(self.reviewRecords.count) * length
            }) { (succeed) in
                labelV.removeFromSuperview()
            }
            
            i += 1
        }
    }
    
    func sendReview(_ artworkID: CKRecord.ID, _ infoRecord: CKRecord, _ text: String) {
        let reviewRecord = CKRecord(recordType: "Review")
        reviewRecord["artwork"] = CKRecord.Reference(recordID: artworkID, action: .deleteSelf)
        reviewRecord["text"] = text
        reviewRecord["nickName"] = (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord?["nickName"] as? String
        if let url = ((UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord?["littleAvatar"] as? CKAsset)?.fileURL {
            reviewRecord["avatar"] = CKAsset(fileURL: url)
        }
        
        let operation = CKModifyRecordsOperation(recordsToSave: [reviewRecord], recordIDsToDelete: nil)
        
        operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
            guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil, alert: true) == nil, let newRecord = records?[0] else { return }
            DispatchQueue.main.sync {
                self.reviewRecords.insert(newRecord, at: 0)
            }
        }
        operation.database = self.database
        
        self.operationQueue.addOperation(operation)
        
        reviewsPlus(infoRecord)
        
        let labelV = UILabel(frame: CGRect(x: view.bounds.width, y: 100 +  CGFloat(arc4random_uniform(UInt32(view.bounds.height - 300))), width: 10, height: 10))
        labelV.text = text
        labelV.textColor = #colorLiteral(red: 0.9994998574, green: 0.06852344424, blue: 0.004268030636, alpha: 1)
        labelV.font = UIFont.boldSystemFont(ofSize: 25)
        labelV.sizeToFit()
        view.addSubview(labelV)
        
        UIView.animate(withDuration: 8, animations: {
            labelV.layer.position.x = labelV.layer.position.x - self.view.bounds.width - labelV.bounds.width
        }) { (succeed) in
            labelV.removeFromSuperview()
        }
    }
    
    func reviewsPlus(_ infoRecord: CKRecord) {
        guard let reviewsCount = infoRecord["reviews"] as? Int64 else {
            return
        }
        
        infoRecord["reviews"] = reviewsCount + 1
        
        let operation = CKModifyRecordsOperation(recordsToSave: [infoRecord], recordIDsToDelete: nil)
        
        operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
            guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil) == nil else {
                
                if let newRecord = records?.first {
                    DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                        self.reviewsPlus(newRecord)
                    })
                }
                
                return
            }
            
            DispatchQueue.main.sync {
                if let row = self.artworksTableView.indexPathsForVisibleRows?.first?.row {
                    self.reloadVisibleRow(row, type: 0)
                }
            }
            
        }
        operation.database = self.database
        
        self.operationQueue.addOperation(operation)
        
    }
    
    @IBAction func fetchData(_ sender: Any) {
        operationQueue.cancelAllOperations()
        artworkRecords = []
        isFetchingData = true
        
        var query: CKQuery
        if let userID = userID {
            query = CKQuery(recordType: "ArtworkInfo", predicate: NSPredicate(format: "creatorUserRecordID = %@ && reports < 5", userID))
            let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
            query.sortDescriptors = [byCreation]
        } else {
            let yesterday = Date().addingTimeInterval(-86400)
            query = CKQuery(recordType: "ArtworkInfo", predicate: NSPredicate(format: "creationDate > %@ && reports < 5", yesterday as NSDate))
            let byChorusCount = NSSortDescriptor(key: "chorus", ascending: false)
            query.sortDescriptors = [byChorusCount]
        }
        
        let queryInfoOp = CKQueryOperation(query: query)
        queryInfoOp.resultsLimit = (selectedRow ?? 0) + 1
        queryInfoOp.recordFetchedBlock = { (infoRecord) in
            var artWorkInfo = ArtWorkInfo()
            artWorkInfo.info = infoRecord
            self.artworkRecords.append(artWorkInfo)
        }
        queryInfoOp.queryCompletionBlock = { (cursor, error) in
            DispatchQueue.main.sync {
                self.refreshControl.endRefreshing()
                if let firstIndex = self.artworksTableView.indexPathsForVisibleRows?.first {
                    self.artworksTableView.scrollToRow(at: firstIndex, at: .top, animated: false)
                }
            }
            
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            self.cursor = cursor
            
            DispatchQueue.main.sync {
                self.isFetchingData = false
                self.artworksTableView.reloadData()
            }
        }
        queryInfoOp.database = self.database
        self.operationQueue.addOperation(queryInfoOp)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(type(of: self).fetchData(_:)), for: UIControl.Event.valueChanged)
        artworksTableView.addSubview(refreshControl)
        artworksTableView.estimatedRowHeight = artworksTableView.bounds.height
        artworksTableView.rowHeight = artworksTableView.bounds.height
        
        if artworksTableView.numberOfRows(inSection: 0) > 0 {
            artworksTableView.scrollToRow(at: IndexPath(row: selectedRow ?? 0, section: 0), at: .top, animated: false)
        } else {
            fetchData(0)
        }
        
        
        let eulaAgreed = UserDefaults.standard.bool(forKey: "eulaAgreed")
        
        if !eulaAgreed {
            performSegue(withIdentifier: "eula", sender: self)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.setNavigationBarHidden(false, animated: false)
        isAppearing = true
        (artworksTableView.visibleCells.first as? MainViewCell)?.player.play()
        
        NotificationCenter.default.addObserver(self, selector: #selector(type(of: self).playerDidFinishPlaying(note:)),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        artworksTableView.estimatedRowHeight = artworksTableView.bounds.height
        artworksTableView.rowHeight = artworksTableView.bounds.height
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isAppearing = false
        for cell in artworksTableView.visibleCells {
            (cell as? MainViewCell)?.player.pause()
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    func queryActorInfos(_ artworkID: CKRecord.ID, _ row: Int) {
        
        var tmpActors:[ActorInfo] = []
        
        let query = CKQuery(recordType: "ArtworkInfo", predicate: NSPredicate(format: "chorusFrom = %@ && reports < 5", artworkID))

        query.sortDescriptors = [NSSortDescriptor(key: "seconds", ascending: false)]
        
        let queryInfoOp = CKQueryOperation(query: query)
        queryInfoOp.resultsLimit = 99
        queryInfoOp.recordFetchedBlock = { (infoRecord) in
            var tmpActor = ActorInfo()
            tmpActor.info = infoRecord
            tmpActors.append(tmpActor)
        }
        queryInfoOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            DispatchQueue.main.sync {
                self.artworkRecords[row].actors = tmpActors.map {$0}
                self.actorsTableView.reloadData()
            }
        }
        queryInfoOp.database = self.database
        self.operationQueue.addOperation(queryInfoOp)
    }
    
    func queryAvatar(_ row: Int)
    {
        guard let artworksRow = artworksTableView.indexPathsForVisibleRows?.first?.row, row < artworkRecords[artworksRow].actors.count, row >= 0, let infoRecord = artworkRecords[artworksRow].actors[row].info else {
            return
        }
        
        if artworkRecords[artworksRow].actors[row].isPrefetched == true {
            return
        }
        artworkRecords[artworksRow].actors[row].isPrefetched = true
        
        let query = CKQuery(recordType: "Artwork", predicate: NSPredicate(format: "info = %@", infoRecord.recordID))
        
        let queryArtworkOp = CKQueryOperation(query: query)
        queryArtworkOp.desiredKeys = ["avatar"]
        queryArtworkOp.recordFetchedBlock = { (artworkRecord) in
            DispatchQueue.main.sync {
                if row < self.artworkRecords[artworksRow].actors.count {
                    self.artworkRecords[artworksRow].actors[row].artwork = artworkRecord
                    self.actorsTableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .fade)
                }
            }
        }
        queryArtworkOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
        }
        queryArtworkOp.database = self.database
        self.operationQueue.addOperation(queryArtworkOp)
        
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        if tableView == actorsTableView {
            for indexPath in indexPaths {
                queryAvatar(indexPath.row)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if let actorCell = cell as? ActorCell {
            queryAvatar(indexPath.row)
            
            if let row = artworksTableView.indexPathsForVisibleRows?.first?.row, let avatarImageAsset = artworkRecords[row].actors[indexPath.row].artwork?["avatar"] as? CKAsset {
                actorCell.actorButton.setBackgroundImage(UIImage(contentsOfFile: avatarImageAsset.fileURL.path), for: .normal)
            }
            
            return
        }
        
        queryFullArtwork(indexPath.row)
        queryFullArtwork(indexPath.row + 1)
        queryFullArtwork(indexPath.row - 1)
        
        let playViewCell = cell as! MainViewCell
        let infoRecord = artworkRecords[indexPath.row].info
        let artwork = artworkRecords[indexPath.row].artwork
        
        playViewCell.secondsLabel.text = "\((infoRecord?["seconds"] as? Int64 ?? 0).seconds2String())"
        playViewCell.reviewsLabel.text = "\(infoRecord?["reviews"] ?? 0)"
        playViewCell.chorusLabel.text = "\(infoRecord?["chorus"] ?? 0)"
        playViewCell.titleLabel.text = "\(artwork?["title"] ?? "")"
        
        if let avatarImageAsset = artwork?["avatar"] as? CKAsset {
            playViewCell.avatarV.setBackgroundImage(UIImage(contentsOfFile: avatarImageAsset.fileURL.path), for: .normal)
        }
        if let coverImageAsset = artwork?["cover"] as? CKAsset {
            playViewCell.coverV.image = UIImage(contentsOfFile: coverImageAsset.fileURL.path)
        }
        if let nickName = artwork?["nickName"] as? String {
            playViewCell.nickNameButton.setTitle("@\(nickName)", for: .normal)
        }
        if artworkRecords[indexPath.row].isFollowRecordFetched {
            playViewCell.followButton.isHidden = false
            if artworkRecords[indexPath.row].followRecord != nil {
                playViewCell.followButton.setTitle("已关注", for: .normal)
            } else {
                playViewCell.followButton.setTitle("+关注", for: .normal)
            }
        } else {
            playViewCell.followButton.isHidden = true
        }
        
        let surplus = artworkRecords.count - (indexPath.row + 1)
        if let cursor = cursor, !isFetchingData, surplus < 2 {
            isFetchingData = true
            
            let queryArtworksOp = CKQueryOperation(cursor: cursor)
            queryArtworksOp.resultsLimit = 2 - surplus
            queryArtworksOp.recordFetchedBlock = { (infoRecord) in
                var artWorkInfo = ArtWorkInfo()
                artWorkInfo.info = infoRecord
                DispatchQueue.main.sync {
                    self.artworkRecords.append(artWorkInfo)
                }
            }
            queryArtworksOp.queryCompletionBlock = { (cursor, error) in
                guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
                self.cursor = cursor
                
                DispatchQueue.main.sync {
                    self.isFetchingData = false
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
            
            if let artworkID = artworkRecords[indexPath.row].artwork?.recordID {
                queryReviews(artworkID)
            }
        }
        
    }
    
    @objc func playerDidFinishPlaying(note: NSNotification) {
        guard let player = (artworksTableView.visibleCells.first as? MainViewCell)?.player else {
            return
        }
        
        player.seek(to: .zero)
        player.play()
        swipeLeft(0)
        
        addSeconds()
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if let actorCell = cell as? ActorCell {
            actorCell.actorButton.setBackgroundImage(nil, for: .normal)
        }
        
        guard let playViewCell = cell as? MainViewCell else {
            return
        }
        
        playViewCell.secondsLabel.text = ""
        playViewCell.reviewsLabel.text = ""
        playViewCell.chorusLabel.text = ""
        playViewCell.titleLabel.text = ""
        playViewCell.nickNameButton.setTitle("", for: .normal)
        playViewCell.avatarV.setBackgroundImage(#imageLiteral(resourceName: "avatar"), for: .normal)
        playViewCell.url = nil
        playViewCell.coverV.image = nil
        playViewCell.progressV.progress = 0
        playViewCell.followButton.isHidden = true
        
        playViewCell.player.pause()
        playViewCell.player.replaceCurrentItem(with: nil)
        
    }
    
    func follow(_ cell: UITableViewCell) {
        guard let row = artworksTableView.indexPath(for: cell)?.row, artworkRecords[row].isFollowRecordFetched, let yourID = artworkRecords[row].info?.creatorUserRecordID else {
            return
        }
        
        if artworkRecords[row].followRecord != nil {
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [artworkRecords[row].followRecord!.recordID])
            
            operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
                guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil, alert: true) == nil else { return }
                
                DispatchQueue.main.sync {
                    self.artworkRecords[row].followRecord = nil
                    self.reloadVisibleRow(row, type: 0)
                }
            }
            operation.database = self.database
            self.operationQueue.addOperation(operation)
        } else {
            let followRecord = CKRecord(recordType: "Follow")
            followRecord["followed"] = CKRecord.Reference(recordID: yourID, action: .none)
            
            let operation = CKModifyRecordsOperation(recordsToSave: [followRecord], recordIDsToDelete: nil)
            
            operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
                guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil, alert: true) == nil,
                    let newRecord = records?.first else { return }
                
                DispatchQueue.main.sync {
                    self.artworkRecords[row].followRecord = newRecord
                    self.reloadVisibleRow(row, type: 0)
                }
            }
            operation.database = self.database
            self.operationQueue.addOperation(operation)
        }
        
    }
    
    func queryFollowRecord(_ yourID: CKRecord.ID, _ row: Int) {
        guard let myInfoRecord = (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord else {
            return
        }
        
        let query = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "followed = %@ && creatorUserRecordID = %@", yourID, myInfoRecord.recordID))
        let queryMessagesOp = CKQueryOperation(query: query)
        
        queryMessagesOp.recordFetchedBlock = { (record) in
            DispatchQueue.main.sync {
                self.artworkRecords[row].followRecord = record
                self.reloadVisibleRow(row, type: 0)
            }
        }
        queryMessagesOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            DispatchQueue.main.sync {
                self.artworkRecords[row].isFollowRecordFetched = true
            }
        }
        queryMessagesOp.database = self.database
        self.operationQueue.addOperation(queryMessagesOp)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let tableView = scrollView as? UITableView, tableView == artworksTableView {
            if let playViewCell = tableView.visibleCells.first as? MainViewCell {
                playViewCell.player.play()
                actorsTableView.reloadData()
            }
            
            syncTableViewWithArtworkRecords()
        }
    }
    
    func syncTableViewWithArtworkRecords() {
        let recordsCountBefore = artworksTableView.numberOfRows(inSection: 0)
        if recordsCountBefore < artworkRecords.count {
            let indexPaths = (recordsCountBefore ..< self.artworkRecords.count).map {
                IndexPath(row: $0, section: 0)
            }
            
            self.artworksTableView.insertRows(at: indexPaths, with: .none)
        }
    }
    
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == actorsTableView {
            if let row = artworksTableView.indexPathsForVisibleRows?.first?.row, row < artworkRecords.count {
                return artworkRecords[row].actors.count
            }
            return 0
        }
        // #warning Incomplete implementation, return the number of rows
        return artworkRecords.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if tableView == actorsTableView, let cell = tableView.dequeueReusableCell(withIdentifier: "actor cell", for: indexPath) as? ActorCell {
            cell.delegate = self
            return cell
        }
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MainViewCell.reuseIdentifier, for: indexPath) as? MainViewCell else {
            fatalError("Expected `\(MainViewCell.self)` type for reuseIdentifier \(MainViewCell.reuseIdentifier). Check the configuration in Main.storyboard.")
        }
        
        cell.delegate = self
        
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "main to action" {
            if let actionVC = segue.destination as? ActionVC, let currentCell = artworksTableView.visibleCells.first as? MainViewCell, let currentIndex = artworksTableView.indexPath(for: currentCell), let url = currentCell.url {
                actionVC.url = url
                actionVC.infoRecord = artworkRecords[currentIndex.row].info
                actionVC.artworkID = artworkRecords[currentIndex.row].artwork?.recordID
                currentCell.player.pause()
            }
        } else if segue.identifier == "main to artist" {
            if let userInfoVC = segue.destination as? UserInfoVC, let row = artworksTableView.indexPathsForVisibleRows?.first?.row {
                userInfoVC.hidesBottomBarWhenPushed = true
                userInfoVC.userID = artworkRecords[row].info?.creatorUserRecordID
            }
        } else if segue.identifier == "main to reviews", let row = self.artworksTableView.indexPathsForVisibleRows?.first?.row {
            if let reviewsVC = segue.destination as? ReviewsVC {
                reviewsVC.artworkID = artworkRecords[row].artwork?.recordID
                reviewsVC.infoRecord = artworkRecords[row].info
            }
        }
        
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "main to artist" {
            if let row = self.artworksTableView.indexPathsForVisibleRows?.first?.row, let userID = userID, let creatorUserRecordID = artworkRecords[row].artwork?.creatorUserRecordID, creatorUserRecordID == userID {
                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: true)
                }
                return false
            }
        } else if identifier == "main to action" {
            if let currentCell = artworksTableView.visibleCells.first as? MainViewCell, currentCell.url != nil {
                return true
            } else {
                return false
            }
        }
        
        return true
    }
    
    @IBAction func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    
    @IBAction func swipeRight(_ sender: Any) {
        if tableViewTrailingWidth.constant == 85 {
            UIView.animate(withDuration: 0.3) {
                self.tableViewTrailingWidth.constant = 0
                self.view.layoutIfNeeded()
            }
            
            artworksTableView.isScrollEnabled = true
            
            return
        }
    }
    
    @IBAction func swipeLeft(_ sender: Any) {
        guard  tableViewTrailingWidth.constant == 0, let row = artworksTableView.indexPathsForVisibleRows?.first?.row, let artworkID = (artworkRecords[row].info?["chorusFrom"] as? CKRecord.Reference)?.recordID else {
            return
        }
        
        if artworkRecords[row].actors.count == 0 {
            queryActorInfos(artworkID, row)
        }
        
        artworksTableView.isScrollEnabled = false
        
        UIView.animate(withDuration: 0.3) {
            self.tableViewTrailingWidth.constant = 85
            self.view.layoutIfNeeded()
        }
        
    }
    
    @IBAction func showActors(_ sender: Any) {
        if tableViewTrailingWidth.constant == 85 {
            swipeRight(sender)
            return
        }
        
        if tableViewTrailingWidth.constant == 0 {
            swipeLeft(sender)
            return
        }
        
    }
    
}

class ActorCell: UITableViewCell {
    
    @IBOutlet weak var actorButton: UIButton! {
        didSet {
            actorButton.layer.cornerRadius = actorButton.bounds.height / 2
        }
    }
    
    @IBAction func changeActor(_ sender: Any) {
        self.delegate?.changeActor(self)
    }
    weak open var delegate: ActorTableViewDelegate?
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
            guard playerTime.isValid, let duration = self.player.currentItem?.duration, duration.isValid else {
                return
            }
            
            self.progressV.progress = Float(playerTime.seconds / duration.seconds)
            
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
    @IBOutlet weak var coverV: UIImageView!
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var chorus: UIButton!
    @IBOutlet weak var nickNameButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var secondsLabel: UILabel!
    @IBOutlet weak var reviewsLabel: UILabel!
    @IBOutlet weak var chorusLabel: UILabel!
    @IBOutlet weak var progressV: UIProgressView!
    @IBOutlet weak var avatarV: UIButton! {
        didSet {
            avatarV.layer.cornerRadius = avatarV.bounds.height / 2
            avatarV.layer.borderWidth = 1
            avatarV.layer.borderColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        }
    }
    @IBOutlet weak var playButton: UIImageView!
    @IBOutlet weak var followButton: UIButton! {
        didSet {
            followButton.layer.cornerRadius = 8
        }
    }
    
    @IBAction func follow(_ sender: Any) {
        delegate?.follow(self)
    }
    
    
    static let reuseIdentifier = "TCPlayViewCell"
    var player = AVPlayer()
    var url : URL?
    weak open var delegate: ArtworksTableViewDelegate?
}

public protocol ArtworksTableViewDelegate : NSObjectProtocol {
    func follow(_ cell: UITableViewCell)
}

public protocol ActorTableViewDelegate : NSObjectProtocol {
    func changeActor(_ cell: UITableViewCell)
}

extension Int64 {
    func seconds2String() -> String {
        let (h,m,s) = (self / 3600, (self % 3600) / 60, (self % 3600) % 60)
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
}
