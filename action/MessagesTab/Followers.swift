//
//  MessagesVC.swift
//  action
//
//  Created by zpc on 2018/11/12.
//  Copyright © 2018 zpc. All rights reserved.
//

import UIKit
import CloudKit

class FollowersVC: UITableViewController {
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    private var followerRecords: [CKRecord] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    var isFetchingData: Bool = false

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

        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if let cell = cell as? FollowerCell {
            if let path = (followerRecords[indexPath.row]["avatar"] as? CKAsset)?.fileURL.path {
                cell.avatarV.image = UIImage(contentsOfFile: path)
            }
            cell.nickNameLabel.text = followerRecords[indexPath.row]["nickName"] as? String
            cell.signLabel.text = followerRecords[indexPath.row]["sign"] as? String
//            if let date = followerRecords[indexPath.row].creationDate {
//            }
        }
        
        let surplus = followerRecords.count - (indexPath.row + 1)
        if let cursor = cursor, !isFetchingData, surplus < 12 {
            isFetchingData = true
            let recordsCountBefore = followerRecords.count
            var tmpArtworkRecords:[CKRecord] = []
            
            let queryArtworksOp = CKQueryOperation(cursor: cursor)
            queryArtworksOp.resultsLimit = 12 - surplus
            queryArtworksOp.recordFetchedBlock = { (followerRecord) in
                DispatchQueue.main.sync {
                    tmpArtworkRecords.append(followerRecord)
                }
            }
            queryArtworksOp.queryCompletionBlock = { (cursor, error) in
                guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
                self.cursor = cursor
                
                DispatchQueue.main.sync {
                    self.followerRecords.append(contentsOf: tmpArtworkRecords)
                    let indexPaths = (recordsCountBefore ..< self.followerRecords.count).map {
                        IndexPath(row: $0, section: 0)
                    }
                    
                    self.isFetchingData = false
                    self.tableView.insertRows(at: indexPaths, with: .none)
                }
            }
            queryArtworksOp.database = self.database
            self.operationQueue.addOperation(queryArtworksOp)
            
        }
    }
    
    @IBAction func fetchData(_ sender: Any) {
        guard let artistID = (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord?.recordID else {
            return
        }
        
        isFetchingData = true
        var tmpdialogInfos:[CKRecord] = []
        
        let query = CKQuery(recordType: "Follow", predicate: NSPredicate(format: "followed = %@", artistID))
        
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [byCreation]
        let queryFollowersOp = CKQueryOperation(query: query)
        
        queryFollowersOp.resultsLimit = 6
        queryFollowersOp.recordFetchedBlock = { (followerRecord) in
            tmpdialogInfos.append(followerRecord)
        }
        queryFollowersOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            self.cursor = cursor
            
            DispatchQueue.main.sync {
                self.followerRecords.append(contentsOf: tmpdialogInfos)
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
                userInfoVC.userID = self.followerRecords[selectedRow.row].creatorUserRecordID
            }
        }
    }

}


class FollowerCell: UITableViewCell {
    
    @IBOutlet weak var avatarV: UIImageView!
    @IBOutlet weak var nickNameLabel: UILabel!
    @IBOutlet weak var signLabel: UILabel!

}
