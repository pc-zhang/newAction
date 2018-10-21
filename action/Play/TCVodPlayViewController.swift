//
//  TCVodPlayViewController.swift
//  TXXiaoShiPinDemo
//
//  Created by zpc on 2018/9/24.
//  Copyright © 2018年 tencent. All rights reserved.
//

import UIKit
import Accelerate
import AVFoundation
import CoreServices

let kTCLivePlayError: String = "kTCLivePlayError"

class TCVodPlayViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching, RosyWriterCapturePipelineDelegate, UITextFieldDelegate, UIAlertViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, TCPlayViewCellDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - UI Controls
    
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var middleLine: UIView!
    
    @IBOutlet weak var backgroundTimelineView: UICollectionView! {
        didSet {
            backgroundTimelineView.contentOffset = CGPoint(x:-backgroundTimelineView.frame.width / 2, y:0)
            backgroundTimelineView.contentInset = UIEdgeInsets(top: 0, left: backgroundTimelineView.frame.width/2, bottom: 0, right: backgroundTimelineView.frame.width/2)
            backgroundTimelineView.panGestureRecognizer.addTarget(self, action: #selector(TCVodPlayViewController.pan))
        }
    }
    
    
    //MARK: - UI Actions
    
    @IBAction func localMovie(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.sourceType = .savedPhotosAlbum
        picker.mediaTypes = [kUTTypeMovie as String]
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }
    
    @IBAction func export(_ sender: Any) {
        // Create the export session with the composition and set the preset to the highest quality.
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: composition!)
        let exporter = AVAssetExportSession(asset: composition!, presetName: AVAssetExportPreset960x540)!
        // Set the desired output URL for the file created by the export process.
        exporter.outputURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        // Set the output file type to be a QuickTime movie.
        exporter.outputFileType = AVFileType.mov
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = videoComposition
        exporter.audioMix = audioMix
        let firstVideoTrack = self.composition!.tracks(withMediaType: .video).first!
        exporter.timeRange = firstVideoTrack.timeRange
        // Asynchronously export the composition to a video file and save this file to the camera roll once export completes.
        
        let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0),
                                                   queue: DispatchQueue.global())
        timer.scheduleRepeating(deadline: .now(), interval: .milliseconds(250))
        timer.setEventHandler {
            DispatchQueue.main.async {
                if let cell = self.tableView.visibleCells.first as? TCPlayViewCell
                {
                    cell.downloadProcess = CGFloat(exporter.progress)
                }
            }
        }
        timer.resume()
        
        exporter.exportAsynchronously {
            timer.cancel()
            DispatchQueue.main.async {
                if let cell = self.tableView.visibleCells.first as? TCPlayViewCell
                {
                    cell.downloadProcess = CGFloat(exporter.progress)
                }
                if (exporter.status == .completed) {
                    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(exporter.outputURL!.path)){
                        UISaveVideoAtPathToSavedPhotosAlbum(exporter.outputURL!.path, self, #selector(self.video), nil)
                    }
                } else {
                    _ = 1
                }
            }
        }
    }
    
    @objc func video(videoPath: NSString, didFinishSavingWithError error:NSError, contextInfo contextInfo:Any) -> Void {
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
            
            self.recordButton.isEnabled = false; // re-enabled once recording has finished starting
            self.recordButton.setTitle("Stop", for: .normal)
            
            _capturePipeline.startRecording()
            
            _recording = true
            
            tapPlayViewCell()
            Timer.scheduledTimer(withTimeInterval: self.recordTimeRange.duration.seconds+0.3, repeats: false, block: { (timer) in
                self._capturePipeline.stopRecording()
                self.tapPlayViewCell()
            })
            
        }
    }
    
    //MARK: - View lifecycle
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if composition==nil {
            composition = AVMutableComposition()
            // Add two video tracks and two audio tracks.
            _ = composition!.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            _ = composition!.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            _ = composition!.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        }
        
        if(!self.lives.isEmpty) {
            self.lives.removeAll()
        }
        
        tableView.rowHeight = tableView.bounds.height - 2
        tableView.contentSize.width = tableView.bounds.width
        tableView.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 1, right: 0)
        tableView.contentOffset = CGPoint(x: 0, y: -1)
        
        tableView.mj_header = MJRefreshNormalHeader(refreshingBlock: {
            self.isLoading = true
            self.lives = []
            self.liveListMgr?.queryVideoList(.up)
        })
        tableView.mj_header.isHidden = true
        
        tableView.mj_footer = MJRefreshAutoNormalFooter(refreshingBlock: {
            self.isLoading = true
            self.liveListMgr?.queryVideoList(.down)
        })
        tableView.mj_footer.isHidden = true
        
        // 先加载缓存的数据，然后再开始网络请求，以防用户打开是看到空数据
        //        liveListMgr.loadVodsFromArchive()
        //        doFetchList()
        
        DispatchQueue.main.async {
            self.tableView.mj_header.beginRefreshing()
        }
        
        tableView.mj_header.endRefreshing {
            self.isLoading = false
        }
        tableView.mj_footer.endRefreshing {
            self.isLoading = false
        }
        
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
        
        _addedObservers = true
        
        // the willEnterForeground and didEnterBackground notifications are subsequently used to update _allowedToUseGPU
        _allowedToUseGPU = (UIApplication.shared.applicationState != .background)
        _capturePipeline.renderingEnabled = _allowedToUseGPU
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)        
    }

    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if _addedObservers {
            NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)
            NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: UIDevice.current)
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        
        _labelTimer?.invalidate()
        _labelTimer = nil
        
        _capturePipeline.stopRunning()
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let playViewCell = cell as! TCPlayViewCell
        
        if indexPath.row < lives.count {
            let liveInfo = lives[indexPath.row]
            let playerItem = AVPlayerItem(url: URL(string: liveInfo.playurl)!)
            playViewCell.player.replaceCurrentItem(with: playerItem)
            playViewCell.player.seek(to: .zero)
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let playViewCell = cell as! TCPlayViewCell
        
        playViewCell.player.pause()
        playViewCell.player.replaceCurrentItem(with: nil)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let tableView = scrollView as? UITableView {
            let indexPath = IndexPath(row: Int((self.tableView.contentOffset.y + tableView.rowHeight/2) / tableView.rowHeight), section: 0)
            tableView.setContentOffset(CGPoint(x: 0, y: CGFloat(indexPath.row) * tableView.rowHeight - 1), animated: true)
            if let playViewCell = tableView.cellForRow(at: indexPath) as? TCPlayViewCell {
                playViewCell.player.play()
            }
            if let prevPlayViewCell = tableView.cellForRow(at: IndexPath(row: indexPath.row - 1, section: 0)) as? TCPlayViewCell {
                prevPlayViewCell.player.pause()
            }
            if let nextPlayViewCell = tableView.cellForRow(at: IndexPath(row: indexPath.row + 1, section: 0)) as? TCPlayViewCell {
                nextPlayViewCell.player.pause()
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return lives.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TCPlayViewCell.reuseIdentifier, for: indexPath) as? TCPlayViewCell else {
            fatalError("Expected `\(TCPlayViewCell.self)` type for reuseIdentifier \(TCPlayViewCell.reuseIdentifier). Check the configuration in Main.storyboard.")
        }
        
        cell.delegate = self
        
        return cell
    }
    
    // MARK: - UITableViewDataSourcePrefetching
    
    /// - Tag: Prefetching
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        // Begin asynchronously fetching data for the requested index paths.
    }
    
    /// - Tag: CancelPrefetching
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        // Cancel any in-flight requests for data for the specified index paths.
        
    }
    
    // MARK: - UICollectionViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let cell = self.tableView.visibleCells.first as? TCPlayViewCell, cell.player.rate == 0, let _timelineView = scrollView as? UICollectionView {
            currentTime = Double((_timelineView.contentOffset.x + _timelineView.frame.width/2) / (_timelineView.frame.width / visibleTimeRange))
        }
    }
    
    @IBAction func pan(_ recognizer: UIPanGestureRecognizer) {
        if let cell = self.tableView.visibleCells.first as? TCPlayViewCell {
            cell.player.pause()
        }
        seekTimer?.invalidate()
        isRecording = false
        tableView.visibleCells.first?.setNeedsLayout()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let compositionVideoTrack = self.composition!.tracks(withMediaType: AVMediaType.video).first!
        let segment = compositionVideoTrack.segments[indexPath.item]
        self.backgroundTimelineView.contentOffset.x = CGFloat(segment.timeMapping.target.start.seconds/Double(self.visibleTimeRange)*Double(self.backgroundTimelineView.frame.width)) - self.backgroundTimelineView.frame.size.width/2
        
        recordTimeRange = segment.timeMapping.target
        isRecording = true
        tableView.visibleCells.first?.setNeedsLayout()
        
        if let indexOfHistogram = histograms.index(where: {$0.time == recordTimeRange.start}) {
            _capturePipeline.startRunning()
            
            let leftSwipe = UISwipeGestureRecognizer(target: self, action: "swipeChangeFilter:")
            leftSwipe.direction = .left
            let rightSwipe = UISwipeGestureRecognizer(target: self, action: "swipeChangeFilter:")
            rightSwipe.direction = .right
            
            tableView.visibleCells.first?.addGestureRecognizer(leftSwipe)
            tableView.visibleCells.first?.addGestureRecognizer(rightSwipe)
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        let compositionVideoTrack = self.composition!.tracks(withMediaType: AVMediaType.video).first!
        
        assert(self.composition!.tracks(withMediaType: AVMediaType.video).count == 2)
        
        return compositionVideoTrack.segments.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let segmentView = collectionView.dequeueReusableCell(withReuseIdentifier: "segment", for: indexPath)
        segmentView.backgroundColor = #colorLiteral(red: 1, green: 0, blue: 0, alpha: 0)
        for view in segmentView.subviews {
            view.removeFromSuperview()
        }
        
        let compositionVideoTrack = self.composition!.tracks(withMediaType: AVMediaType.video).first!
        
        let imageGenerator = AVAssetImageGenerator.init(asset: composition!)
        imageGenerator.maximumSize = CGSize(width: self.backgroundTimelineView.bounds.height * 2, height: self.backgroundTimelineView.bounds.height * 2)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.videoComposition = videoComposition
        
        if true {
            var times = [NSValue]()
            
            let timerange = (compositionVideoTrack.segments[indexPath.item].timeMapping.target)
            
            // Generate an image at time zero.
            let incrementTime = CMTime(seconds: Double(backgroundTimelineView.frame.height /  scaledDurationToWidth), preferredTimescale: 600)
            
            var iterTime = timerange.start
            
            while iterTime <= timerange.end {
                times.append(iterTime as NSValue)
                iterTime = CMTimeAdd(iterTime, incrementTime);
            }
            
            // Set a videoComposition on the ImageGenerator if the underlying movie has more than 1 video track.
            imageGenerator.generateCGImagesAsynchronously(forTimes: times as [NSValue]) { (requestedTime, image, actualTime, result, error) in
                if (image != nil) {
                    DispatchQueue.main.async {
                        let nextX = CGFloat(CMTimeGetSeconds(requestedTime - timerange.start)) * self.scaledDurationToWidth
                        let nextView = UIImageView.init(frame: CGRect(x: nextX, y: 0.0, width: self.backgroundTimelineView.bounds.height, height: self.backgroundTimelineView.bounds.height))
                        nextView.contentMode = .scaleAspectFill
                        nextView.clipsToBounds = true
                        nextView.image = UIImage.init(cgImage: image!)
                        segmentView.addSubview(nextView)
                        
                        if nextX == 0 {
                            let whiteline = UIView(frame: CGRect(x:0,y:0,width:1,height:segmentView.bounds.height))
                            whiteline.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
                            segmentView.addSubview(whiteline)
                        }
                    }
                }
            }
        }
        
        return segmentView
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let compositionVideoTrack = self.composition!.tracks(withMediaType: AVMediaType.video).first!
        
        return CGSize(width: CGFloat(CMTimeGetSeconds((compositionVideoTrack.segments[indexPath.row].timeMapping.target.duration))) * scaledDurationToWidth, height: backgroundTimelineView.frame.height)
    }
    
    //MARK: - TCPlayViewCellDelegate
    
    func funcIsRecording() -> Bool {
        return isRecording
    }
    
    func chorus(process processHandler: ((CGFloat) -> Void)!) {
        TCUtil.report(xiaoshipin_videochorus, userName: nil, code: 0, msg: "合唱事件")
        if let index = tableView.indexPathsForVisibleRows?.first?.row {
            TCUtil.downloadVideo(self.lives[index].playurl, process: processHandler) { (videoPath) in
                self.addClip(try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(videoPath!))
            }
        }
    }
    
    func tapPlayViewCell() {
        if let cell = self.tableView.visibleCells.first as? TCPlayViewCell {
            if cell.player.rate == 0 {
                // Not playing forward, so play.
                if currentTime == duration {
                    // At end, so got back to begining.
                    currentTime = 0.0
                }
                
                cell.player.play()
                
                //todo: animate
                if #available(iOS 10.0, *) {
                    seekTimer?.invalidate()
                    seekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
                        self.backgroundTimelineView.contentOffset.x = CGFloat(self.currentTime/Double(self.visibleTimeRange)*Double(self.backgroundTimelineView.frame.width)) - self.backgroundTimelineView.frame.size.width/2
                    })
                } else {
                    // Fallback on earlier versions
                }
            }
            else {
                // Playing, so pause.
                cell.player.pause()
                seekTimer?.invalidate()
            }
        }
    }
    
    //MARK: - RosyWriterCapturePipelineDelegate
    
    func capturePipeline(_ capturePipeline: RosyWriterCapturePipeline, didStopRunningWithError error: Error) {
        self.showError(error)
        
        self.recordButton.isEnabled = false
    }
    
    // Preview
    func capturePipeline(_ capturePipeline: RosyWriterCapturePipeline, previewPixelBufferReadyForDisplay previewPixelBuffer: CVPixelBuffer) {
        if !_allowedToUseGPU {
            return
        }
        if _previewView == nil {
            self.setupPreviewView()
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
        self.recordButton.isEnabled = true
        self.recordButton.setTitle("Stop", for: .normal)
    }
    
    func capturePipelineRecordingWillStop(_ capturePipeline: RosyWriterCapturePipeline) {
        // Disable record button until we are ready to start another recording
        self.recordButton.isEnabled = false
        self.recordButton.setTitle("Record", for: .normal)
    }
    
    func capturePipelineRecordingDidStop(_ capturePipeline: RosyWriterCapturePipeline) {
        
        self.recordingStopped()
        capturePipeline.stopRunning()

        let newAsset = AVAsset(url: capturePipeline._recordingURL)
        
        /*
         Using AVAsset now runs the risk of blocking the current thread (the
         main UI thread) whilst I/O happens to populate the properties. It's
         prudent to defer our work until the properties we need have been loaded.
         */
        newAsset.loadValuesAsynchronously(forKeys: TCVodPlayViewController.assetKeysRequiredToPlay) {
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
                for key in TCVodPlayViewController.assetKeysRequiredToPlay {
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
                
                let videoAssetTrack = newAsset.tracks(withMediaType: .video).first!
                
                let secondVideoTrack = self.composition!.tracks(withMediaType: .video)[1]
                
                secondVideoTrack.preferredTransform = videoAssetTrack.preferredTransform
                
                if let recordedSegment = secondVideoTrack.segment(forTrackTime: self.recordTimeRange.start), recordedSegment.timeMapping.target == self.recordTimeRange {
                    secondVideoTrack.removeTimeRange(self.recordTimeRange)
                }
                
                try! secondVideoTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: self.recordTimeRange.duration), of: videoAssetTrack, at: self.recordTimeRange.start)
                
                self.updatePlayer()
                self.currentTime = self.recordTimeRange.start.seconds
                
                self.isRecording = false
                self.tableView.visibleCells.first?.setNeedsLayout()
            }
        }
    }
    
    func capturePipeline(_ capturePipeline: RosyWriterCapturePipeline, recordingDidFailWithError error: Error) {
        self.recordingStopped()
        self.showError(error)
    }
    
    // MARK: UIImagePickerControllerDelegate, UINavigationControllerDelegate
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let videoURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
            addClip(videoURL)
        }
        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Net fetch
    /**
     * 拉取直播列表。TCLiveListMgr在启动是，会将所有数据下载下来。在未全部下载完前，通过loadLives借口，
     * 能取到部分数据。通过finish接口，判断是否已取到最后的数据
     *
     */
    func doFetchList() {
        let range = NSMakeRange(self.lives.count, 20)

        var finish: ObjCBool = false
        var result = liveListMgr?.readVods(range, finish: &finish)
        
        if result != nil {
            result = mergeResult(result: result! as! [TCLiveInfo])
            self.lives.append(contentsOf: result! as! [TCLiveInfo])
        } else {
            if finish.boolValue {
//                let hud = HUDHelper.sharedInstance()?.tipMessage("没有啦")
//                hud?.isUserInteractionEnabled = false
            }
        }
        tableView.mj_header.isHidden = true
        tableView.mj_footer.isHidden = true
        tableView.mj_header.endRefreshing()
        tableView.mj_footer.endRefreshing()
        tableView.reloadData()
    }
    
    /**
     *  将取到的数据于已存在的数据进行合并。
     *
     *  @param result 新拉取到的数据
     *
     *  @return 新数据去除已存在记录后，剩余的数据
     */
    func mergeResult(result: [TCLiveInfo]) -> [TCLiveInfo] {
        // 每个直播的播放地址不同，通过其进行去重处理
        let existArray = self.lives.map { (obj) -> String in
            obj.playurl
        }
        
        let newArray = result.filter { (obj) -> Bool in
            !existArray.contains(obj.playurl)
        }
        
        return newArray
    }
    
    /**
     *  TCLiveListMgr有新数据过来
     *
     *  @param noti
     */
    @objc func newDataAvailable(noti: NSNotification) {
        self.doFetchList()
    }
    
    /**
     *  TCLiveListMgr数据有更新
     *
     *  @param noti
     */
    @objc func listDataUpdated(noti: NSNotification) {
    //    [self setup];
    }
    
    
    /**
     *  TCLiveListMgr内部出错
     *
     *  @param noti
     */
    @objc func svrError(noti: NSNotification) {
        let e = noti.object
        if ((e as? NSError) != nil) {
//            HUDHelper.alert(e.debugDescription)
        }
        
        // 如果还在加载，停止加载动画
        if self.isLoading {
            tableView.mj_header.endRefreshing()
            tableView.mj_footer.endRefreshing()
            self.isLoading = false
        }
    }
    
    /**
     *  TCPlayViewController出错，加入房间失败
     *
     */
    @objc func playError(noti: NSNotification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(0.5), execute: {
            //        [self.tableView.mj_header beginRefreshing];
            //加房间失败后，刷新列表，不需要刷新动画
            self.lives = []
            self.isLoading = true
            self.liveListMgr?.queryVideoList(.up)
        })
    }
    
    
    //MARK: - Utilities

    
    func addClip(_ movieURL: URL) {
        self.tableView.isScrollEnabled = false
        let newAsset = AVURLAsset(url: movieURL, options: nil)
        
        /*
         Using AVAsset now runs the risk of blocking the current thread (the
         main UI thread) whilst I/O happens to populate the properties. It's
         prudent to defer our work until the properties we need have been loaded.
         */
        newAsset.loadValuesAsynchronously(forKeys: TCVodPlayViewController.assetKeysRequiredToPlay) {
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
                for key in TCVodPlayViewController.assetKeysRequiredToPlay {
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
                
                compositionVideoTrack?.preferredTransform = videoAssetTrack.preferredTransform
                
                try! compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: newAsset.duration), of: videoAssetTrack, at: CMTime.zero)
                
                if let audioAssetTrack = newAsset.tracks(withMediaType: .audio).first {
                    try! compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: newAsset.duration), of: audioAssetTrack, at: CMTime.zero)
                    
                    assert(compositionAudioTrack?.timeRange == compositionVideoTrack?.timeRange)
                    
                }
                
                self.backgroundTimelineView.isHidden = false
                self.middleLine.isHidden = false
                self.exportButton.isHidden = false
                
                // update timeline
                if let cell = self.tableView.visibleCells.first as? TCPlayViewCell {
                    let currentTime = cell.player.currentTime()
                    self.updatePlayer()
                    self.currentTime = currentTime.seconds
                }
                
                DispatchQueue.global(qos: .background).async {
                    var videoTrackOutput : AVAssetReaderTrackOutput?
                    var avAssetReader = try?AVAssetReader(asset: self.composition!)

                    if let videoTrack = self.composition!.tracks(withMediaType: AVMediaType.video).first {
                        videoTrackOutput = AVAssetReaderTrackOutput.init(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange])
                        avAssetReader?.add(videoTrackOutput!)
                    }

                    avAssetReader?.startReading()

                    while avAssetReader?.status == .reading {
                        //视频
                        if let sampleBuffer = videoTrackOutput?.copyNextSampleBuffer() {
                            let sampleBufferTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                            DispatchQueue.main.async {
                                if let cell = self.tableView.visibleCells.first as? TCPlayViewCell
                                {
                                    cell.downloadProcess = 0.5 + CGFloat(sampleBufferTime.seconds / self.composition!.duration.seconds)/2
                                }
                            }

                            if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
                            {

                                var buffer = vImage_Buffer()
                                buffer.data = CVPixelBufferGetBaseAddress(pixelBuffer)
                                buffer.rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
                                buffer.width = vImagePixelCount(CVPixelBufferGetWidth(pixelBuffer))
                                buffer.height = vImagePixelCount(CVPixelBufferGetHeight(pixelBuffer))

                                let bitmapInfo = CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderMask.rawValue | CGImageAlphaInfo.last.rawValue)

                                var cgFormat = vImage_CGImageFormat(bitsPerComponent: 8,
                                                                    bitsPerPixel: 32,
                                                                    colorSpace: nil,
                                                                    bitmapInfo: bitmapInfo,
                                                                    version: 0,
                                                                    decode: nil,
                                                                    renderingIntent: .defaultIntent)


                                var error = vImageBuffer_InitWithCVPixelBuffer(&buffer, &cgFormat, pixelBuffer, nil, nil, vImage_Flags(kvImageNoFlags))
                                assert(kvImageNoError == error)
                                defer {
                                    free(buffer.data)
                                }

                                let histogramBins = (0...3).map { _ in
                                    return [vImagePixelCount](repeating: 0, count: 256)
                                }
                                var mutableHistogram: [UnsafeMutablePointer<vImagePixelCount>?] = histogramBins.map {
                                    return UnsafeMutablePointer<vImagePixelCount>(mutating: $0)
                                }
                                error = vImageHistogramCalculation_ARGB8888(&buffer,
                                                                            &mutableHistogram,
                                                                            vImage_Flags(kvImageNoFlags))
                                assert(kvImageNoError == error)


                                if let last_split_time = self.histograms.last?.time, let last_histogramBins = self.histograms.last?.histogram {

                                    if self.costheta(histogramBins, last_histogramBins) < 0.9995, CMTimeSubtract(sampleBufferTime, last_split_time).seconds > 1 {

                                        self.histograms.append((time: sampleBufferTime, histogram: histogramBins))

                                        DispatchQueue.main.async {
                                            let firstVideoTrack = self.composition!.tracks(withMediaType: .video).first!

                                            if let segment = firstVideoTrack.segment(forTrackTime: sampleBufferTime), segment.timeMapping.target.containsTime(sampleBufferTime) {
                                                try! firstVideoTrack.insertTimeRange(segment.timeMapping.target, of: firstVideoTrack, at: segment.timeMapping.target.end)
                                                firstVideoTrack.removeTimeRange(CMTimeRange(start:sampleBufferTime, duration:segment.timeMapping.target.duration + CMTime(value: 1, timescale: 600)))

                                                if let audioTrack = self.composition!.tracks(withMediaType: .audio).first {
                                                    try! audioTrack.insertTimeRange(segment.timeMapping.target, of: audioTrack, at: segment.timeMapping.target.end)
                                                    audioTrack.removeTimeRange(CMTimeRange(start:sampleBufferTime, duration:segment.timeMapping.target.duration + CMTime(value: 1, timescale: 600)))
                                                }
                                            }

                                            self.backgroundTimelineView.reloadData()

                                        }

                                    }
                                } else {
                                    self.histograms.append((time: sampleBufferTime, histogram: histogramBins))
                                }
                            }
                        }
                    }
                }
                
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
        if self.composition == nil {
            return
        }
        
        let firstVideoTrack = self.composition!.tracks(withMediaType: .video)[0]
        let secondVideoTrack = self.composition!.tracks(withMediaType: .video)[1]
        
        self.videoComposition = AVMutableVideoComposition()
        let renderSize = firstVideoTrack.naturalSize.applying(firstVideoTrack.preferredTransform)
        self.videoComposition!.renderSize = CGSize(width: abs(renderSize.width), height: abs(renderSize.height))
        self.videoComposition!.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        for segment in firstVideoTrack.segments {
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = segment.timeMapping.target
            
            if let segment2 = secondVideoTrack.segment(forTrackTime: segment.timeMapping.target.start),!segment2.isEmpty, segment2.timeMapping.target ==  segment.timeMapping.target {
                let transformer2 = AVMutableVideoCompositionLayerInstruction(assetTrack: secondVideoTrack)
                
                let renderSize2 = secondVideoTrack.naturalSize.applying(secondVideoTrack.preferredTransform)
                let renderScale = self.videoComposition!.renderSize.height / renderSize2.height
                transformer2.setTransform(secondVideoTrack.preferredTransform.scaledBy(x: renderScale, y: renderScale), at: instruction.timeRange.start)
                instruction.layerInstructions = [transformer2]
            } else {
                let transformer1 = AVMutableVideoCompositionLayerInstruction(assetTrack: firstVideoTrack)
                transformer1.setTransform(firstVideoTrack.preferredTransform, at: instruction.timeRange.start)
                instruction.layerInstructions = [transformer1]
            }
            
            if let lastInstruction = self.videoComposition!.instructions.last {
                assert(lastInstruction.timeRange.end == instruction.timeRange.start)
            }
            self.videoComposition!.instructions.append(instruction)
        }
        
        if let lastInstruction = self.videoComposition!.instructions.last {
            assert(lastInstruction.timeRange.end == firstVideoTrack.timeRange.end)
        }
        
        if let audioTrack = self.composition!.tracks(withMediaType: .audio).first {
            audioMix = AVMutableAudioMix()
            // Create the audio mix input parameters object.
            let mixParameters = AVMutableAudioMixInputParameters(track: audioTrack)
            // Set the volume ramp to slowly fade the audio out over the duration of the composition.
            mixParameters.setVolume(1.f, at: .zero)
            // Attach the input parameters to the audio mix.
            audioMix?.inputParameters = [mixParameters]
        }
        
        let playerItem = AVPlayerItem(asset: self.composition!)
        playerItem.videoComposition = videoComposition
        playerItem.audioMix = audioMix
        
        if let cell = self.tableView.visibleCells.first as? TCPlayViewCell {
            cell.player.replaceCurrentItem(with: playerItem)
        }
        
        self.backgroundTimelineView.reloadData()
    }
    
    private func recordingStopped() {
        _recording = false
        self.recordButton.isEnabled = true
        //        self.recordButton.title = "Record"
        
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
        
        self.view.insertSubview(_previewView!, at: 0)
        var bounds = CGRect.zero
        bounds.size = self.view.convert(self.view.bounds, to: _previewView).size
        _previewView!.bounds = bounds
        _previewView!.center = CGPoint(x: self.view.bounds.size.width/2.0, y: self.view.bounds.size.height/2.0)
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
            self.present(alert, animated: true, completion: nil)
        } else {
            let alertView = UIAlertView(title: error.localizedDescription,
                                        message: message,
                                        delegate: nil,
                                        cancelButtonTitle: "OK")
            alertView.show()
        }
    }
    
    // MARK: - Models
    
    var recordTimeRange = CMTimeRange.zero
    
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    var _currentIdx = 0
    
    let avaliableFilters = CoreImageFilters.avaliableFilters()
    
    var isRecording: Bool = false {
        didSet {
            self.recordButton.isHidden = !isRecording
        }
    }
    
    var liveListMgr: TCLiveListMgr?
    var isLoading: Bool = false
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.lives = []
        liveListMgr = TCLiveListMgr.shared()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(newDataAvailable),
            name: NSNotification.Name(rawValue: kTCLiveListNewDataAvailable),
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(listDataUpdated),
            name: NSNotification.Name(rawValue: kTCLiveListUpdated),
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(svrError),
            name: NSNotification.Name(rawValue: kTCLiveListSvrError),
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playError),
            name: NSNotification.Name(rawValue: kTCLivePlayError),
            object: nil)
    }
    
    
    private var _addedObservers: Bool = false
    private var _recording: Bool = false
    private var _backgroundRecordingID: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: 0)
    private var _allowedToUseGPU: Bool = false
    
    private var _labelTimer: Timer?
    private var _previewView: OpenGLPixelBufferView?
    private var _capturePipeline: RosyWriterCapturePipeline!
    
    @IBOutlet weak var recordButton: UIButton!
    
    var histograms = [(time: CMTime, histogram: [[vImagePixelCount]])]()
    
    var seekTimer: Timer? = nil
    var recordTimer: Timer? = nil
    var visibleTimeRange: CGFloat = 15
    var scaledDurationToWidth: CGFloat {
        return backgroundTimelineView.frame.width / visibleTimeRange
    }
    
    
    // Attempt load and test these asset keys before playing.
    static let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    var currentTime: Double {
        get {
            if let cell = self.tableView.visibleCells.first as? TCPlayViewCell {
                return CMTimeGetSeconds(cell.player.currentTime())
            } else {
                return 0
            }
        }
        set {
            let newTime = CMTimeMakeWithSeconds(newValue, preferredTimescale: 600)
            //todo: more tolerance
            if let cell = self.tableView.visibleCells.first as? TCPlayViewCell {
                cell.player.seek(to: newTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
            }
        }
    }
    
    var duration: Double {
        if let cell = self.tableView.visibleCells.first as? TCPlayViewCell, let currentItem = cell.player.currentItem {
            return CMTimeGetSeconds(currentItem.duration)
        }
        
        return 0.0
    }
    
    var composition: AVMutableComposition? = nil
    var videoComposition: AVMutableVideoComposition? = nil
    var audioMix: AVMutableAudioMix? = nil
    
    /*
     A token obtained from calling `player`'s `addPeriodicTimeObserverForInterval(_:queue:usingBlock:)`
     method.
     */
    
    private var playerItem: AVPlayerItem? = nil
    
    var lives: [TCLiveInfo] = []
        
}

