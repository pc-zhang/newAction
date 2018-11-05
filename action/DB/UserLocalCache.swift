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
    var userRecordID: CKRecord.ID?
    var gifs : [CKAsset]?
    var avatarPath : String?
    var nickName : String?
    var sign : String?
    
    override init() {
        self.container = CKContainer.default()
        self.database = container.publicCloudDatabase
        
        super.init()
        
        CKContainer.default().fetchUserRecordID { (recordID, error) in
            if let recordID = recordID {
                self.performWriterBlock { self.userRecordID = recordID }
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
                self.avatarPath = (userRecord["avatarImage"] as? CKAsset)?.fileURL.path
                self.nickName = userRecord["nickName"]
                self.sign = userRecord["sign"]
                self.gifs = userRecord["gifs"]
            }
        }
        fetchRecordsOp.database = database
        operationQueue.addOperation(fetchRecordsOp)
        postWhenOperationQueueClear(name: .userCacheDidChange)
    }
    
}
