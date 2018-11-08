/*
 Copyright (C) 2018 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Topic and note local cache class, managing the local cache for topics and notes.
 */

import Foundation
import CloudKit

// "container", "database", and "zone" are immutalbe; "topics" and "serverChangeToken" are mutable,
// thus "topic.permission", "topic.notes", "topic.record", "note.permission", "note.record" are mutable.
//
// TopicLocalCache and subclasses follow these rules to be thread-safe:
// 1. Public methods access mutable properties via "perform...".
// 2. Private methods that access mutable properties should be called via "perform...".
// 3. Private methods access mutable properties directly because of #2
// 4. Immutable properties are accessed directly.
//
// We don't provide accessors to protect mutable properties because we don't want to call "perform..."
// in every call to the properties. Clients should wrap the code accessing mutable properties
// directly with "perform...".
//
// Clients follow these rules to thread-safely use BaseLocalCache or its subclasses:
// 1. Access mutable properties via "perform...".
// 2. Call public methods directly, otherwise will trigger a deadlock.
//
final class UserLocalCache: BaseLocalCache {
    
    let container: CKContainer
    let database: CKDatabase
    var userRecord: CKRecord?
    var avatarURL : URL?
    var nickName : String?
    var sex : String?
    var location : String?
    var sign : String?
    var gifs : [CKAsset] = []
    
    override init() {
        self.container = CKContainer.default()
        self.database = container.publicCloudDatabase
        
        super.init()
        
        CKContainer.default().fetchUserRecordID { (recordID, error) in
            if let recordID = recordID {
                self.updateWithRecordID(recordID)
            }
        }
        
    }
    
    
    // Convenient method for updating the cache with one specified record ID.
    //
    func updateWithRecordID(_ recordID: CKRecord.ID) {
        
        let fetchRecordsOp = CKFetchRecordsOperation(recordIDs: [recordID])
        fetchRecordsOp.fetchRecordsCompletionBlock = {recordsByRecordID, error in
            
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: [recordID]) == nil,
                let userRecord = recordsByRecordID?[recordID]  else { return }
            
            self.performWriterBlock {
                self.updateCacheWithRecord(userRecord: userRecord)
            }
        }
        fetchRecordsOp.database = database
        operationQueue.addOperation(fetchRecordsOp)
        postWhenOperationQueueClear(name: .userCacheDidChange)
    }
    
    func updateCacheWithRecord(userRecord: CKRecord) {
        self.userRecord = userRecord
        self.avatarURL = (userRecord["avatarImage"] as? CKAsset)?.fileURL
        self.nickName = userRecord["nickName"]
        self.sex = userRecord["sex"]
        self.location = userRecord["location"]
        self.sign = userRecord["sign"]
    }
    
    func changeUserInfo(avatarURL: URL, nickName: String, sex: String, location: String, sign: String) {
        guard let userRecord = self.userRecord else {
            return
        }
        userRecord["avatarImage"] = CKAsset(fileURL: avatarURL)
        userRecord["nickName"] = nickName
        userRecord["sex"] = sex
        userRecord["location"] = location
        userRecord["sign"] = sign
        
        let operation = CKModifyRecordsOperation(recordsToSave: [userRecord], recordIDsToDelete: nil)
        
        operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
            guard handleCloudKitError(error, operation: .modifyRecords, alert: true) == nil,
                let newRecord = records?[0] else { return }
            
            self.performWriterBlock {
                self.updateCacheWithRecord(userRecord: newRecord)
            }
        }
        operation.database = database
        operationQueue.addOperation(operation)
        postWhenOperationQueueClear(name: .userCacheDidChange)
    }
}
