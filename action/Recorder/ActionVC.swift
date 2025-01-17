//
//  actionVC.swift
//  action
//
//  Created by zpc on 2018/11/14.
//  Copyright © 2018 zpc. All rights reserved.
//

import UIKit
import Accelerate
import AVFoundation
import CoreServices
import CloudKit

class ActionVC: UIViewController, RosyWriterCapturePipelineDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate, UIGestureRecognizerDelegate, UITextViewDelegate {
    
    // MARK: - UI Controls
    
    @IBOutlet weak var playButton: UIImageView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playerV: PlayerView!
    @IBOutlet weak var timelineV: UICollectionView!
    @IBOutlet weak var actionSegment: UISegmentedControl! {
        didSet {
            actionSegment.selectedSegmentIndex = 0
        }
    }
//    @IBOutlet weak var audioLevel: UIProgressView!
    @IBOutlet weak var tools: UIStackView!
    @IBOutlet weak var middleLineV: UIView!
    @IBOutlet weak var titleTextV: UITextView!
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var saveLocalButton: UIButton!
    
    @IBOutlet weak var cutButton: UIButton! {
        didSet {
            cutButton.transform = CGAffineTransform(rotationAngle: .pi)
        }
    }
    
    let container: CKContainer = CKContainer.default()
    let database: CKDatabase = CKContainer.default().publicCloudDatabase
    lazy var operationQueue: OperationQueue = {
        return OperationQueue()
    }()
    
    //MARK: - UI Actions
    
    func generateCover() -> (CKAsset, CKAsset)? {
        let imageGenerator = AVAssetImageGenerator.init(asset: composition!)
        imageGenerator.maximumSize = videoComposition!.renderSize
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.videoComposition = videoComposition
        
        if let coverImage = try? imageGenerator.copyCGImage(at: .zero, actualTime: nil), let coverImageURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(UUID().uuidString).png"), let littleCoverImageURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(UUID().uuidString).png") {
            
            FileManager.default.createFile(atPath: coverImageURL.path, contents: UIImage(cgImage: coverImage).pngData(), attributes: nil)
            FileManager.default.createFile(atPath: littleCoverImageURL.path, contents: UIImage(cgImage: coverImage).resize(targetSize: CGSize(width: 90, height: 160)).pngData(), attributes: nil)
            return (CKAsset(fileURL: coverImageURL), CKAsset(fileURL: littleCoverImageURL))
        }
        
        return nil
    }
    
    func generateThumbnail() -> CKAsset? {
        let imageGenerator = AVAssetImageGenerator.init(asset: composition!)
        imageGenerator.maximumSize = CGSize(width: 90, height: 160)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.videoComposition = videoComposition
        
        var iter = 0
        var iterTime = CMTime.zero
        var images: [CGImage] = []
        
        while iter < 5 {
            if let image = try? imageGenerator.copyCGImage(at: iterTime, actualTime: nil) {
                images.append(image)
            }
            iterTime = CMTimeAdd(iterTime, CMTime(value: 1, timescale: 10))
            iter = iter + 1
        }
        
        let fileProperties: CFDictionary = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]]  as CFDictionary
        let frameProperties: CFDictionary = [kCGImagePropertyGIFDictionary as String: [(kCGImagePropertyGIFDelayTime as String): 0.3]] as CFDictionary
        
        let documentsDirectoryURL: URL? = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        if let fileURL = documentsDirectoryURL?.appendingPathComponent("thumbnail.gif"), let url = fileURL as CFURL? {
            if let destination = CGImageDestinationCreateWithURL(url, kUTTypeGIF, images.count, nil) {
                CGImageDestinationSetProperties(destination, fileProperties)
                for image in images {
                    CGImageDestinationAddImage(destination, image, frameProperties)
                }
                if !CGImageDestinationFinalize(destination) {
                    print("Failed to finalize the image destination")
                } else {
                    return CKAsset(fileURL: fileURL)
                }
            }
        }
        
        return nil
    }
    
    @IBAction func cancel(_ sender: Any) {
        if isExporting {
            isExporting = false
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    func split(at splitTime: CMTime) -> Bool {
        guard let firstVideoTrack = self.composition?.tracks(withMediaType: .video).first else {
            return false
        }
        
        if let segment = firstVideoTrack.segment(forTrackTime: splitTime), segment.timeMapping.target.containsTime(splitTime) {
            let section = firstVideoTrack.segments.firstIndex(of: segment)!
            
            let duration = splitTime - segment.timeMapping.target.start
            var tmpSegments = firstVideoTrack.segments!.map {$0}
            tmpSegments.replaceSubrange(section...section, with: [AVCompositionTrackSegment(url: segment.sourceURL!, trackID: segment.sourceTrackID, sourceTimeRange: CMTimeRange(start: segment.timeMapping.source.start, duration: duration+CMTime(value: 1, timescale: 600)), targetTimeRange: CMTimeRange(start: segment.timeMapping.target.start, end: splitTime)), AVCompositionTrackSegment(url: segment.sourceURL!, trackID: segment.sourceTrackID, sourceTimeRange: CMTimeRange(start: segment.timeMapping.source.start+duration, end: segment.timeMapping.source.end), targetTimeRange: CMTimeRange(start: splitTime, end: segment.timeMapping.target.end))])
            
            firstVideoTrack.segments = tmpSegments
            if firstVideoTrack.segments.count == tmpSegments.count {
                timelineV.performBatchUpdates({
                    timelineV.insertSections(IndexSet(integer: section+1))
                    timelineV.reloadSections(IndexSet(integer: section))
                }, completion: nil)
                
                return true
            }
        }
        
        return false
    }
    
    @IBAction func split(_ sender: Any) {
        if true == split(at: player.currentTime()) {
            push()
        }
    }
    
    @IBAction func merge(_ sender: Any) {
        guard let firstVideoTrack = self.composition?.tracks(withMediaType: .video).first else {
            return
        }
        
        let time = player.currentTime()
        
        if let segment = firstVideoTrack.segment(forTrackTime: time), segment.timeMapping.target.containsTime(time), let section = firstVideoTrack.segments.firstIndex(of: segment), section < firstVideoTrack.segments.count - 1, segment.sourceURL! == firstVideoTrack.segments[section+1].sourceURL! {
            
                var tmpSegments = firstVideoTrack.segments!.map {$0}
                tmpSegments.replaceSubrange(section...(section+1), with: [AVCompositionTrackSegment(url: segment.sourceURL!, trackID: segment.sourceTrackID, sourceTimeRange: CMTimeRange(start: segment.timeMapping.source.start, end: firstVideoTrack.segments[section+1].timeMapping.source.end), targetTimeRange: CMTimeRange(start: segment.timeMapping.target.start, end: firstVideoTrack.segments[section+1].timeMapping.target.end))])
                try! firstVideoTrack.validateSegments(tmpSegments)
                firstVideoTrack.segments = tmpSegments
                
                timelineV.performBatchUpdates({
                    timelineV.deleteSections(IndexSet(integer: section+1))
                    timelineV.reloadSections(IndexSet(integer: section))
                }, completion: nil)
            
                push()
        }
    }
    
    var stack: [AVMutableComposition] = []
    var undoPos: Int = -1
    
    func push() {
        let newComposition = composition!.mutableCopy() as! AVMutableComposition
        
        while undoPos < stack.count - 1 {
            stack.removeLast()
        }
        
        stack.append(newComposition)
        undoPos = stack.count - 1
    }
    
    @IBAction func lastFrame(_ sender: Any) {
        if player.rate != 0 {
            player.pause()
            seekTimer?.invalidate()
            recordTimer?.invalidate()
        }
        player.seek(to: player.currentTime() - videoComposition!.frameDuration, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        self.timelineV.contentOffset.x = CGFloat(self.currentTime/self.interval)*self.timelineV.bounds.height - self.timelineV.bounds.width/2
    }
    
    @IBAction func nextFrame(_ sender: Any) {
        if player.rate != 0 {
            player.pause()
            seekTimer?.invalidate()
            recordTimer?.invalidate()
        }
        player.seek(to: player.currentTime() + videoComposition!.frameDuration, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        self.timelineV.contentOffset.x = CGFloat(self.currentTime/self.interval)*self.timelineV.bounds.height - self.timelineV.bounds.width/2
    }
    
    @IBAction func Undo(_ sender: Any) {
        if undoPos <= 0 {
            return
        }
        
        undoPos -= 1
        composition = stack[undoPos].mutableCopy() as! AVMutableComposition
        
        updatePlayer()
        timelineV.reloadData()
    }
    
    @IBAction func Redo(_ sender: Any) {
        if undoPos == stack.count - 1 {
            return
        }
        
        undoPos += 1
        composition = stack[undoPos].mutableCopy() as! AVMutableComposition
        
        updatePlayer()
        timelineV.reloadData()
    }
    
    @IBAction func export(_ sender: Any) {
        isExporting = !isExporting
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        if text == "\n" {
            titleTextV.resignFirstResponder()
            return false
        }
        
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        
        let changedText = currentText.replacingCharacters(in: stringRange, with: text)
        
        return changedText.count <= 60
    }
    
    @IBAction func saveLocalOrUpload(_ sender: Any) {
        if (sender as? UIButton) == self.uploadButton, let duration = composition?.tracks(withMediaType: .video).first?.timeRange.duration.seconds, duration > 60 {
            let alert = UIAlertController(title: "请您上传60秒之内的视频", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .cancel, handler: nil))
            present(alert, animated: true)
            
            return
        }
        
        // Create the export session with the composition and set the preset to the highest quality.
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: composition!)
        let exporter = AVAssetExportSession(asset: composition!, presetName: AVAssetExportPreset960x540)!
        // Set the desired output URL for the file created by the export process.
        exporter.outputURL = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        // Set the output file type to be a QuickTime movie.
        exporter.outputFileType = AVFileType.mov
        exporter.shouldOptimizeForNetworkUse = true
        let waterMarkedVideoComposition = videoComposition?.mutableCopy() as! AVMutableVideoComposition
        
        let weixin = CALayer()
        weixin.contents = UIImage(named: "logo")!.cgImage!
        weixin.frame = CGRect(origin: .zero, size: videoComposition!.renderSize)
        weixin.contentsGravity = CALayerContentsGravity(rawValue: "topRight")
        if videoComposition!.renderSize.width > videoComposition!.renderSize.height {
            weixin.contentsScale = CGFloat(UIImage(named: "logo")!.cgImage!.height) / videoComposition!.renderSize.height * 8
            
            weixin.frame.origin.x -= weixin.frame.width / 5 / 4
            weixin.frame.origin.y -= weixin.frame.height / 8 / 2
        } else {
            weixin.contentsScale = CGFloat(UIImage(named: "logo")!.cgImage!.width) / videoComposition!.renderSize.width * 5
            weixin.frame.origin.x -= weixin.frame.width / 5 / 4
            weixin.frame.origin.y -= weixin.frame.height / 8 / 3
        }
        
        
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoComposition!.renderSize)
        videoLayer.frame = CGRect(origin: .zero, size: videoComposition!.renderSize)
        
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(weixin)
        waterMarkedVideoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
        exporter.videoComposition = waterMarkedVideoComposition
        exporter.audioMix = audioMix
        let firstVideoTrack = composition!.tracks(withMediaType: .video).first!
        exporter.timeRange = firstVideoTrack.timeRange
        // Asynchronously export the composition to a video file and save this file to the camera roll once export completes.
        
        let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0),
                                                   queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: .milliseconds(250))
        timer.setEventHandler {
            DispatchQueue.main.async {
                if (sender as? UIButton) == self.saveLocalButton {
                    self.downloadProgress = CGFloat(exporter.progress)
                } else if (sender as? UIButton) == self.uploadButton {
                    self.downloadProgress = CGFloat(exporter.progress) / 4
                }
            }
        }
        timer.resume()
        
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                timer.cancel()
                
                if (sender as? UIButton) == self.saveLocalButton {
                    self.downloadProgress = CGFloat(exporter.progress)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                        if (sender as? UIButton) == self.saveLocalButton {
                            self.downloadProgress = 0
                        }
                    })
                }

                if (exporter.status == .completed) {
                    if (sender as? UIButton) == self.saveLocalButton {
                        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(exporter.outputURL!.path)) {
                            UISaveVideoAtPathToSavedPhotosAlbum(exporter.outputURL!.path, self, #selector(self.video), nil)
                        }
                    }
                    
                    if (sender as? UIButton) == self.uploadButton {
                        
                        let myInfoRecord = CKRecord(recordType: "ArtworkInfo")
                        myInfoRecord["seconds"] = 0
                        myInfoRecord["reviews"] = 0
                        myInfoRecord["chorus"] = 0
                        myInfoRecord["reports"] = 0
                        
                        let artworkRecord = CKRecord(recordType: "Artwork")
                        artworkRecord["video"] = CKAsset(fileURL: exporter.outputURL!)
                        if let thumbnail = self.generateThumbnail() {
                            artworkRecord["thumbnail"] = thumbnail
                        }
                        if let (cover, littleCover) = self.generateCover() {
                            artworkRecord["cover"] = cover
                            artworkRecord["littleCover"] = littleCover
                        }
                        artworkRecord["title"] = self.titleTextV.text
                        if let url = ((UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord?["littleAvatar"] as? CKAsset)?.fileURL {
                            artworkRecord["avatar"] = CKAsset(fileURL: url)
                        }
                        
                        artworkRecord["nickName"] = (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil?.myInfoRecord?["nickName"] as? String
                        
                        if let artworkID = self.artworkID {
                            myInfoRecord["chorusFrom"] = CKRecord.Reference(recordID: artworkID, action: .none)
                        } else {
                            myInfoRecord["chorusFrom"] = CKRecord.Reference(recordID: artworkRecord.recordID, action: .none)
                        }
                        artworkRecord["info"] = CKRecord.Reference(recordID: myInfoRecord.recordID, action: .none)
                        
                        let operation = CKModifyRecordsOperation(recordsToSave: [myInfoRecord, artworkRecord], recordIDsToDelete: nil)
                        
                        operation.perRecordProgressBlock = {(record, progress) in
                            if record.recordID == artworkRecord.recordID {
                                DispatchQueue.main.async {
                                    self.downloadProgress = 0.25 + CGFloat(progress) * 0.75
                                }
                            }
                        }
                        
                        operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
                            guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil, alert: true) == nil else { return }
                            DispatchQueue.main.async {
                                self.downloadProgress = 0
                            }
                        }
                        operation.database = self.database
                        self.operationQueue.addOperation(operation)
                        
                        if let infoRecord = self.infoRecord {
                            self.chorusPlus(infoRecord)
                        }
                    }
                    
                } else {
                    _ = 1
                }
            }
        }
    }
    
    
    func chorusPlus(_ infoRecord: CKRecord) {
        guard let chorusCount = infoRecord["chorus"] as? Int64 else {
            return
        }
        
        infoRecord["chorus"] = chorusCount + 1
        
        let operation = CKModifyRecordsOperation(recordsToSave: [infoRecord], recordIDsToDelete: nil)
        
        operation.modifyRecordsCompletionBlock = { (records, recordIDs, error) in
            guard handleCloudKitError(error, operation: .modifyRecords, affectedObjects: nil) == nil else {
                
                if let newRecord = records?.first {
                    DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
                        self.chorusPlus(newRecord)
                    })
                }
                
                return
            }
            
        }
        operation.database = self.database
        
        self.operationQueue.addOperation(operation)
    }
    
    @objc func video(videoPath: NSString, didFinishSavingWithError error:NSError, contextInfo:Any) -> Void {
    }
    
    @IBAction func swipeChangeFilter(_ swipeGesture: UISwipeGestureRecognizer) {
        switch swipeGesture.direction {
        case .left:
            _currentIdx = (_currentIdx + 1) % avaliableFilters.count
        case .right:
            _currentIdx = _currentIdx - 1
            if _currentIdx < 0 {
                _currentIdx += avaliableFilters.count
            }
        default:
            assert(false)
        }
        
        _capturePipeline.changeFilter(_currentIdx)
        
    }
    
    @IBAction func toggleRecording(_: Any) {
        if _recording {
            _capturePipeline.stopRecording()
        } else {
            // Disable the idle timer while recording
            UIApplication.shared.isIdleTimerDisabled = true
            
            // Make sure we have time to finish saving the movie if the app is backgrounded during recording
            if UIDevice.current.isMultitaskingSupported {
                _backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: {})
            }
            
            recordButton.isEnabled = false; // re-enabled once recording has finished starting
            recordButton.setTitle("Stop", for: .normal)
            
            _capturePipeline.startRecording()
            
            _recording = true
            
            player.pause()
            tapPlayView(0)
        }
    }
    
    //MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerV.player = player
        playerV.playerLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        
        timelineV.contentInset = UIEdgeInsets(top: 0, left: view.bounds.width/2, bottom: 0, right: view.bounds.width/2)
        timelineV.panGestureRecognizer.addTarget(self, action: #selector(type(of: self).pan))
        
        downloadProgressLayer = CAShapeLayer()
        downloadProgressLayer!.frame = playerV.bounds
        downloadProgressLayer!.position = CGPoint(x:playerV.bounds.width/2, y:playerV.bounds.height/2)
        playerV.layer.addSublayer(downloadProgressLayer!)
        
        _capturePipeline = RosyWriterCapturePipeline(delegate: self, callbackQueue: DispatchQueue.main)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.applicationDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: UIApplication.shared)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: UIApplication.shared)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.deviceOrientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: UIDevice.current)
        
        // Keep track of changes to the device orientation so we can update the capture pipeline
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // the willEnterForeground and didEnterBackground notifications are subsequently used to update _allowedToUseGPU
        _allowedToUseGPU = (UIApplication.shared.applicationState != .background)
        _capturePipeline.renderingEnabled = _allowedToUseGPU
        
        if let url = url {
            addClip(url)
        }
    
        player.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions(rawValue: NSKeyValueObservingOptions.new.rawValue | NSKeyValueObservingOptions.old.rawValue), context: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            if player.rate == 1  {
                playButton.isHidden = true
            }else{
                playButton.isHidden = false
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        player.pause()
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: UIDevice.current)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        
        _capturePipeline.stopRunning()
//        audioLevelTimer?.cancel()
    }
    
    
    
    @objc func applicationDidEnterBackground() {
        // Avoid using the GPU in the background
        _allowedToUseGPU = false
        _capturePipeline?.renderingEnabled = false
        
        _capturePipeline?.stopRecording() // a no-op if we aren't recording
        
        // We reset the OpenGLPixelBufferView to ensure all resources have been cleared when going to the background.
        _previewView?.reset()
    }
    
    @objc func applicationWillEnterForeground() {
        _allowedToUseGPU = true
        _capturePipeline?.renderingEnabled = true
    }
    
    // MARK: - UICollectionViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let _timelineView = scrollView as? UICollectionView, player.rate == 0, UIDevice.current.orientation.isPortrait {
            currentTime = Double((_timelineView.contentOffset.x + _timelineView.bounds.width/2) / _timelineView.bounds.height) * interval
        }
    }
    
    @IBAction func pan(_ recognizer: UIPanGestureRecognizer) {
        player.pause()
        seekTimer?.invalidate()
        recordTimer?.invalidate()
        
        if downloadProgress == 0 {
            isRecording = false
        }
        _capturePipeline.stopRunning()
    }
    
    @IBAction func pinch(_ pinchRecognizer: UIPinchGestureRecognizer) {
        guard let firstVideoTrack = composition?.tracks(withMediaType: AVMediaType.video).first else {
            return
        }
        
        var expiredIndexPaths = self.timelineV.indexPathsForVisibleItems.filter({ (indexPath) -> Bool in
            guard let thumbnailCell = self.timelineV.cellForItem(at: indexPath) as? ThumbnailCell else {
                return false
            }
            
            let bias = CMTime(seconds: self.interval * Double(indexPath.item), preferredTimescale: 600)
            let expectedThumbnailTime = firstVideoTrack.segments[indexPath.section].timeMapping.target.start + bias
            
            if abs(((thumbnailCell.thumbnailTime ?? .zero) - expectedThumbnailTime).seconds) > 0.1 {
                return true
            } else {
                return false
            }
        })
        
        let prevInterval = interval
        
        interval = tmpInterval / Double(pinchRecognizer.scale)
        if interval < 0.04 {
            interval = 0.04
        }
        if interval > composition!.duration.seconds / 5 {
            interval = composition!.duration.seconds / 5
        }
        
        if interval > prevInterval {
            var toBeDeleted: [IndexPath] = []
            for section in 0..<firstVideoTrack.segments.count {
                toBeDeleted.append(contentsOf: (numberOfItemsInSection(section: section, interval: interval)..<numberOfItemsInSection(section: section, interval: prevInterval)).map({IndexPath(item: $0, section: section)}))
            }
            
            expiredIndexPaths.removeAll { toBeDeleted.contains($0) }

            toBeDeleted.append(contentsOf: expiredIndexPaths)
            toBeDeleted = toBeDeleted.sorted(by: {
                if $0.section < $1.section {
                    return true
                } else if $0.section > $1.section {
                    return false
                } else {
                    return $0.item < $1.item
                }
            })
            
            expiredIndexPaths = expiredIndexPaths.sorted(by: {
                if $0.section < $1.section {
                    return true
                } else if $0.section > $1.section {
                    return false
                } else {
                    return $0.item < $1.item
                }
            })
            
            timelineV.performBatchUpdates({
                timelineV.deleteItems(at: toBeDeleted.reversed())
                timelineV.insertItems(at: expiredIndexPaths)
            }, completion: {(succeed) in
//                self.timelineV.contentOffset.x = CGFloat(self.currentTime/self.interval)*self.timelineV.bounds.height - self.timelineV.bounds.width/2
            })
        } else if interval < prevInterval {
            var toBeInserted: [IndexPath] = []
            for section in 0..<firstVideoTrack.segments.count {
                toBeInserted.append(contentsOf: (numberOfItemsInSection(section: section, interval: prevInterval)..<numberOfItemsInSection(section: section, interval: interval)).map({IndexPath(item: $0, section: section)}))
            }
            
            toBeInserted.append(contentsOf: expiredIndexPaths)
            toBeInserted = toBeInserted.sorted(by: {
                if $0.section < $1.section {
                    return true
                } else if $0.section > $1.section {
                    return false
                } else {
                    return $0.item < $1.item
                }
            })
            
            expiredIndexPaths = expiredIndexPaths.sorted(by: {
                if $0.section < $1.section {
                    return true
                } else if $0.section > $1.section {
                    return false
                } else {
                    return $0.item < $1.item
                }
            })
            
            timelineV.performBatchUpdates({
                timelineV.deleteItems(at: expiredIndexPaths.reversed())
                timelineV.insertItems(at: toBeInserted)
            }, completion: {(succeed) in
//                self.timelineV.contentOffset.x = CGFloat(self.currentTime/self.interval)*self.timelineV.bounds.height - self.timelineV.bounds.width/2
            })
        }
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        player.pause()
        seekTimer?.invalidate()
        recordTimer?.invalidate()
        
        if downloadProgress == 0 {
            isRecording = false
        }

        if let pinch = gestureRecognizer as? UIPinchGestureRecognizer {
            tmpInterval = interval
        }
        return true
    }
    
    var tmpInterval: Double = 0
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let firstVideoTrack = composition?.tracks(withMediaType: AVMediaType.video).first else {
            return
        }
        
        if player.rate != 0 {
            tapPlayView(0)
        }
        
        let segment = firstVideoTrack.segments[indexPath.section]
        recordTimeRange = segment.timeMapping.target
        timelineV.contentOffset.x = CGFloat(recordTimeRange.start.seconds / interval) * timelineV.bounds.height - timelineV.bounds.width/2
        
        let playerItem = AVPlayerItem(asset: composition!)
        player.replaceCurrentItem(with: playerItem)
        player.seek(to: recordTimeRange.start)

        isRecording = true

//        if histograms.index(where: {$0.time == recordTimeRange.start}) != nil {
            _capturePipeline.startRunning(actionSegment.selectedSegmentIndex)
//            audioLevelTimer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0),
//                                                       queue: DispatchQueue.global())
//            audioLevelTimer?.schedule(deadline: .now(), repeating: .milliseconds(100))
//            audioLevelTimer?.setEventHandler {
//                DispatchQueue.main.async {
//                    if let audioChannel = self._capturePipeline.audioChannels?.first {
//                        self.audioLevel.progress = (50 + audioChannel.averagePowerLevel) / 50.0
//                    } else {
//                        self.audioLevel.progress = 0
//                    }
//                }
//            }
//            audioLevelTimer?.resume()
//        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        guard let firstVideoTrack = composition?.tracks(withMediaType: AVMediaType.video).first else {
            return 0
        }
        
        return firstVideoTrack.segments.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        guard let firstVideoTrack = composition?.tracks(withMediaType: AVMediaType.video).first else {
            return 0
        }
        
        return Int(ceil(firstVideoTrack.segments[section].timeMapping.target.duration.seconds / interval))
    }
    
    func numberOfItemsInSection(section: Int, interval: Double) -> Int {
        guard let firstVideoTrack = composition?.tracks(withMediaType: AVMediaType.video).first else {
            return 0
        }
        
        return Int(ceil(firstVideoTrack.segments[section].timeMapping.target.duration.seconds / interval))
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "thumbnail cell", for: indexPath)
        
        if let thumbnailCell = cell as? ThumbnailCell {
            thumbnailCell.backgroundColor = #colorLiteral(red: 1, green: 0, blue: 0, alpha: 0)
            thumbnailCell.imageV.clipsToBounds = true
            thumbnailCell.imageV.contentMode = .scaleAspectFill
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let thumbnailCell = cell as? ThumbnailCell, let firstVideoTrack = composition?.tracks(withMediaType: AVMediaType.video).first else {
            return
        }
        
        thumbnailCell.imageV.image = nil
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let thumbnailCell = cell as? ThumbnailCell, let firstVideoTrack = composition?.tracks(withMediaType: AVMediaType.video).first else {
            return
        }
        
        let bias = CMTime(seconds: interval * Double(indexPath.item), preferredTimescale: 600)
        let thumbnailTime = firstVideoTrack.segments[indexPath.section].timeMapping.target.start + bias
        
        thumbnailCell.thumbnailTime = thumbnailTime
        
        let imageGenerator = AVAssetImageGenerator.init(asset: composition!)
        imageGenerator.maximumSize = CGSize(width: timelineV.bounds.height * 2, height: timelineV.bounds.height * 2)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.videoComposition = videoComposition
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: [thumbnailTime as NSValue]) { (requestedTime, image, actualTime, result, error) in
            if (image != nil) {
                DispatchQueue.main.async {
                    thumbnailCell.imageV.image = UIImage.init(cgImage: image!)
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let cell = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "shot separator", for: indexPath)
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        guard let firstVideoTrack = composition?.tracks(withMediaType: AVMediaType.video).first else {
            return .zero
        }
        
        let duration = firstVideoTrack.segments[indexPath.section].timeMapping.target.duration.seconds
        
        let cellTimeDuration = duration - interval * Double(indexPath.item)
        if cellTimeDuration <= interval {
            let width = CGFloat(cellTimeDuration / interval) * timelineV.bounds.height
            return CGSize(width: max(width-2,0), height: timelineV.bounds.height)
        }
        
        return CGSize(width: timelineV.bounds.height, height: timelineV.bounds.height)
    }
    
    @IBAction func tapPlayView(_ sender: Any) {
        if player.rate == 0 {
            // Not playing forward, so play.
            if currentTime == player.currentItem!.duration.seconds {
                // At end, so got back to begining.
                currentTime = 0.0
            }
            
            player.play()
            
            //todo: animate
            if isRecording {
                recordTimer?.invalidate()
                recordTimer = Timer.scheduledTimer(withTimeInterval: recordTimeRange.end.seconds-currentTime+0.39, repeats: false, block: { (timer) in
                   self.timelineV.contentOffset.x = CGFloat(self.recordTimeRange.start.seconds / self.interval) * self.timelineV.bounds.height - self.timelineV.bounds.width/2
                    self.tapPlayView(0)
                    self.player.seek(to: self.recordTimeRange.start)
                    
                    if self._recording {
//                        self.audioLevelTimer?.cancel()
                        self._capturePipeline.stopRunning()
                    }
                })
            }
            
            seekTimer?.invalidate()
            seekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
                self.timelineV.contentOffset.x = CGFloat(self.currentTime/self.interval)*self.timelineV.bounds.height - self.timelineV.bounds.width/2
            })
        }
        else {
            // Playing, so pause.
            player.pause()
            seekTimer?.invalidate()
            recordTimer?.invalidate()
        }
    }
    
    //MARK: - RosyWriterCapturePipelineDelegate
    
    func capturePipeline(_ capturePipeline: RosyWriterCapturePipeline, didStopRunningWithError error: Error) {
        showError(error)
        
        recordButton.isEnabled = false
    }
    
    // Preview
    func capturePipeline(_ capturePipeline: RosyWriterCapturePipeline, previewPixelBufferReadyForDisplay previewPixelBuffer: CVPixelBuffer) {
        if !_allowedToUseGPU {
            return
        }
        if _previewView == nil {
            setupPreviewView()
        }
        
        _previewView!.displayPixelBuffer(previewPixelBuffer)
    }
    
    func capturePipelineDidRunOutOfPreviewBuffers(_ capturePipeline: RosyWriterCapturePipeline) {
        if _allowedToUseGPU {
            _previewView?.flushPixelBufferCache()
        }
    }
    
    // Recording
    func capturePipelineRecordingDidStart(_ capturePipeline: RosyWriterCapturePipeline) {
        recordButton.isEnabled = true
        recordButton.setTitle("⏹", for: .normal)
    }
    
    func capturePipelineRecordingWillStop(_ capturePipeline: RosyWriterCapturePipeline) {
        // Disable record button until we are ready to start another recording
        recordButton.isEnabled = false
        recordButton.setTitle("🔴", for: .normal)
    }
    
    func capturePipelineRecordingDidStop(_ capturePipeline: RosyWriterCapturePipeline) {
        
        recordingStopped()
        capturePipeline.stopRunning()
        
        let newAsset = AVAsset(url: capturePipeline._recordingURL)
        
        /*
         Using AVAsset now runs the risk of blocking the current thread (the
         main UI thread) whilst I/O happens to populate the properties. It's
         prudent to defer our work until the properties we need have been loaded.
         */
        newAsset.loadValuesAsynchronously(forKeys: type(of: self).assetKeysRequiredToPlay) {
            /*
             The asset invokes its completion handler on an arbitrary queue.
             To avoid multiple threads using our internal state at the same time
             we'll elect to use the main thread at all times, let's dispatch
             our handler to the main queue.
             */
            DispatchQueue.main.async {
                
                /*
                 Test whether the values of each of the keys we need have been
                 successfully loaded.
                 */
                for key in type(of: self).assetKeysRequiredToPlay {
                    var error: NSError?
                    
                    if newAsset.statusOfValue(forKey: key, error: &error) == .failed {
                        return
                    }
                }
                
                // We can't play this asset.
                if !newAsset.isPlayable || newAsset.hasProtectedContent {
                    return
                }
                
                /*
                 We can play this asset. Create a new `AVPlayerItem` and make
                 it our player's current item.
                 */
                
                if let videoAssetTrack = newAsset.tracks(withMediaType: .video).first {
                
                    let secondVideoTrack = self.composition!.tracks(withMediaType: .video)[1]
                    
//                    if let recordedSegment = secondVideoTrack.segment(forTrackTime: self.recordTimeRange.start), recordedSegment.timeMapping.target == self.recordTimeRange {
                        secondVideoTrack.removeTimeRange(self.recordTimeRange)
//                    }
                    
                    try! secondVideoTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: self.recordTimeRange.duration), of: videoAssetTrack, at: self.recordTimeRange.start)
                    
                    self.secondTrackTransform = videoAssetTrack.getTransform(renderSize: self.videoComposition!.renderSize)
                }
                
                if let audioAssetTrack = newAsset.tracks(withMediaType: .audio).first {
                    let compositionAudioTrack = self.composition!.tracks(withMediaType: .audio).first!
                    
//                    if let recordedSegment = compositionAudioTrack.segment(forTrackTime: self.recordTimeRange.start), recordedSegment.timeMapping.target == self.recordTimeRange {
                        compositionAudioTrack.removeTimeRange(self.recordTimeRange)
//                    }
                    
                    try! compositionAudioTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: self.recordTimeRange.duration), of: audioAssetTrack, at:self.recordTimeRange.start)
                }
                
                self.push()
                self.updatePlayer()
                
                if newAsset.tracks(withMediaType: .video).first != nil, let firstVideoTrack = self.composition!.tracks(withMediaType: .video).first, let segment = firstVideoTrack.segments.compactMap({
                    return $0.timeMapping.target == self.recordTimeRange ? $0 : nil
                }).first, let section = firstVideoTrack.segments.firstIndex(of: segment) {
                    self.timelineV.reloadSections(IndexSet(integer: section))
                }
                
                self.isRecording = false
            }
        }
    }
    
    func capturePipeline(_ capturePipeline: RosyWriterCapturePipeline, recordingDidFailWithError error: Error) {
        recordingStopped()
        showError(error)
    }
    
    
    //MARK: - Utilities
    
    
    func addClip(_ movieURL: URL) {
        let newAsset = AVURLAsset(url: movieURL, options: nil)
        
        /*
         Using AVAsset now runs the risk of blocking the current thread (the
         main UI thread) whilst I/O happens to populate the properties. It's
         prudent to defer our work until the properties we need have been loaded.
         */
        newAsset.loadValuesAsynchronously(forKeys: type(of: self).assetKeysRequiredToPlay) {
            /*
             The asset invokes its completion handler on an arbitrary queue.
             To avoid multiple threads using our internal state at the same time
             we'll elect to use the main thread at all times, let's dispatch
             our handler to the main queue.
             */
            DispatchQueue.main.async {
                
                /*
                 Test whether the values of each of the keys we need have been
                 successfully loaded.
                 */
                for key in type(of: self).assetKeysRequiredToPlay {
                    var error: NSError?
                    
                    if newAsset.statusOfValue(forKey: key, error: &error) == .failed {
                        let stringFormat = NSLocalizedString("error.asset_key_%@_failed.description", comment: "Can't use this AVAsset because one of it's keys failed to load")
                        
                        let message = String.localizedStringWithFormat(stringFormat, key)
                        
                        
                        return
                    }
                }
                
                // We can't play this asset.
                if !newAsset.isPlayable || newAsset.hasProtectedContent {
                    let message = NSLocalizedString("error.asset_not_playable.description", comment: "Can't use this AVAsset because it isn't playable or has protected content")
                    
                    
                    return
                }
                
                /*
                 We can play this asset. Create a new `AVPlayerItem` and make
                 it our player's current item.
                 */
                
                self.composition = AVMutableComposition()
                // Add two video tracks and two audio tracks.
                let compositionVideoTrack = self.composition!.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
                
                _ = self.composition!.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
                
                let compositionAudioTrack = self.composition!.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                
                let videoAssetTrack = newAsset.tracks(withMediaType: .video).first!
                                
                try! compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: newAsset.duration), of: videoAssetTrack, at: CMTime.zero)
                
                if let audioAssetTrack = newAsset.tracks(withMediaType: .audio).first {
                    try! compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: newAsset.duration), of: audioAssetTrack, at: CMTime.zero)
                    
                    assert(compositionAudioTrack?.timeRange == compositionVideoTrack?.timeRange)
                }
                
                self.videoComposition = AVMutableVideoComposition()
                let renderSize = videoAssetTrack.naturalSize.applying(videoAssetTrack.preferredTransform)
                self.videoComposition!.renderSize = CGSize(width: abs(renderSize.width), height: abs(renderSize.height))
                self.firstTrackTransform = videoAssetTrack.getTransform(renderSize: self.videoComposition!.renderSize)
                
                self.interval = self.composition!.duration.seconds / 5
                // update timeline
                self.push()
                self.updatePlayer()
                self.timelineV.reloadData()
                self.tapPlayView(0)
                
//                DispatchQueue.global(qos: .background).async {
//                    var videoTrackOutput : AVAssetReaderTrackOutput?
//                    var avAssetReader = try?AVAssetReader(asset: newAsset)
//
//                    if let videoTrack = newAsset.tracks(withMediaType: AVMediaType.video).first {
//                        videoTrackOutput = AVAssetReaderTrackOutput.init(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange])
//                        avAssetReader?.add(videoTrackOutput!)
//                    }
//
//                    avAssetReader?.startReading()
//
//                    while avAssetReader?.status == .reading {
//                        //视频
//                        if let sampleBuffer = videoTrackOutput?.copyNextSampleBuffer() {
//                            let sampleBufferTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
//                            DispatchQueue.main.async {
//                                self.downloadProgress =  CGFloat(sampleBufferTime.seconds / newAsset.duration.seconds)
//                            }
//
//                            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
//                            {
//
//                                var buffer = vImage_Buffer()
//                                buffer.data = CVPixelBufferGetBaseAddress(pixelBuffer)
//                                buffer.rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
//                                buffer.width = vImagePixelCount(CVPixelBufferGetWidth(pixelBuffer))
//                                buffer.height = vImagePixelCount(CVPixelBufferGetHeight(pixelBuffer))
//
//                                let bitmapInfo = CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderMask.rawValue | CGImageAlphaInfo.last.rawValue)
//
//                                var cgFormat = vImage_CGImageFormat(bitsPerComponent: 8,
//                                                                    bitsPerPixel: 32,
//                                                                    colorSpace: nil,
//                                                                    bitmapInfo: bitmapInfo,
//                                                                    version: 0,
//                                                                    decode: nil,
//                                                                    renderingIntent: .defaultIntent)
//
//
//                                var error = vImageBuffer_InitWithCVPixelBuffer(&buffer, &cgFormat, pixelBuffer, nil, nil, vImage_Flags(kvImageNoFlags))
//                                assert(kvImageNoError == error)
//                                defer {
//                                    free(buffer.data)
//                                }
//
//                                let histogramBins = (0...3).map { _ in
//                                    return [vImagePixelCount](repeating: 0, count: 256)
//                                }
//                                var mutableHistogram: [UnsafeMutablePointer<vImagePixelCount>?] = histogramBins.map {
//                                    return UnsafeMutablePointer<vImagePixelCount>(mutating: $0)
//                                }
//                                error = vImageHistogramCalculation_ARGB8888(&buffer,
//                                                                            &mutableHistogram,
//                                                                            vImage_Flags(kvImageNoFlags))
//                                assert(kvImageNoError == error)
//
//
//                                if let last_split_time = self.histograms.last?.time, let last_histogramBins = self.histograms.last?.histogram {
//
//                                    if self.costheta(histogramBins, last_histogramBins) < 0.9995, CMTimeSubtract(sampleBufferTime, last_split_time).seconds > 1 {
//
//                                        self.histograms.append((time: sampleBufferTime, histogram: histogramBins))
//
//                                        DispatchQueue.main.async {
//                                            self.split(at: sampleBufferTime)
//                                        }
//
//                                    }
//                                } else {
//                                    self.histograms.append((time: sampleBufferTime, histogram: histogramBins))
//                                }
//                            }
//                        }
//                    }
//
//                    DispatchQueue.main.async {
//                        self.push()
//                        self.downloadProgress = 1
//                    }
//
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
//                        self.downloadProgress = 0
//                    })
//                }
                
            }
        }
    }
    
    func costheta(_ histogram1: [[vImagePixelCount]], _ histogram2: [[vImagePixelCount]]) -> Double {
        let rgba1 = histogram1[0] + histogram1[1] + histogram1[2] + histogram1[3]
        let rgba2 = histogram2[0] + histogram2[1] + histogram2[2] + histogram2[3]
        let AB = zip(rgba1, rgba2).map(*).reduce(0, { (result, item) -> UInt in
            result + item
        })
        let AA = zip(rgba1, rgba1).map(*).reduce(0, { (result, item) -> UInt in
            result + item
        })
        let BB = zip(rgba2, rgba2).map(*).reduce(0, { (result, item) -> UInt in
            result + item
        })
        return Double(AB) / sqrt(Double(AA)) / sqrt(Double(BB))
    }
    
    
    func updatePlayer() {
        guard composition != nil else {
            return
        }
        
        let firstVideoTrack = composition!.tracks(withMediaType: .video)[0]
        let secondVideoTrack = composition!.tracks(withMediaType: .video)[1]
        
        videoComposition!.instructions = []
        videoComposition!.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        for segment in firstVideoTrack.segments {
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = segment.timeMapping.target
            
            if let segment2 = secondVideoTrack.segment(forTrackTime: segment.timeMapping.target.start),!segment2.isEmpty, segment2.timeMapping.target ==  segment.timeMapping.target {
                let transformer2 = AVMutableVideoCompositionLayerInstruction(assetTrack: secondVideoTrack)
                transformer2.setTransform(secondTrackTransform, at: instruction.timeRange.start)
                
                instruction.layerInstructions = [transformer2]
            } else {
                let transformer1 = AVMutableVideoCompositionLayerInstruction(assetTrack: firstVideoTrack)
                transformer1.setTransform(firstTrackTransform, at: instruction.timeRange.start)
                
                instruction.layerInstructions = [transformer1]
            }
            
            if let lastInstruction = videoComposition!.instructions.last {
                assert(lastInstruction.timeRange.end == instruction.timeRange.start)
            }
            videoComposition!.instructions.append(instruction)
        }
        
        if let lastInstruction = videoComposition!.instructions.last {
            assert(lastInstruction.timeRange.end == firstVideoTrack.timeRange.end)
        }
        
        if let audioTrack = composition!.tracks(withMediaType: .audio).first {
            audioMix = AVMutableAudioMix()
            // Create the audio mix input parameters object.
            let mixParameters = AVMutableAudioMixInputParameters(track: audioTrack)
            // Set the volume ramp to slowly fade the audio out over the duration of the composition.
            mixParameters.setVolume(1.f, at: .zero)
            // Attach the input parameters to the audio mix.
            audioMix?.inputParameters = [mixParameters]
        }
        
        let playerItem = AVPlayerItem(asset: composition!)
        playerItem.videoComposition = videoComposition
        playerItem.audioMix = audioMix
        
        let time = player.currentTime()
        player.replaceCurrentItem(with: playerItem)
        if time.isValid {
            player.seek(to: time)
        }
        
    }
    
    private func recordingStopped() {
        _recording = false
        recordButton.isEnabled = true
        //        recordButton.title = "Record"
        
        UIApplication.shared.isIdleTimerDisabled = false
        
        UIApplication.shared.endBackgroundTask(_backgroundRecordingID)
        _backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
    }
    
    private func setupPreviewView() {
        // Set up GL view
        _previewView = OpenGLPixelBufferView(frame: CGRect.zero)
        _previewView!.autoresizingMask = [UIView.AutoresizingMask.flexibleHeight, UIView.AutoresizingMask.flexibleWidth]
        
        let currentInterfaceOrientation = UIApplication.shared.statusBarOrientation
        _previewView!.transform = _capturePipeline.transformFromVideoBufferOrientationToOrientation(AVCaptureVideoOrientation(rawValue: currentInterfaceOrientation.rawValue)!, withAutoMirroring: true) // Front camera preview should be mirrored
        
        view.insertSubview(_previewView!, at: 0)
        _previewView!.frame = view.frame
    }
    
    @objc func deviceOrientationDidChange() {
        let deviceOrientation = UIDevice.current.orientation
        
        // Update recording orientation if device changes to portrait or landscape orientation (but not face up/down)
        if deviceOrientation.isPortrait || deviceOrientation.isLandscape {
            _capturePipeline.recordingOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue)!
        }
    }
    
    
    private func showError(_ error: Error) {
        let message = (error as NSError).localizedFailureReason
        if #available(iOS 8.0, *) {
            let alert = UIAlertController(title: error.localizedDescription, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            let alertView = UIAlertView(title: error.localizedDescription,
                                        message: message,
                                        delegate: nil,
                                        cancelButtonTitle: "OK")
            alertView.show()
        }
    }
    
    // MARK: - Models
    
    
    var url: URL?
    
    var artworkID: CKRecord.ID? = nil
    
    var infoRecord: CKRecord?
    
    var player = AVPlayer()
    
    var recordTimeRange = CMTimeRange.zero
    
//    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
//        return UIInterfaceOrientationMask.portrait
//    }
    
    var _currentIdx = 0
    
    let avaliableFilters = CoreImageFilters.avaliableFilters()
    
    var isExporting: Bool = false {
        didSet {
            tools.isHidden = isExporting
            actionSegment.isHidden = isExporting
            timelineV.isHidden = isExporting
            middleLineV.isHidden = isExporting
            
            titleTextV.isHidden = !isExporting
            uploadButton.isHidden = !isExporting
            saveLocalButton.isHidden = !isExporting
        }
    }
    
    var isRecording: Bool = false {
        didSet {
            if isRecording == true {
                (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .all
            } else {
                (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .portrait
                let value = UIInterfaceOrientation.portrait.rawValue
                UIDevice.current.setValue(value, forKey: "orientation")
            }
            
            navigationController?.navigationBar.isHidden = isRecording
            recordButton.isHidden = !isRecording
            tools.isHidden = isRecording
            downloadProgressLayer?.isHidden = isRecording
            actionSegment.isHidden = isRecording
//            audioLevel.isHidden = !isRecording
            
            if !isRecording {
//                audioLevelTimer?.cancel()
            }
            
            viewDidLayoutSubviews()
        }
    }
    
    
    @IBOutlet weak var playerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var playerWidthConstraint: NSLayoutConstraint!
    
    override func viewDidLayoutSubviews() {
        if isRecording {
            _capturePipeline.startRunning(actionSegment.selectedSegmentIndex)
            if let width = videoComposition?.renderSize.width, let height = videoComposition?.renderSize.height {
                
                if _previewView != nil {
                    let currentInterfaceOrientation = UIApplication.shared.statusBarOrientation
                    _previewView!.transform = _capturePipeline.transformFromVideoBufferOrientationToOrientation(AVCaptureVideoOrientation(rawValue: currentInterfaceOrientation.rawValue)!, withAutoMirroring: true) // Front camera preview should be mirrored
                }
                
                let xScale = view.frame.width / width
                let yScale = view.frame.height / height
                if xScale <= yScale {
                    let offsetY = (view.frame.height - height * xScale) / 2
                    _previewView?.frame = CGRect(x: 0, y: offsetY, width: view.frame.width, height: height * xScale)
                } else {
                    let offsetX = (view.frame.width - width * yScale) / 2
                    _previewView?.frame = CGRect(x: offsetX, y: 0, width: width * yScale, height: view.frame.height)
                }
                
                _previewView?.layoutIfNeeded()
            }
            
            switch(actionSegment.selectedSegmentIndex) {
            case 0:
                playerWidthConstraint = playerWidthConstraint.setMultiplier(multiplier: 1.0/3)
                playerHeightConstraint = playerHeightConstraint.setMultiplier(multiplier: 1.0/3)
                playerV.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
                
            case 1:
                playerWidthConstraint = playerWidthConstraint.setMultiplier(multiplier: 1.0)
                playerHeightConstraint = playerHeightConstraint.setMultiplier(multiplier: 1.0)
                playerV.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                
            default:
                _ = 1
            }
            
            if UIDevice.current.orientation.isLandscape {
                timelineV.isHidden = true
                middleLineV.isHidden = true
            } else {
                timelineV.isHidden = false
                middleLineV.isHidden = false
            }
            
        } else {
            playerWidthConstraint = playerWidthConstraint.setMultiplier(multiplier: 1.0)
            playerHeightConstraint = playerHeightConstraint.setMultiplier(multiplier: 1.0)
            playerV.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            timelineV.isHidden = false
            middleLineV.isHidden = false
        }
        
        playerV.layoutIfNeeded()
    }
    
    private var _recording: Bool = false {
        didSet {
            if _recording && actionSegment.selectedSegmentIndex == 1 {
                player.volume = 0
            } else {
                player.volume = 1
            }
        }
    }
    private var _backgroundRecordingID: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: 0)
    private var _allowedToUseGPU: Bool = false
    
    private var _previewView: OpenGLPixelBufferView?
    private var _capturePipeline: RosyWriterCapturePipeline!
    
    var histograms = [(time: CMTime, histogram: [[vImagePixelCount]])]()
    
    var seekTimer: Timer? = nil
    var recordTimer: Timer? = nil
    var interval: Double = 0
    
    // Attempt load and test these asset keys before playing.
    static let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    var currentTime: Double {
        get {
            return player.currentTime().seconds
        }
        set {
            let newTime = CMTimeMakeWithSeconds(newValue, preferredTimescale: 600)
            //todo: more tolerance
            player.seek(to: newTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        }
    }
    
    var composition: AVMutableComposition? = nil
    var videoComposition: AVMutableVideoComposition? = nil
    var audioMix: AVMutableAudioMix? = nil
    var firstTrackTransform: CGAffineTransform = CGAffineTransform.identity
    var secondTrackTransform: CGAffineTransform = CGAffineTransform.identity
    
    /*
     A token obtained from calling `player`'s `addPeriodicTimeObserverForInterval(_:queue:usingBlock:)`
     method.
     */
    
//    var audioLevelTimer: DispatchSourceTimer?
    var downloadProgressLayer: CAShapeLayer?
    var downloadProgress: CGFloat = 0 {
        didSet {
            timelineV.allowsSelection = downloadProgress == 0
            tools.isHidden = downloadProgress != 0 || isExporting
            saveLocalButton.isEnabled = downloadProgress == 0
            uploadButton.isEnabled = downloadProgress == 0
            titleTextV.isEditable = downloadProgress == 0
            if downloadProgress != 0 {
                downloadProgressLayer?.fillColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
                downloadProgressLayer?.path = CGPath(rect: playerV.bounds, transform: nil)
                downloadProgressLayer?.borderWidth = 0
                downloadProgressLayer?.lineWidth = 8
                downloadProgressLayer?.strokeColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
                downloadProgressLayer?.strokeStart = 0
                downloadProgressLayer?.strokeEnd = downloadProgress
            } else {
                downloadProgressLayer?.path = nil
            }
        }
    }
}

class ThumbnailCell: UICollectionViewCell {
    @IBOutlet weak var imageV: UIImageView!
    
    var thumbnailTime: CMTime? = nil
}

extension NSLayoutConstraint {
    
    func setMultiplier(multiplier:CGFloat) -> NSLayoutConstraint {
        
        NSLayoutConstraint.deactivate([self])
        
        let newConstraint = NSLayoutConstraint(
            item: firstItem,
            attribute: firstAttribute,
            relatedBy: relation,
            toItem: secondItem,
            attribute: secondAttribute,
            multiplier: multiplier,
            constant: constant)
        
        newConstraint.priority = priority
        newConstraint.shouldBeArchived = shouldBeArchived
        newConstraint.identifier = identifier
        
        NSLayoutConstraint.activate([newConstraint])
        return newConstraint
    }
}

extension AVAssetTrack {
    func getTransform(renderSize: CGSize) -> CGAffineTransform {
        let mySize = self.naturalSize.applying(self.preferredTransform)
        
        let xScale = renderSize.width / abs(mySize.width)
        let yScale = renderSize.height / abs(mySize.height)
        let renderScale = max(xScale, yScale)

        var offset = CGPoint.zero
        
        if xScale >= yScale {
            offset.y = (abs(mySize.height) * xScale - renderSize.height) / 2
        } else {
            offset.x = (abs(mySize.width) * yScale - renderSize.width) / 2
        }
        
        let transform = self.preferredTransform.concatenating(CGAffineTransform.init(translationX: mySize.width < 0 ? -mySize.width : 0, y: mySize.height < 0 ? -mySize.height : 0)).concatenating(CGAffineTransform.init(scaleX: renderScale, y: renderScale)).concatenating(CGAffineTransform.init(translationX: -offset.x, y: -offset.y))
        return transform
    }
}
