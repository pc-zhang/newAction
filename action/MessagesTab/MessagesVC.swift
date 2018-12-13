//
//  MessagesVC.swift
//  action
//
//  Created by zpc on 2018/11/12.
//  Copyright © 2018 zpc. All rights reserved.
//

import UIKit
import CloudKit

class MessagesVC: UITableViewController {
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    private var dialogs: [CKRecord] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var isFetchingData: Bool = false
    var artistID: CKRecord.ID? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl?.addTarget(self, action: #selector(type(of: self).fetchData(_:)), for: UIControl.Event.valueChanged)

        CKContainer.default().fetchUserRecordID { (recordID, error) in
            if let recordID = recordID {
                self.artistID = recordID
                self.fetchData(0)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func awakeFromNib() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(type(of:self).newMessage(_:)),
            name: .newMessage, object: nil)
    }
    
    @objc func newMessage(_ notification: Notification) {
        tabBarItem.badgeValue = "1"
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 110 : 70
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : dialogs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = indexPath.section == 0 ? "messages header" : "dialog"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)

        // Configure the cell...

        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if indexPath.section != 1 {
            return
        }
        
        if let cell = cell as? DialogCell {
            if let artistID = artistID, artistID != (dialogs[indexPath.row]["receiver"] as? CKRecord.Reference)?.recordID, let path = (dialogs[indexPath.row]["receiverAvatar"] as? CKAsset)?.fileURL.path {
                cell.avatarV.image = UIImage(contentsOfFile: path)
                cell.nickNameLabel.text = dialogs[indexPath.row]["receiverNickName"] as? String
            }
            if let artistID = artistID, artistID == (dialogs[indexPath.row]["receiver"] as? CKRecord.Reference)?.recordID, let path = (dialogs[indexPath.row]["senderAvatar"] as? CKAsset)?.fileURL.path {
                cell.avatarV.image = UIImage(contentsOfFile: path)
                cell.nickNameLabel.text = dialogs[indexPath.row]["senderNickName"] as? String
            }
            
            cell.lastMessageLabel.text = (dialogs[indexPath.row]["texts"] as? [String])?.last
            if let date = dialogs[indexPath.row].modificationDate {
                cell.lastMessageTimeLabel.text = dateFormatter.string(from: date)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section != 0
    }
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd mm:ss"
        return dateFormatter
    }()
    
    func otherDialogist(_ dialogists: [CKRecord.Reference], _ artistID: CKRecord.ID) -> CKRecord.ID? {
        let dialogistIDs = dialogists.compactMap { (dialogistRef) -> CKRecord.ID? in
            if dialogistRef.recordID != artistID {
                return dialogistRef.recordID
            }
            
            return nil
        }
        
        return dialogistIDs.first
    }

    @IBAction func fetchData(_ sender: Any) {
        guard let artistID = artistID else {
            return
        }
        
        operationQueue.cancelAllOperations()
        isFetchingData = true
        dialogs = []
        var tmpdialogs:[CKRecord] = []
        
        let query = CKQuery(recordType: "Dialog", predicate: NSPredicate(format: "creatorUserRecordID = %@", artistID))
        let byModify = NSSortDescriptor(key: "modificationDate", ascending: false)
        query.sortDescriptors = [byModify]
        let queryDialogsOp = CKQueryOperation(query: query)
        
        queryDialogsOp.resultsLimit = 99
        queryDialogsOp.recordFetchedBlock = { (dialogRecord) in
            tmpdialogs.append(dialogRecord)
        }
        queryDialogsOp.queryCompletionBlock = { (cursor, error) in
            DispatchQueue.main.sync {
                self.refreshControl?.endRefreshing()
            }
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            DispatchQueue.main.sync {
                self.dialogs.append(contentsOf: tmpdialogs)
                self.tableView.reloadData()
                self.isFetchingData = false
            }
        }
        queryDialogsOp.database = self.database
        self.operationQueue.addOperation(queryDialogsOp)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "show dialog" {
            if let dialogVC = segue.destination as? DialogVC, let selectedRow = self.tableView.indexPathForSelectedRow {
                dialogVC.dialogRecord = dialogs[selectedRow.row]
                dialogVC.yourRecord = nil
            }
        } else if segue.identifier == "messages to followers" {
            if let followersVC = segue.destination as? FollowersVC {
                //                dialogVC.dialogID = dialogInfos[selectedRow.row].dialog?.recordID
                followersVC.userID = (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord?.recordID
                followersVC.isFollowers = true
            }
        }
    }

}


class DialogCell: UITableViewCell {
    @IBOutlet weak var avatarV: UIImageView! {
        didSet {
            avatarV.layer.cornerRadius = avatarV.layer.bounds.width / 2
        }
    }
    @IBOutlet weak var nickNameLabel: UILabel!
    @IBOutlet weak var lastMessageLabel: UILabel!
    @IBOutlet weak var lastMessageTimeLabel: UILabel!
}
