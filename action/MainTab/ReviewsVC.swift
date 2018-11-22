//
//  ReviewsVC.swift
//  action
//
//  Created by zpc on 2018/11/19.
//  Copyright © 2018 zpc. All rights reserved.
//

import UIKit
import CloudKit

fileprivate struct ReviewInfo {
    var isPrefetched: Bool = false
    var artist: CKRecord? = nil
    var likes: [CKRecord]? = nil
    var review: CKRecord? = nil
}

class ReviewsVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching , UITextFieldDelegate{

    @IBOutlet weak var tableView: UITableView!
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    private var reviewInfos: [ReviewInfo] = []
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    var cursor: CKQueryOperation.Cursor? = nil
    var isFetchingData: Bool = false
    var artworkID: CKRecord.ID? = nil
    @IBOutlet weak var reviewTextFieldBottomHeight: NSLayoutConstraint!
    
    private var userCacheOrNil: UserLocalCache? {
        return (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        reviewTextFieldBottomHeight.constant = 500
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text {
            sendReview(text)
        }
        
        reviewTextFieldBottomHeight.constant = 0
        textField.text = nil
        textField.resignFirstResponder()
        return true
    }
    
    func sendReview(_ text: String) {
        guard let artworkID = artworkID else {
            return
        }
        let reviewRecord = CKRecord(recordType: "Review")
        reviewRecord["artwork"] = CKRecord.Reference(recordID: artworkID, action: .deleteSelf)
        reviewRecord["text"] = text
        
        database.save(reviewRecord) { (record, error) in
            guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil) == nil else { return }
            
            DispatchQueue.main.async {
                var artistRecord: CKRecord?
                
                self.userCacheOrNil?.performReaderBlockAndWait {
                    artistRecord = self.userCacheOrNil!.userRecord
                }
                let reviewInfo = ReviewInfo(isPrefetched: true, artist: artistRecord, likes: [], review: record)
                self.reviewInfos.insert(reviewInfo, at: 0)
                self.tableView.reloadData()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        
        fetchData(0)
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    func reloadVisibleRow(_ row: Int) {
        let indexPath = IndexPath(row: row, section: 0)
        if tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false {
            tableView.reloadRows(at: [indexPath], with: .fade)
        }
    }
    
    func queryReviewOtherInfo(_ row: Int)
    {
        guard let reviewRecord = reviewInfos[row].review else {
            return
        }
        
        if reviewInfos[row].isPrefetched == true {
            return
        }
        reviewInfos[row].isPrefetched = true
        
        if let artistID = reviewRecord.creatorUserRecordID {
            let fetchArtistOp = CKFetchRecordsOperation(recordIDs: [artistID])
            fetchArtistOp.desiredKeys = ["avatarImage", "nickName"]
            fetchArtistOp.fetchRecordsCompletionBlock = { (recordsByRecordID, error) in
                guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
                
                DispatchQueue.main.async {
                    self.reviewInfos[row].artist = recordsByRecordID?[artistID]
                    self.reloadVisibleRow(row)
                }
            }
            fetchArtistOp.database = self.database
            self.operationQueue.addOperation(fetchArtistOp)
        }
        
    }
    
    @IBAction func fetchData(_ sender: Any) {
        guard let artworkID = artworkID else {
            return
        }
        
        reviewInfos = []
        isFetchingData = true
        var tmpReviewInfos:[ReviewInfo] = []
        
        let query = CKQuery(recordType: "Review", predicate: NSPredicate(format: "artwork = %@", artworkID))
        
        let byCreation = NSSortDescriptor(key: "creationDate", ascending: false)
        query.sortDescriptors = [byCreation]
        let queryReviewsOp = CKQueryOperation(query: query)
        
        queryReviewsOp.desiredKeys = ["text"]
        queryReviewsOp.resultsLimit = 6
        queryReviewsOp.recordFetchedBlock = { (reviewRecord) in
            var reviewInfo = ReviewInfo()
            reviewInfo.review = reviewRecord
            tmpReviewInfos.append(reviewInfo)
        }
        queryReviewsOp.queryCompletionBlock = { (cursor, error) in
            guard handleCloudKitError(error, operation: .fetchRecords, affectedObjects: nil) == nil else { return }
            self.cursor = cursor
        }
        queryReviewsOp.database = self.database
        self.operationQueue.addOperation(queryReviewsOp)
        
        DispatchQueue.global().async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            DispatchQueue.main.async {
                self.reviewInfos.append(contentsOf: tmpReviewInfos)
                self.isFetchingData = false
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return reviewInfos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "review"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        
        // Configure the cell...
        
        return cell
    }
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }()
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? ReviewCell {
            cell.avatarV.image = nil
            cell.nickNameLabel.text = nil
            cell.reviewLabel.text = nil
            cell.createTimeLabel.text = nil
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        queryReviewOtherInfo(indexPath.row)
        
        if let cell = cell as? ReviewCell {
            if let path = (reviewInfos[indexPath.row].artist?["avatarImage"] as? CKAsset)?.fileURL.path {
                cell.avatarV.image = UIImage(contentsOfFile: path)
            }
            cell.nickNameLabel.text = reviewInfos[indexPath.row].artist?["nickName"] as? String
            cell.reviewLabel.text = reviewInfos[indexPath.row].review?["text"] as? String
            if let date = reviewInfos[indexPath.row].review?.creationDate {
                cell.createTimeLabel.text = dateFormatter.string(from: date)
            }
        }
        
    }
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        
    }
    
    @IBAction func tapBlankPlace(_ sender: Any) {
        super.dismiss(animated: true)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.setSelected(false, animated: false)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "review to artist segue" {
//            if let userVC = segue.destination as? UserInfoVC, let currentCell = self.tableView.visibleCells.first as? MainViewCell {
//                userVC.url = currentCell.url
//                currentCell.player.pause()
//            }
        }
    }

}

class ReviewCell: UITableViewCell {
    @IBOutlet weak var avatarV: UIImageView!
    @IBOutlet weak var nickNameLabel: UILabel!
    @IBOutlet weak var reviewLabel: UILabel!
    @IBOutlet weak var createTimeLabel: UILabel!
    
}
