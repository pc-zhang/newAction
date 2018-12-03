//
//  MessagesVC.swift
//  action
//
//  Created by zpc on 2018/11/12.
//  Copyright © 2018 zpc. All rights reserved.
//

import UIKit
import CloudKit

struct FollowerInfo {
    var isPrefetched = false
    var followRecord: CKRecord? = nil
    var artistRecord: CKRecord? = nil
    var isFollowMe = false
    var myFollowRecord: CKRecord? = nil
}

class FollowersVC: UITableViewController, UITableViewDataSourcePrefetching, FollowerCellDelegate {
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    private var followerRecords: [FollowerInfo] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    var isFetchingData: Bool = false
    var userID: CKRecord.ID? = nil
    var isFollowers: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchData(0)
    }
    

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return followerRecords.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "follower"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)

        // Configure the cell...
        if let followerCell = cell as? FollowerCell {
            followerCell.delegate = self
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        fetchArtistRecord(indexPath.row)
        
        if let cell = cell as? FollowerCell {
            if let path = (followerRecords[indexPath.row].artistRecord?["littleAvatar"] as? CKAsset)?.fileURL.path {
                cell.avatarV.image = UIImage(contentsOfFile: path)
            }
            cell.nickNameLabel.text = followerRecords[indexPath.row].artistRecord?["nickName"] as? String
            cell.signLabel.text = followerRecords[indexPath.row].artistRecord?["sign"] as? String
            cell.followButton.setTitle((followerRecords[indexPath.row].myFollowRecord != nil) ? (followerRecords[indexPath.row].isFollowMe ? "互相关注" : "取消关注") : "关注", for: .normal)
        }
    }
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            fetchArtistRecord(indexPath.item)
        }
    }
    
    
    func fetchArtistRecord(_ row: Int) {
        guard let followRecord = followerRecords[row].followRecord, let followedID = (followRecord["followed"] as? CKRecord.Reference)?.recordID, let followerID = followRecord.creatorUserRecordID else {
            return
        }
        
        if followerRecords[row].isPrefetched == true {
            return
        }
        followerRecords[row].isPrefetched = true
        
        var userID: CKRecord.ID
        if isFollowers {
            userID = followerID
        } else {
            userID = followedID
        }
        
        let fetchRecordsOp = CKFetchRecordsOperation(recordIDs: [userID])
        fetchRecordsOp.desiredKeys = ["littleAvatar", "nickName", "sign"]
        fetchRecordsOp.fetchRecordsCompletionBlock = {recordsByRecordID, error in
            
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil,
                let userRecord = recordsByRecordID?[userID]  else { return }
            
            DispatchQueue.main.sync {
                self.followerRecords[row].artistRecord = userRecord
                self.tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
            }
        }
        fetchRecordsOp.database = database
        operationQueue.addOperation(fetchRecordsOp)
        
        
        guard let myID = (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord?.recordID else {
            return
        }
        
        let queryMyFollow = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "followed = %@ && creatorUserRecordID = %@", userID, myID))
        let queryMyFollowOp = CKQueryOperation(query: queryMyFollow)
        
        queryMyFollowOp.recordFetchedBlock = { (record) in
            DispatchQueue.main.sync {
                self.followerRecords[row].myFollowRecord = record
                self.tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
            }
        }
        queryMyFollowOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
        }
        queryMyFollowOp.database = self.database
        self.operationQueue.addOperation(queryMyFollowOp)
        
        let queryFollowMe = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "followed = %@ && creatorUserRecordID = %@", myID, userID))
        let queryFollowMeOp = CKQueryOperation(query: queryFollowMe)
        
        queryFollowMeOp.recordFetchedBlock = { (record) in
            DispatchQueue.main.sync {
                self.followerRecords[row].isFollowMe = true
                self.tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
            }
        }
        queryFollowMeOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
        }
        queryFollowMeOp.database = self.database
        self.operationQueue.addOperation(queryFollowMeOp)

    }
    
    @IBAction func fetchData(_ sender: Any) {
        guard let artistID = userID else {
            return
        }
        
        isFetchingData = true
        var tmpFollowerRecords:[FollowerInfo] = []
        
        var query: CKQuery
        if isFollowers {
            query = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "followed = %@", artistID))
        } else {
            query = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "creatorUserRecordID = %@", artistID))
        }
        
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [byCreation]
        let queryFollowersOp = CKQueryOperation(query: query)
        
        queryFollowersOp.resultsLimit = 999
        queryFollowersOp.recordFetchedBlock = { (followRecord) in
            var followInfo = FollowerInfo()
            followInfo.followRecord = followRecord
            tmpFollowerRecords.append(followInfo)
        }
        queryFollowersOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            self.cursor = cursor
            
            DispatchQueue.main.sync {
                self.followerRecords.append(contentsOf: tmpFollowerRecords)
                self.isFetchingData = false
                self.tableView.reloadData()
            }
        }
        queryFollowersOp.database = self.database
        operationQueue.addOperation(queryFollowersOp)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "follower to me" {
            if let userInfoVC = segue.destination as? UserInfoVC, let selectedRow = self.tableView.indexPathForSelectedRow {
                userInfoVC.userID = self.followerRecords[selectedRow.row].artistRecord?.recordID
            }
        }
    }
    
    func follow(_ cell: UITableViewCell) {
        guard let row = tableView.indexPath(for: cell)?.row, let yourID = followerRecords[row].artistRecord?.recordID else {
            return
        }
        
        
        if self.followerRecords[row].myFollowRecord != nil {
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [self.followerRecords[row].myFollowRecord!.recordID])
            
            operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
                guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil, alert: true) == nil else { return }
                
                DispatchQueue.main.sync {
                    self.followerRecords[row].myFollowRecord = nil
                    self.tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
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
                    self.followerRecords[row].myFollowRecord = newRecord
                    self.tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
                }
            }
            operation.database = self.database
            self.operationQueue.addOperation(operation)
        }
        
    }

}


class FollowerCell: UITableViewCell {
    
    @IBOutlet weak var avatarV: UIImageView!
    @IBOutlet weak var nickNameLabel: UILabel!
    @IBOutlet weak var signLabel: UILabel!
    @IBOutlet weak var followButton: UIButton!
    
    @IBAction func follow(_ sender: Any) {
        delegate?.follow(self)
    }
    
    weak open var delegate: FollowerCellDelegate?

}

public protocol FollowerCellDelegate : NSObjectProtocol {
    func follow(_ cell: UITableViewCell)
}
