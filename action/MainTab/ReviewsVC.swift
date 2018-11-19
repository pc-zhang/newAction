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
    @IBOutlet weak var reviewTextField: UITextField!
    @IBOutlet weak var reviewTextFieldBottomHeight: NSLayoutConstraint!
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        reviewTextFieldBottomHeight.constant = 500
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        reviewTextFieldBottomHeight.constant = 0
        reviewTextField.text = nil
        reviewTextField.resignFirstResponder()
        return true
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
        
        queryReviewsOp.desiredKeys = []
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
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        
    }
    
    @IBAction func tapBlankPlace(_ sender: Any) {
        super.dismiss(animated: true)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
