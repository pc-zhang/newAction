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

    let container = CKContainer.default()
    let database = CKContainer.default().publicCloudDatabase
    let zone = CKRecordZone.default()
    var userRecord : CKRecord?
    
    override init() {
        super.init()
        
        CKContainer.default().fetchUserRecordID { (recordID, error) in
            if (error != nil) {
                // Error handling for failed fetch from public database
            }
            else {
                guard let recordID = recordID else {
                    return
                }
                
                CKContainer.default().publicCloudDatabase.fetch(withRecordID: recordID) { (record, error) in
                    if (error != nil) {
                        // Error handling for failed fetch from public database
                    }
                    else {
                        self.userRecord = record
                    }
                }
            }
        }
    }

}

