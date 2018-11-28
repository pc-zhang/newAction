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
    
    private var userCacheOrNil: UserLocalCache? {
        return (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil
    }
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    private var messages: [CKRecord] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    var isFetchingData: Bool = false
    var yourRecord: CKRecord? = nil
    var dialogID: CKRecord.ID? = nil
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
    
    func sendMessage(_ text: String) {
        var myID: CKRecord.ID?
        userCacheOrNil?.performReaderBlockAndWait {
            myID = userCacheOrNil!.userRecord?.recordID
        }
        
        guard let dialogID = dialogID, myID != nil else {
            return
        }
        
        let messageRecord = CKRecord(recordType: "Message")
        messageRecord["receiver"] = CKRecord.Reference(recordID: yourRecord!.recordID, action: .deleteSelf)
        messageRecord["text"] = text
        messageRecord["dialog"] = CKRecord.Reference(recordID: dialogID, action: .none)
        
        let operation = CKModifyRecordsOperation(recordsToSave: [messageRecord], recordIDsToDelete: nil)
        
        operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
            guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: [messageRecord.recordID], alert: true) == nil,
                let newRecord = records?[0] else { return }
                DispatchQueue.main.async {
                    self.messages.append(newRecord)
                    self.isFetchingData = false
                    self.tableView.reloadData()
                    self.tableView.scrollToRow(at: IndexPath(row: self.messages.count-1, section: 0), at: .bottom, animated: false)
                }
        }
        operation.database = database
        operationQueue.addOperation(operation)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = yourRecord?["nickName"] as? String
        
        fetchData(0)
    }
    
    
    override func awakeFromNib() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(type(of:self).newMessage(_:)),
            name: .newMessage, object: nil)
    }

    @objc func newMessage(_ notification: Notification) {
        if let dialogID = dialogID, (notification.object as? NewMessage)?.payload?.dialogID == dialogID {
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
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var myID: CKRecord.ID?
        userCacheOrNil?.performReaderBlockAndWait {
            myID = userCacheOrNil!.userRecord?.recordID
        }
        var identifier = "my message"
        if (messages[indexPath.row]["receiver"] as? CKRecord.Reference)?.recordID == myID! {
            identifier = "your message"
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)

        // Configure the cell...

        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if let cell = cell as? MessageCell {
            var myID: CKRecord.ID?
            userCacheOrNil?.performReaderBlockAndWait {
                myID = userCacheOrNil!.userRecord?.recordID
            }
            
            var imageURL: URL?
            userCacheOrNil?.performReaderBlockAndWait {
                imageURL = (userCacheOrNil!.userRecord?["littleAvatar"] as? CKAsset)?.fileURL
            }
            
            if (messages[indexPath.row]["receiver"] as? CKRecord.Reference)?.recordID == myID! {
                if let path = (yourRecord?["littleAvatar"] as? CKAsset)?.fileURL.path {
                    cell.avatarImageV.image = UIImage(contentsOfFile: path)
                }
            } else {
                if let path = imageURL?.path {
                    cell.avatarImageV.image = UIImage(contentsOfFile: path)
                }
            }
            
            cell.messageTextLabel.text = messages[indexPath.row]["text"] as? String
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? MessageCell {
            cell.messageTextLabel.text = nil
            cell.avatarImageV.image = nil
        }
    }
    
    
    @IBAction func fetchData(_ sender: Any) {
        guard let dialogID = dialogID else {
            return
        }
        
        messages = []
        
        isFetchingData = true
        var tmpMessages:[CKRecord] = []
        
        let query = CKQuery(recordType: "Message", predicate: NSPredicate(format: "dialog = %@", dialogID))
        
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: true)
        query.sortDescriptors = [byCreation]
        let queryMessagesOp = CKQueryOperation(query: query)
        
        queryMessagesOp.desiredKeys = ["text", "receiver"]
        queryMessagesOp.resultsLimit = 1000
        queryMessagesOp.recordFetchedBlock = { (messageRecord) in
            tmpMessages.append(messageRecord)
        }
        queryMessagesOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            self.cursor = cursor
        }
        queryMessagesOp.database = self.database
        self.operationQueue.addOperation(queryMessagesOp)
        
        DispatchQueue.global().async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            DispatchQueue.main.async {
                self.messages = tmpMessages
                self.isFetchingData = false
                self.tableView.reloadData()
                self.tableView.scrollToRow(at: IndexPath(row: self.messages.count-1, section: 0), at: .bottom, animated: false)
            }
        }
    }

}


class MessageCell: UITableViewCell {
    @IBOutlet weak var avatarImageV: UIImageView!
    @IBOutlet weak var messageTextLabel: UILabel!
    
}
