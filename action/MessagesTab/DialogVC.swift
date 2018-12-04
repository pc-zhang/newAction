//
//  MessagesVC.swift
//  action
//
//  Created by zpc on 2018/11/12.
//  Copyright © 2018 zpc. All rights reserved.
//

import UIKit
import CloudKit


class DialogVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var yourRecord: CKRecord? = nil
    var dialogRecord: CKRecord? = nil
    var myRecord: CKRecord? = {
        return (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord
    }()
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var reviewTextFieldBottomHeight: NSLayoutConstraint!
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        reviewTextFieldBottomHeight.constant = 500
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text {
            sendMessage(text)
        }
        
        reviewTextFieldBottomHeight.constant = 0
        textField.text = nil
        textField.resignFirstResponder()
        return true
    }
    
    
    func newDialog(_ text: String) {
        guard let yourRecord = yourRecord, let myRecord = myRecord else {
            return
        }
        
        let newDialogRecord = CKRecord(recordType: "Dialog")
        newDialogRecord["receiver"] = CKRecord.Reference(recordID: yourRecord.recordID, action: .none)
        if let fileURL = (yourRecord["littleAvatar"] as? CKAsset)?.fileURL {
            newDialogRecord["receiverAvatar"] = CKAsset(fileURL: fileURL)
        }
        if let fileURL = (myRecord["littleAvatar"] as? CKAsset)?.fileURL {
            newDialogRecord["senderAvatar"] = CKAsset(fileURL: fileURL)
        }
        newDialogRecord["senderNickName"] = myRecord["nickName"] as? String
        newDialogRecord["receiverNickName"] = yourRecord["nickName"] as? String
        newDialogRecord["senders"] = [] as? [CKRecord.Reference]
        newDialogRecord["texts"] = [] as? [String]
        
        let operation = CKModifyRecordsOperation(recordsToSave: [newDialogRecord], recordIDsToDelete: nil)
        
        operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
            guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil, alert: true) == nil,
                let newRecord = records?.first else { return }
            
            DispatchQueue.main.sync {
                self.dialogRecord = newRecord
                self.sendMessage(text)
            }
        }
        operation.database = database
        operationQueue.addOperation(operation)
    }
    
    
    func sendMessage(_ text: String) {
        guard let myRecord = myRecord else {
            return
        }
        
        if let dialogRecord = dialogRecord {
            var senders = dialogRecord["senders"] as? [CKRecord.Reference] ?? []
            var texts = dialogRecord["texts"] as? [String] ?? []
            senders.append(CKRecord.Reference(recordID: myRecord.recordID, action: .none))
            texts.append(text)
            dialogRecord["senders"] = senders
            dialogRecord["texts"] = texts
            
            let operation = CKModifyRecordsOperation(recordsToSave: [dialogRecord], recordIDsToDelete: nil)
            
            operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
                guard let newRecord = records?.first else {
                    return
                }
                
                if handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil, alert: true) != nil {
                    
                    DispatchQueue.main.sync {
                        self.dialogRecord = newRecord
                        self.sendMessage(text)
                    }
                    
                    return
                }
                
                DispatchQueue.main.sync {
                    self.dialogRecord = newRecord
                    self.tableView.reloadData()
                    self.tableView.scrollToRow(at: IndexPath(row: self.tableView.numberOfRows(inSection: 0) - 1, section: 0), at: .bottom, animated: false)
                }
            }
            operation.database = database
            operationQueue.addOperation(operation)
            
            return
        }
        
        guard let yourRecord = yourRecord else {
            return
        }
        
        let dialogists = [yourRecord.recordID, myRecord.recordID]
        let query = CKQuery(recordType: "Dialog", predicate: NSPredicate(format: "receiver in %@ && creatorUserRecordID in %@", dialogists, dialogists))
        
        let queryMessagesOp = CKQueryOperation(query: query)
        queryMessagesOp.recordFetchedBlock = { (dialogRecord) in
            DispatchQueue.main.sync {
                self.dialogRecord = dialogRecord
                self.sendMessage(text)
            }
        }
        queryMessagesOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            
            DispatchQueue.main.sync {
                if self.dialogRecord == nil {
                    self.newDialog(text)
                }
            }
        }
        queryMessagesOp.database = self.database
        self.operationQueue.addOperation(queryMessagesOp)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        assert((yourRecord == nil && dialogRecord != nil) || (yourRecord != nil && dialogRecord == nil))
        
        if let yourRecord = yourRecord {
            navigationItem.title = yourRecord["nickName"] as? String
        } else if let receiverID = (dialogRecord?["receiver"] as? CKRecord.Reference)?.recordID, receiverID == myRecord?.recordID {
            navigationItem.title = dialogRecord?["senderNickName"] as? String
        } else {
            navigationItem.title = dialogRecord?["receiverNickName"] as? String
        }
        
        fetchData(0)
    }
    
    
    override func awakeFromNib() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(type(of:self).newMessage(_:)),
            name: .newMessage, object: nil)
    }

    @objc func newMessage(_ notification: Notification) {
        if let dialogID = dialogRecord?.recordID, (notification.object as? NewMessage)?.payload?.dialogID == dialogID {
            fetchData(0)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (dialogRecord?["texts"] as? [String])?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        var identifier = "my message"
        if let senderID = (dialogRecord?["senders"] as? [CKRecord.Reference])?[indexPath.row].recordID, let myID = myRecord?.recordID, senderID != myID {
            identifier = "your message"
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)

        // Configure the cell...

        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if let cell = cell as? MessageCell {
            
            var receiverAvatar: UIImage? = nil
            var senderAvatar: UIImage? = nil
            var myAvatar: UIImage? = nil
            var yourAvatar: UIImage? = nil
            
            if let path = (dialogRecord?["receiverAvatar"] as? CKAsset)?.fileURL.path {
                receiverAvatar = UIImage(contentsOfFile: path)
            }
            if let path = (dialogRecord?["senderAvatar"] as? CKAsset)?.fileURL.path {
                senderAvatar = UIImage(contentsOfFile: path)
            }
            
            if let receiverID = (dialogRecord?["receiver"] as? CKRecord.Reference)?.recordID, receiverID != myRecord?.recordID {
                myAvatar = senderAvatar
                yourAvatar = receiverAvatar
            } else {
                myAvatar = receiverAvatar
                yourAvatar = senderAvatar
            }
            
            if cell.reuseIdentifier == "your message" {
                cell.avatarImageV.image = yourAvatar
            } else {
                cell.avatarImageV.image = myAvatar
            }
            
            if let texts = (dialogRecord?["texts"] as? [String]), texts.count > indexPath.row {
                cell.messageTextLabel.text = texts[indexPath.row]
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? MessageCell {
            cell.messageTextLabel.text = nil
            cell.avatarImageV.image = nil
        }
    }
    
    
    @IBAction func fetchData(_ sender: Any) {
        operationQueue.cancelAllOperations()
        if let dialogRecord = dialogRecord {
            let fetchRecordsOp = CKFetchRecordsOperation(recordIDs: [dialogRecord.recordID])
            fetchRecordsOp.fetchRecordsCompletionBlock = {recordsByRecordID, error in
                
                guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil,
                    let newRecord = recordsByRecordID?[dialogRecord.recordID]  else { return }
                
                DispatchQueue.main.sync {
                    self.dialogRecord = newRecord
                    self.tableView.reloadData()
                    self.tableView.scrollToRow(at: IndexPath(row: self.tableView.numberOfRows(inSection: 0) - 1, section: 0), at: .bottom, animated: false)
                }
            }
            fetchRecordsOp.database = database
            operationQueue.addOperation(fetchRecordsOp)
            
            return
        }
        
        guard let yourRecord = yourRecord, let myRecord = myRecord else {
            return
        }
        
        let dialogists = [yourRecord.recordID, myRecord.recordID]
        let query = CKQuery(recordType: "Dialog", predicate: NSPredicate(format: "receiver in %@ && creatorUserRecordID in %@", dialogists, dialogists))
        
        let queryMessagesOp = CKQueryOperation(query: query)
        queryMessagesOp.recordFetchedBlock = { (dialogRecord) in
            DispatchQueue.main.sync {
                self.dialogRecord = dialogRecord
                self.tableView.reloadData()
                self.tableView.scrollToRow(at: IndexPath(row: self.tableView.numberOfRows(inSection: 0) - 1, section: 0), at: .bottom, animated: false)
            }
        }
        queryMessagesOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
        }
        queryMessagesOp.database = self.database
        self.operationQueue.addOperation(queryMessagesOp)
    }

}


class MessageCell: UITableViewCell {
    @IBOutlet weak var avatarImageV: UIImageView!
    @IBOutlet weak var messageTextLabel: UILabel!
    
}
