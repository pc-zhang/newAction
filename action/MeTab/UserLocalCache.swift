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
    var artworkRecords: [CKRecord] = []
    
//    var artworkURLs: [URL] {
//        return artworkRecords.map {
//            if let ckasset = $0["video"] as? CKAsset {
//                return ckasset.fileURL.appendingPathExtension("mp4")
//            }
//            return URL(fileURLWithPath: "")
//        }
//    }
    
    var artworkThumbnails: [CKAsset] {
        return artworkRecords.compactMap {
            return $0["thumbnail"] as? CKAsset
        }
    }
    
    var avatarImage : CKAsset? {
        guard let userRecord = userRecord else {
            return nil
        }
        return userRecord["avatarImage"] as? CKAsset
    }
    var nickName : String? {
        guard let userRecord = userRecord else {
            return nil
        }
        return userRecord["nickName"]
    }
    var sex : String? {
        guard let userRecord = userRecord else {
            return nil
        }
        return userRecord["sex"]
    }
    var location : String? {
        guard let userRecord = userRecord else {
            return nil
        }
        return userRecord["location"]
    }
    var sign : String? {
        guard let userRecord = userRecord else {
            return nil
        }
        return userRecord["sign"]
    }
    
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
                self.userRecord = userRecord
            }
        }
        fetchRecordsOp.database = database
        operationQueue.addOperation(fetchRecordsOp)
        
        self.performWriterBlock {
            self.artworkRecords = []
        }
        let queryArtworksOp = CKQueryOperation(query: CKQuery(recordType: "Artwork", predicate: NSPredicate(format: "artist = %@", recordID)))
        queryArtworksOp.desiredKeys = ["thumbnail"]
        queryArtworksOp.recordFetchedBlock = { (artworkRecord) in
            if let ckasset = artworkRecord["video"] as? CKAsset {
                let savedURL = ckasset.fileURL.appendingPathExtension("mp4")
                try? FileManager.default.moveItem(at: ckasset.fileURL, to: savedURL)
            }
            self.performWriterBlock {
                self.artworkRecords.append(artworkRecord)
            }
        }
        queryArtworksOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: [recordID]) == nil else { return }
        }
        queryArtworksOp.database = database
        operationQueue.addOperation(queryArtworksOp)
        postWhenOperationQueueClear(name: .userCacheDidChange)
        
    }
    
    func changeUserInfo(avatarAsset: CKAsset, nickName: String, sex: String, location: String, sign: String) -> Bool {
        guard let userRecord = self.userRecord else {
            return false
        }
        userRecord["avatarImage"] = avatarAsset
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
            
            self.performWriterBlock {
                self.userRecord = newRecord
            }
        }
        operation.database = database
        operationQueue.addOperation(operation)
        operationQueue.waitUntilAllOperationsAreFinished()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .userCacheDidChange, object: nil)
        }
        return succeed
    }
}
