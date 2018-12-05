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
final class UserLocalCache {
    
    let container: CKContainer
    let database: CKDatabase
    var myInfoRecord: CKRecord?
    
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    
    init() {
        self.container = CKContainer.default()
        self.database = container.publicCloudDatabase
        
        CKContainer.default().fetchUserRecordID { (recordID, error) in
            if let recordID = recordID {
//                self.subscripts(recordID)
                self.updateWithRecordID(recordID)
            }
        }
        
    }
    
    func subscripts(_ myID: CKRecord.ID) {
        let predicate = NSPredicate(format: "receiver = %@", myID)
//        let predicate = NSPredicate(value: true)

        let subscriptionID = "new message to me"
        let subscription = CKQuerySubscription(recordType: "Message", predicate: predicate, subscriptionID: subscriptionID, options: CKQuerySubscription.Options.firesOnRecordCreation)
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldBadge = true
        notificationInfo.alertLocalizationKey = "New message!"
        notificationInfo.desiredKeys = ["dialog", "text"]
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        
        operation.modifySubscriptionsCompletionBlock = { _, _, error in
            guard handleCloudKitError(error, operation: .modifySubscriptions) == nil else { return }
        }
        
        operation.database = database
        operationQueue.addOperation(operation)
    }
    
    
    // Convenient method for updating the cache with one specified record ID.
    //
    func updateWithRecordID(_ recordID: CKRecord.ID) {
        let fetchRecordsOp = CKFetchRecordsOperation(recordIDs: [recordID])
        fetchRecordsOp.fetchRecordsCompletionBlock = {recordsByRecordID, error in
            
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: [recordID]) == nil,
                let userRecord = recordsByRecordID?[recordID]  else { return }
            
            DispatchQueue.main.sync {
                self.myInfoRecord = userRecord
                NotificationCenter.default.post(name: .userCacheDidChange, object: nil)
            }
        }
        fetchRecordsOp.database = database
        operationQueue.addOperation(fetchRecordsOp)
    }
    
    func changeUserInfo(avatarAsset: CKAsset, littleAvatarAsset: CKAsset, nickName: String, sex: String, location: String, sign: String) -> Bool {
        guard let userRecord = self.myInfoRecord else {
            return false
        }
        userRecord["avatarImage"] = avatarAsset
        userRecord["littleAvatar"] = littleAvatarAsset
        userRecord["nickName"] = nickName
        userRecord["sex"] = sex
        userRecord["location"] = location
        userRecord["sign"] = sign
        
        let operation = CKModifyRecordsOperation(recordsToSave: [userRecord], recordIDsToDelete: nil)
        
        var succeed: Bool = true
        
        operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
            succeed = (error == nil)
            guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: [userRecord.recordID], alert: true) == nil,
                let newRecord = records?[0] else { return }
            
            DispatchQueue.main.sync {
                self.myInfoRecord = newRecord
                NotificationCenter.default.post(name: .userCacheDidChange, object: nil)
            }
        }
        operation.database = database
        operationQueue.addOperation(operation)
        
        return succeed
    }
    
}
