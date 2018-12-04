//
//  UserInfoVC.swift
//  NIM
//
//  Created by zpc on 2018/10/16.
//  Copyright © 2018年 Netease. All rights reserved.
//

import Foundation
import CloudKit
import UIKit


class UserInfoVC : UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching, HeaderViewDelegate {
    
    var isEditMode: Bool = false
    var followingsCount = 0
    var followersCount = 0
    var secondsCount: Int64 = 0
    
    func deleteArtworksMode(_ isEditMode: Bool) {
        self.isEditMode = isEditMode
    }
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            queryFullArtwork(indexPath.item)
        }
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    var userID: CKRecord.ID?
    var userRecord: CKRecord?
    private var artworkRecords: [ArtWorkInfo] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    var isFetchingData: Bool = false
    var refreshControl = UIRefreshControl()
    var isMyPage: Bool? = nil
    
    @IBAction func swipeRight(_ sender: Any) {
        cancel(0)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if isEditMode {
            let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            actionSheet.addAction(UIAlertAction(title: "删除作品", style: .destructive, handler: { (action) in
                guard let cell = sender as? UICollectionViewCell, let index = self.collectionView.indexPath(for: cell), let infoRecord = self.artworkRecords[index.item].info else {
                    return
                }
                
                var recordIDsToDelete = [infoRecord.recordID]
                
                if let artworkRecord = self.artworkRecords[index.item].artwork {
                    recordIDsToDelete.append(artworkRecord.recordID)
                }
                
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
                
                operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
                    guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil, alert: true) == nil else { return }
                    DispatchQueue.main.async {
                        self.artworkRecords.remove(at: index.item)
                        self.collectionView.deleteItems(at: [index])
                    }
                }
                operation.database = self.database
                self.operationQueue.addOperation(operation)
            }))
            actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            
            present(actionSheet, animated: true)
        }
        
        return isEditMode ? false : true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self, selector: #selector(type(of:self).userCacheDidChange(_:)),
            name: .userCacheDidChange, object: nil)
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(type(of: self).fetchData(_:)), for: UIControl.Event.valueChanged)
        collectionView.addSubview(refreshControl)
        
        fetchData(0)
    }
    
    
    @IBAction func fetchData(_ sender: Any) {
        operationQueue.cancelAllOperations()
        artworkRecords = []
        
        if let userID = userID {
            self.updateWithRecordID(userID)
        } else {
            CKContainer.default().fetchUserRecordID { (recordID, error) in
                if let recordID = recordID {
                    self.userID = recordID
                    self.updateWithRecordID(recordID)
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func userCacheDidChange(_ notification: Notification) {
        self.collectionView.reloadData()
    }
    
    func fetchUserRecord(_ userID: CKRecord.ID) {
        let fetchRecordsOp = CKFetchRecordsOperation(recordIDs: [userID])
        fetchRecordsOp.fetchRecordsCompletionBlock = {recordsByRecordID, error in
            
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil,
                let userRecord = recordsByRecordID?[userID]  else { return }
            
            DispatchQueue.main.sync {
                self.userRecord = userRecord
                if let myID = (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord?.recordID.recordName, self.userRecord?.recordID.recordName == myID {
                    self.isMyPage = true
                } else {
                    self.isMyPage = false
                }
                self.collectionView.reloadData()
            }
        }
        fetchRecordsOp.database = database
        operationQueue.addOperation(fetchRecordsOp)
        
        
        var tmpFollowers:[CKRecord] = []
        let followerQuery = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "followed = %@", userID))
        let queryFollowersOp = CKQueryOperation(query: followerQuery)
        queryFollowersOp.desiredKeys = []
        queryFollowersOp.resultsLimit = 999
        queryFollowersOp.recordFetchedBlock = { (followerRecord) in
            tmpFollowers.append(followerRecord)
        }
        queryFollowersOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            DispatchQueue.main.sync {
                self.followersCount = tmpFollowers.count
                
                let attribFollower = NSMutableAttributedString(string: "\(self.followersCount)", attributes: [.font: UIFont(name: "Helvetica", size: 24.0)!, .foregroundColor: UIColor.white])
                attribFollower.append(NSMutableAttributedString(string: "粉丝", attributes: [.font: UIFont(name: "Helvetica", size: 15.0)!, .foregroundColor: UIColor.white]))
                (self.collectionView.visibleSupplementaryViews(ofKind: "UICollectionElementKindSectionHeader").first as? UserInfoHeaderV)?.followersButton.setAttributedTitle(attribFollower, for: .normal)
            }
        }
        queryFollowersOp.database = self.database
        operationQueue.addOperation(queryFollowersOp)
        
        var tmpFollowings:[CKRecord] = []
        let followingQuery = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "creatorUserRecordID = %@", userID))
        let queryFollowingsOp = CKQueryOperation(query: followingQuery)
        queryFollowingsOp.desiredKeys = []
        queryFollowingsOp.resultsLimit = 999
        queryFollowingsOp.recordFetchedBlock = { (followRecord) in
            tmpFollowings.append(followRecord)
        }
        queryFollowingsOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            DispatchQueue.main.sync {
                self.followingsCount = tmpFollowings.count
                let attribFollowing = NSMutableAttributedString(string: "\(self.followingsCount)", attributes: [.font: UIFont(name: "Helvetica", size: 24.0)!, .foregroundColor: UIColor.white])
                attribFollowing.append(NSMutableAttributedString(string: "关注", attributes: [.font: UIFont(name: "Helvetica", size: 15.0)!, .foregroundColor: UIColor.white]))
                
                (self.collectionView.visibleSupplementaryViews(ofKind: "UICollectionElementKindSectionHeader").first as? UserInfoHeaderV)?.followingsButton.setAttributedTitle(attribFollowing, for: .normal)
                
            }
        }
        queryFollowingsOp.database = self.database
        operationQueue.addOperation(queryFollowingsOp)
    }
    
    var followRecord: CKRecord? = nil
    
    func queryFollowRecord(_ yourID: CKRecord.ID) {
        guard let myInfoRecord = (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord else {
            return
        }
        
        let query = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "followed = %@ && creatorUserRecordID = %@", yourID, myInfoRecord.recordID))
        let queryMessagesOp = CKQueryOperation(query: query)
        
        queryMessagesOp.recordFetchedBlock = { (record) in
            DispatchQueue.main.sync {
                self.followRecord = record
                self.collectionView.reloadData()
            }
        }
        queryMessagesOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
        }
        queryMessagesOp.database = self.database
        self.operationQueue.addOperation(queryMessagesOp)
    }
    
    func updateWithRecordID(_ userID: CKRecord.ID) {
        isFetchingData = true
        
        queryFollowRecord(userID)
        fetchUserRecord(userID)
        
        var tmpArtworkRecords:[ArtWorkInfo] = []
        
        let query = CKQuery(recordType: "ArtworkInfo", predicate: NSPredicate(format: "creatorUserRecordID = %@", userID))
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [byCreation]
        
        let queryInfoOp = CKQueryOperation(query: query)
        queryInfoOp.resultsLimit = 999
        queryInfoOp.recordFetchedBlock = { (infoRecord) in
            var artWorkInfo = ArtWorkInfo()
            artWorkInfo.info = infoRecord
            tmpArtworkRecords.append(artWorkInfo)
        }
        queryInfoOp.queryCompletionBlock = { (cursor, error) in
            DispatchQueue.main.sync {
                self.refreshControl.endRefreshing()
            }
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            self.cursor = cursor
            
            DispatchQueue.main.sync {
                self.artworkRecords.append(contentsOf: tmpArtworkRecords)
                self.isFetchingData = false
                self.secondsCount = tmpArtworkRecords.compactMap({ $0.info?["seconds"] as? Int64 }).reduce(0, +)
                self.collectionView.reloadData()
            }
        }
        queryInfoOp.database = self.database
        self.operationQueue.addOperation(queryInfoOp)
        
    }
    
    @IBAction func done(bySegue: UIStoryboardSegue) {
        if bySegue.identifier == "" {
//            saveRecord()
        }
    }
    
    @IBAction func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
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
        queryArtworkOp.desiredKeys = ["littleCover"]
        queryArtworkOp.recordFetchedBlock = { (artworkRecord) in
            DispatchQueue.main.sync {
                self.artworkRecords[row].artwork = artworkRecord
                
                if self.collectionView.indexPathsForVisibleItems.contains(IndexPath(item: row, section: 0)) {
                    self.collectionView.reloadItems(at: [IndexPath(item: row, section: 0)])
                }
            }
        }
        queryArtworkOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
        }
        queryArtworkOp.database = self.database
        self.operationQueue.addOperation(queryArtworkOp)
        
        
        let queryFullArtworkOp = CKQueryOperation(query: query)
        queryFullArtworkOp.desiredKeys = ["thumbnail"]
        queryFullArtworkOp.recordFetchedBlock = { (artworkRecord) in
            if let ckasset = artworkRecord["thumbnail"] as? CKAsset {
                DispatchQueue.main.sync {
                    self.artworkRecords[row].artwork?["thumbnail"] = ckasset

                    if self.collectionView.indexPathsForVisibleItems.contains(IndexPath(item: row, section: 0)) {
                        self.collectionView.reloadItems(at: [IndexPath(item: row, section: 0)])
                    }
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

    
    @IBAction func follow(_ sender: Any) {
        guard let yourID = userID, let myInfoRecord = (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord else {
            return
        }
        
        let query = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "followed = %@ && creatorUserRecordID = %@", yourID, myInfoRecord.recordID))
        let queryMessagesOp = CKQueryOperation(query: query)
        
        queryMessagesOp.recordFetchedBlock = { (record) in
            DispatchQueue.main.sync {
                self.followRecord = record
            }
        }
        queryMessagesOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            if self.followRecord != nil {
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [self.followRecord!.recordID])
                
                operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
                    guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil, alert: true) == nil else { return }
                    
                    DispatchQueue.main.sync {
                        self.followRecord = nil
                        self.collectionView.reloadData()
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
                        self.followRecord = newRecord
                        self.collectionView.reloadData()
                    }
                }
                operation.database = self.database
                self.operationQueue.addOperation(operation)
            }
        }
        queryMessagesOp.database = self.database
        self.operationQueue.addOperation(queryMessagesOp)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerV = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "UserInfo Header", for: indexPath)
        if let headerV = headerV as? UserInfoHeaderV {
            
            headerV.myInfo.isHidden = !(isMyPage ?? false)
            headerV.herInfo.isHidden = isMyPage ?? true
            headerV.followButton.setTitle(followRecord != nil ? "取消关注" : "关注", for: .normal)
            
            let imageURL = (userRecord?["avatarImage"] as? CKAsset)?.fileURL
            let nickName = userRecord?["nickName"] as? String
            let sex = userRecord?["sex"] as? String
            let location = userRecord?["location"] as? String
            let sign = userRecord?["sign"] as? String
            
            if let imagePath = imageURL?.path {
                let advTimeGif = UIImage(contentsOfFile: imagePath)
                headerV.avatarV.image = advTimeGif
            }
            
            headerV.nickNameV.text = nickName
            let attribFollowing = NSMutableAttributedString(string: "\(followingsCount)", attributes: [.font: UIFont(name: "Helvetica", size: 24.0)!, .foregroundColor: UIColor.white])
            attribFollowing.append(NSMutableAttributedString(string: "关注", attributes: [.font: UIFont(name: "Helvetica", size: 15.0)!, .foregroundColor: UIColor.white]))
            headerV.followingsButton.setAttributedTitle(attribFollowing, for: .normal)
            let attribFollower = NSMutableAttributedString(string: "\(followersCount)", attributes: [.font: UIFont(name: "Helvetica", size: 24.0)!, .foregroundColor: UIColor.white])
            attribFollower.append(NSMutableAttributedString(string: "粉丝", attributes: [.font: UIFont(name: "Helvetica", size: 15.0)!, .foregroundColor: UIColor.white]))
            headerV.followersButton.setAttributedTitle(attribFollower, for: .normal)
            let attribSeconds = NSMutableAttributedString(string: "\(secondsCount.seconds2String())", attributes: [.font: UIFont(name: "Helvetica", size: 24.0)!, .foregroundColor: UIColor.white])
            attribSeconds.append(NSMutableAttributedString(string: "时间", attributes: [.font: UIFont(name: "Helvetica", size: 15.0)!, .foregroundColor: UIColor.white]))
            headerV.secondsButton.setAttributedTitle(attribSeconds, for: .normal)
            headerV.signV.text = sign
            headerV.delegate = self
        }
        return headerV
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return artworkRecords.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GifViewCell", for: indexPath)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        queryFullArtwork(indexPath.item)
        if let thumbnail = artworkRecords[indexPath.item].artwork?["thumbnail"] as? CKAsset, let imageData = try? Data(contentsOf: thumbnail.fileURL), let cell = cell as? GifViewCell {
            cell.imageV.image = UIImage.gifImageWithData(imageData)
        } else if let littleCover = artworkRecords[indexPath.item].artwork?["littleCover"] as? CKAsset, let imageData = try? Data(contentsOf: littleCover.fileURL), let cell = cell as? GifViewCell {
            cell.imageV.image = UIImage(data: imageData)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? GifViewCell {
            cell.imageV.image = nil
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellWidth = (collectionView.bounds.width - 2) / 3
        return CGSize(width: cellWidth, height: cellWidth / 3.0 * 4)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "artworks segue" {
            if let artworksVC = segue.destination as? MainVC, let selectedItem = collectionView.indexPathsForSelectedItems?.first?.item {
                artworksVC.userID = userID
                artworksVC.selectedRow = selectedItem
            }
        } else if segue.identifier == "me to dialog" {
            if let dialogVC = segue.destination as? DialogVC {
                dialogVC.dialogRecord = nil
                dialogVC.yourRecord = userRecord
            }
        } else if segue.identifier == "me to followers" {
            if let followersVC = segue.destination as? FollowersVC {
                //                dialogVC.dialogID = dialogInfos[selectedRow.row].dialog?.recordID
                followersVC.userID = self.userID
                followersVC.isFollowers = true
            }
        } else if segue.identifier == "me to followings" {
            if let followersVC = segue.destination as? FollowersVC {
                //                dialogVC.dialogID = dialogInfos[selectedRow.row].dialog?.recordID
                followersVC.userID = self.userID
                followersVC.isFollowers = false
            }
        }
    }
}


class GifViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageV: UIImageView! {
        didSet {
            imageV.contentMode = .scaleAspectFill
        }
    }
    
}

class UserInfoHeaderV: UICollectionReusableView {
    
    @IBOutlet weak var avatarV: UIImageView! {
        didSet {
            avatarV.contentMode = .scaleAspectFill
            avatarV.layer.cornerRadius = avatarV.bounds.width/10
            avatarV.layer.masksToBounds = true
            avatarV.layer.borderColor = #colorLiteral(red: 0.3529411765, green: 0.3450980392, blue: 0.4235294118, alpha: 1)
            avatarV.layer.borderWidth = 1
        }
    }
    
    @IBOutlet weak var nickNameV: UILabel!
    @IBOutlet weak var signV: UILabel!
    @IBOutlet weak var positionV: UILabel!
    @IBOutlet weak var deleteArtworksButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var followButton: UIButton!
    @IBOutlet weak var messageButton: UIButton!
    
    @IBOutlet weak var followingsButton: UIButton!
    @IBOutlet weak var followersButton: UIButton!
    @IBOutlet weak var secondsButton: UIButton!
    
    
    @IBOutlet weak var myInfo: UIStackView!
    @IBOutlet weak var herInfo: UIStackView!
    
    weak open var delegate: HeaderViewDelegate?
    
    var isEditMode = false {
        didSet {
            deleteArtworksButton.setTitle(!isEditMode ? "删除作品" : "完成删除", for: .normal)
        }
    }
    
    @IBAction func deleteArtworks(_ sender: Any) {
        isEditMode = !isEditMode
        delegate?.deleteArtworksMode(isEditMode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit() {
        
    }
}

public protocol HeaderViewDelegate : NSObjectProtocol {
    func deleteArtworksMode(_ isEditMode: Bool)
}
