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

fileprivate struct UserPageArtWorkInfo {
    var isPrefetched: Bool = false
    var artwork: CKRecord? = nil
}

class UserInfoVC : UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching, HeaderViewDelegate {
    
    var isEditMode: Bool = false
    
    func deleteArtworksMode(_ isEditMode: Bool) {
        self.isEditMode = isEditMode
    }
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            queryArtworkOtherInfo(indexPath.item)
        }
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    private var userCacheOrNil: UserLocalCache? {
        return (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil
    }
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    var userID: CKRecord.ID?
    private var artworkRecords: [UserPageArtWorkInfo] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    var isFetchingData: Bool = false
    var refreshControl = UIRefreshControl()
    
    @IBAction func swipeRight(_ sender: Any) {
        cancel(0)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if isEditMode {
            let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            actionSheet.addAction(UIAlertAction(title: "删除作品", style: .destructive, handler: { (action) in
                guard let cell = sender as? UICollectionViewCell, let index = self.collectionView.indexPath(for: cell), let artworkRecord = self.artworkRecords[index.item].artwork else {
                    return
                }
                
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [artworkRecord.recordID])
                
                operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
                    guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: [artworkRecord.recordID], alert: true) == nil else { return }
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
    
    func updateWithRecordID(_ recordID: CKRecord.ID) {

        isFetchingData = true
        var tmpArtworkRecords:[UserPageArtWorkInfo] = []
        
        let query = CKQuery(recordType: "Artwork", predicate: NSPredicate(format: "creatorUserRecordID = %@", recordID))
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [byCreation]
        let queryArtworksOp = CKQueryOperation(query: query)
        
        queryArtworksOp.desiredKeys = []
        queryArtworksOp.resultsLimit = 6
        queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
            var artWorkInfo = UserPageArtWorkInfo()
            artWorkInfo.artwork = artworkRecord
            tmpArtworkRecords.append(artWorkInfo)
        }
        queryArtworksOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            self.cursor = cursor
            
            DispatchQueue.main.sync {
                self.artworkRecords.append(contentsOf: tmpArtworkRecords)
                self.isFetchingData = false
                self.collectionView.reloadData()
                
                self.refreshControl.endRefreshing()
            }
        }
        queryArtworksOp.database = self.database
        self.operationQueue.addOperation(queryArtworksOp)
        
    }
    
    @IBAction func done(bySegue: UIStoryboardSegue) {
        if bySegue.identifier == "" {
//            saveRecord()
        }
    }
    
    @IBAction func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
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
        
        
        let fetchArtworkOp = CKFetchRecordsOperation(recordIDs: [artworkRecord.recordID])
        fetchArtworkOp.desiredKeys = ["thumbnail"]
        fetchArtworkOp.fetchRecordsCompletionBlock = { (recordsByRecordID, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            if let artworkRecord = recordsByRecordID?[artworkRecord.recordID] {
                DispatchQueue.main.async {
                    self.artworkRecords[row].artwork = artworkRecord
                    if self.collectionView.indexPathsForVisibleItems.contains(IndexPath(item: row, section: 0)) {
                        self.collectionView.reloadItems(at: [IndexPath(item: row, section: 0)])
                    }
                }
            }
            
        }
        fetchArtworkOp.database = self.database
        self.operationQueue.addOperation(fetchArtworkOp)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerV = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "UserInfo Header", for: indexPath)
        if let headerV = headerV as? UserInfoHeaderV {
            var imageURL: URL?
            var nickName: String?
            var sex: String?
            var location: String?
            var sign: String?
            
            userCacheOrNil?.performReaderBlockAndWait {
                imageURL = (userCacheOrNil!.userRecord?["avatarImage"] as? CKAsset)?.fileURL
                nickName = userCacheOrNil!.userRecord?["nickName"] as? String
                sex = userCacheOrNil!.userRecord?["sex"] as? String
                location = userCacheOrNil!.userRecord?["location"] as? String
                sign = userCacheOrNil!.userRecord?["sign"] as? String
            }
            
            if let imagePath = imageURL?.path {
                let advTimeGif = UIImage(contentsOfFile: imagePath)
                headerV.avatarV.image = advTimeGif
            }
            
            headerV.nickNameV.text = nickName
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
        queryArtworkOtherInfo(indexPath.item)
        if let thumbnail = artworkRecords[indexPath.item].artwork?["thumbnail"] as? CKAsset, let imageData = try? Data(contentsOf: thumbnail.fileURL), let cell = cell as? GifViewCell {
            cell.imageV.image = UIImage.gifImageWithData(imageData)
            
            if true {
                let surplus = artworkRecords.count - (indexPath.row + 1)
                
                if let cursor = cursor, !isFetchingData, surplus < 6 {
                    isFetchingData = true
                    
                    let recordsCountBefore = artworkRecords.count
                    var tmpArtworkRecords:[UserPageArtWorkInfo] = []
                    
                    let queryArtworksOp = CKQueryOperation(cursor: cursor)
                    queryArtworksOp.desiredKeys = []
                    queryArtworksOp.resultsLimit = 6 - surplus
                    queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
                        var artWorkInfo = UserPageArtWorkInfo()
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
                                IndexPath(item: $0, section: 0)
                            }
                            
                            self.isFetchingData = false
                            self.collectionView.insertItems(at: indexPaths)
                        }
                    }
                }
            }
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
    @IBOutlet weak var idV: UILabel!
    @IBOutlet weak var friendsV: UILabel!
    @IBOutlet weak var signV: UILabel!
    @IBOutlet weak var positionV: UILabel!
    @IBOutlet weak var deleteArtworksButton: UIButton!
    
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
