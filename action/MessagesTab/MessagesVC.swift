//
//  MessagesVC.swift
//  action
//
//  Created by zpc on 2018/11/12.
//  Copyright © 2018 zpc. All rights reserved.
//

import UIKit
import CloudKit

fileprivate struct DialogInfo {
    var isPrefetched: Bool = false
    var dialogist: CKRecord? = nil
    var lastMessage: CKRecord? = nil
    var dialog: CKRecord? = nil
}

class MessagesVC: UITableViewController {
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    private var dialogInfos: [DialogInfo] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    var isFetchingData: Bool = false
    var artistID: CKRecord.ID? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        CKContainer.default().fetchUserRecordID { (recordID, error) in
            if let recordID = recordID {
                self.artistID = recordID
                self.fetchData(0)
            }
        }
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

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : dialogInfos.count
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
        
        queryDialogOtherInfo(indexPath.row)
        
        if let cell = cell as? DialogCell {
            if let path = (dialogInfos[indexPath.row].dialogist?["avatarImage"] as? CKAsset)?.fileURL.path {
                cell.avatarV.image = UIImage(contentsOfFile: path)
            }
            cell.nickNameLabel.text = dialogInfos[indexPath.row].dialogist?["nickName"] as? String
            cell.lastMessageLabel.text = dialogInfos[indexPath.row].lastMessage?["text"] as? String
            if let date = dialogInfos[indexPath.row].lastMessage?.creationDate {
                cell.lastMessageTimeLabel.text = dateFormatter.string(from: date)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section != 0
    }
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }()
    
    func queryDialogOtherInfo(_ row: Int)
    {
        guard let dialogRecord = dialogInfos[row].dialog else {
            return
        }
        
        if dialogInfos[row].isPrefetched == true {
            return
        }
        dialogInfos[row].isPrefetched = true
        
        if let dialogists = dialogRecord["dialogists"] as? [CKRecord.Reference], let artistID = artistID, let dialogistID = otherDialogist(dialogists, artistID) {
            
            let fetchArtistOp = CKFetchRecordsOperation(recordIDs: [dialogistID])
            fetchArtistOp.desiredKeys = ["avatarImage", "nickName"]
            fetchArtistOp.fetchRecordsCompletionBlock = { (recordsByRecordID, error) in
                guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
                
                DispatchQueue.main.async {
                    self.dialogInfos[row].dialogist = recordsByRecordID?[dialogistID]
                    self.reloadVisibleRow(row)
                }
            }
            fetchArtistOp.database = self.database
            self.operationQueue.addOperation(fetchArtistOp)
        }
        
        var lastMessage: CKRecord? = nil
        let query = CKQuery(recordType: "Message", predicate: NSPredicate(format: "dialog = %@", dialogRecord.recordID))
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [byCreation]
        let queryMessagesOp = CKQueryOperation(query: query)
        queryMessagesOp.desiredKeys = ["text"]
        queryMessagesOp.resultsLimit = 1
        queryMessagesOp.recordFetchedBlock = { (messageRecord) in
            lastMessage = messageRecord
        }
        queryMessagesOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            DispatchQueue.main.async {
                self.dialogInfos[row].lastMessage = lastMessage
                self.reloadVisibleRow(row)
            }
        }
        queryMessagesOp.database = self.database
        self.operationQueue.addOperation(queryMessagesOp)
    }
    
    func reloadVisibleRow(_ row: Int) {
        let indexPath = IndexPath(row: row, section: 1)
        if dialogInfos[row].dialog != nil && dialogInfos[row].dialogist != nil && dialogInfos[row].lastMessage != nil {
            if tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false {
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
    }
    
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
        
        isFetchingData = true
        var tmpdialogInfos:[DialogInfo] = []
        
        let query = CKQuery(recordType: "Dialog", predicate: NSPredicate(format: "%@ in dialogists", artistID))
        
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [byCreation]
        let queryDialogsOp = CKQueryOperation(query: query)
        
        queryDialogsOp.desiredKeys = ["dialogists"]
        queryDialogsOp.resultsLimit = 6
        queryDialogsOp.recordFetchedBlock = { (dialogRecord) in
            var dialogInfo = DialogInfo()
            dialogInfo.dialog = dialogRecord
            tmpdialogInfos.append(dialogInfo)
        }
        queryDialogsOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            self.cursor = cursor
        }
        queryDialogsOp.database = self.database
        self.operationQueue.addOperation(queryDialogsOp)
        
        DispatchQueue.global().async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            DispatchQueue.main.async {
                self.dialogInfos.append(contentsOf: tmpdialogInfos)
                self.isFetchingData = false
                self.tableView.reloadData()
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "show dialog" {
            if let dialogVC = segue.destination as? DialogVC, let selectedRow = self.tableView.indexPathForSelectedRow {
                dialogVC.dialogID = dialogInfos[selectedRow.row].dialog?.recordID
                dialogVC.yourRecord = dialogInfos[selectedRow.row].dialogist
            }
        }
    }

}


class DialogCell: UITableViewCell {
    @IBOutlet weak var avatarV: UIImageView!
    @IBOutlet weak var nickNameLabel: UILabel!
    @IBOutlet weak var lastMessageLabel: UILabel!
    @IBOutlet weak var lastMessageTimeLabel: UILabel!
}
