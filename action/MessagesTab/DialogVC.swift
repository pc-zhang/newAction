//
//  MessagesVC.swift
//  action
//
//  Created by zpc on 2018/11/12.
//  Copyright © 2018 zpc. All rights reserved.
//

import UIKit
import CloudKit


class DialogVC: UITableViewController {
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    private var messages: [CKRecord] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    var isFetchingData: Bool = false
    var myRecord: CKRecord? = nil
    var yourRecord: CKRecord? = nil
    var dialogID: CKRecord.ID? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = yourRecord?["nickName"] as? String
        
        fetchData(0)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "your message"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)

        // Configure the cell...

        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if let cell = cell as? MessageCell {
            if let path = (yourRecord?["avatarImage"] as? CKAsset)?.fileURL.path {
                cell.avatarImageV.image = UIImage(contentsOfFile: path)
            }
            cell.messageTextLabel.text = messages[indexPath.row]["text"] as? String
        }
    }
    
    
    @IBAction func fetchData(_ sender: Any) {
        guard let dialogID = dialogID else {
            return
        }
        
        isFetchingData = true
        var tmpMessages:[CKRecord] = []
        
        let query = CKQuery(recordType: "Message", predicate: NSPredicate(format: "dialog = %@", dialogID))
        
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: true)
        query.sortDescriptors = [byCreation]
        let queryMessagesOp = CKQueryOperation(query: query)
        
        queryMessagesOp.desiredKeys = ["text", "sender"]
        queryMessagesOp.resultsLimit = 10
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
                self.messages.append(contentsOf: tmpMessages)
                self.isFetchingData = false
                self.tableView.reloadData()
            }
        }
    }

}


class MessageCell: UITableViewCell {
    @IBOutlet weak var avatarImageV: UIImageView!
    @IBOutlet weak var messageTextLabel: UILabel!
    
}
