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

class ActionVC: UIViewController, RosyWriterCapturePipelineDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - UI Controls
    
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var playerV: PlayerView!
    @IBOutlet weak var timelineV: UICollectionView!

    //MARK: - UI Actions
    
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
        navigationController?.popViewController(animated: true)
    }
    
    func split(at splitTime: CMTime) {
        guard let firstVideoTrack = self.composition?.tracks(withMediaType: .video).first else {
            return
        }
        
        if let segment = firstVideoTrack.segment(forTrackTime: splitTime), segment.timeMapping.target.containsTime(splitTime) {
            let section = firstVideoTrack.segments.firstIndex(of: segment)
            try! firstVideoTrack.insertTimeRange(segment.timeMapping.target, of: firstVideoTrack, at: segment.timeMapping.target.end)
            firstVideoTrack.removeTimeRange(CMTimeRange(start:splitTime, duration:segment.timeMapping.target.duration + CMTime(value: 1, timescale: 600)))
            
            if let audioTrack = self.composition?.tracks(withMediaType: .audio).first {
                try! audioTrack.insertTimeRange(segment.timeMapping.target, of: audioTrack, at: segment.timeMapping.target.end)
                audioTrack.removeTimeRange(CMTimeRange(start:splitTime, duration:segment.timeMapping.target.duration + CMTime(value: 1, timescale: 600)))
            }
            
            timelineV.performBatchUpdates({
                timelineV.insertSections(IndexSet(integer: section!+1))
                timelineV.reloadSections(IndexSet(integer: section!))
            }, completion: nil)
        }
        
    }
    
    @IBAction func split(_ sender: Any) {
        split(at: CMTime(seconds: 1, preferredTimescale: 600))
    }
    
    @IBAction func export(_ sender: Any) {
        let thumbnail = generateThumbnail()
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
        let firstVideoTrack = composition!.tracks(withMediaType: .video).first!
        exporter.timeRange = firstVideoTrack.timeRange
        // Asynchronously export the composition to a video file and save this file to the camera roll once export completes.
        
        let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0),
                                                   queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: .milliseconds(250))
        timer.setEventHandler {
            DispatchQueue.main.async {
                self.downloadProcess = CGFloat(exporter.progress)
            }
        }
        timer.resume()
        
        exporter.exportAsynchronously {
            timer.cancel()
            DispatchQueue.main.async {
                self.downloadProcess = CGFloat(exporter.progress)
                
                if (exporter.status == .completed) {
                    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(exporter.outputURL!.path)){
                        UISaveVideoAtPathToSavedPhotosAlbum(exporter.outputURL!.path, self, #selector(self.video), nil)
                        
                        let artworkRecord = CKRecord(recordType: "Artwork")
                        artworkRecord["video"] = CKAsset(fileURL: exporter.outputURL!)
                        if let thumbnail = thumbnail {
                            artworkRecord["thumbnail"] = thumbnail
                        }
                        CKContainer.default().publicCloudDatabase.save(artworkRecord) {
                            (record, error) in
                            if let error = error {
                                // Insert error handling
                                return
                            }
                            // Insert successfully saved record code
                        }
                        
                    }
                } else {
                    _ = 1
                }
            }
        }
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
            
            tapPlayView(0)
            Timer.scheduledTimer(withTimeInterval: recordTimeRange.duration.seconds+0.3, repeats: false, block: { (timer) in
                self._capturePipeline.stopRecording()
                self.tapPlayView(0)
            })
            
        }
    }
    
    //MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timelineV.contentInset = UIEdgeInsets(top: 0, left: view.bounds.width/2, bottom: 0, right: view.bounds.width/2)
        timelineV.panGestureRecognizer.addTarget(self, action: #selector(type(of: self).pan))
        
        downloadProgressLayer = CAShapeLayer()
        downloadProgressLayer!.frame = playerV.bounds
        downloadProgressLayer!.position = CGPoint(x:playerV.bounds.width/2, y:playerV.bounds.height/2)
//        playerV.layer.addSublayer(downloadProgressLayer!)
        
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
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .savedPhotosAlbum
            picker.mediaTypes = [kUTTypeMovie as String]
            picker.delegate = self
            picker.allowsEditing = false
            present(picker, animated: true)
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
        if let _timelineView = scrollView as? UICollectionView, player.rate == 0 {
            currentTime = Double((_timelineView.contentOffset.x + _timelineView.bounds.width/2) / _timelineView.bounds.height) * interval
        }
    }
    
    @IBAction func pan(_ recognizer: UIPanGestureRecognizer) {
        player.pause()
        seekTimer?.invalidate()
        isRecording = false
        viewDidLayoutSubviews()
    }
    
    func different(_ prevVisibleTimeRange: Double, _ visibleTimeRange: Double) {

    }
    
    @IBAction func pinch(_ pinchRecognizer: UIPinchGestureRecognizer) {
        let prevInterval = interval
        interval = tmpInterval / Double(pinchRecognizer.scale)
        if interval < 0.04 {
            interval = 0.04
        }
        if interval > composition!.duration.seconds / 5 {
            interval = composition!.duration.seconds / 5
        }
        
        different(prevInterval, interval)

        timelineV.collectionViewLayout.invalidateLayout()
        timelineV.reloadData()
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
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
        let segment = firstVideoTrack.segments[indexPath.section]
        timelineV.contentOffset.x = CGFloat(segment.timeMapping.target.start.seconds / interval) * timelineV.bounds.height - timelineV.bounds.width/2

        recordTimeRange = segment.timeMapping.target
        isRecording = true
        viewDidLayoutSubviews()

        if histograms.index(where: {$0.time == recordTimeRange.start}) != nil {
            _capturePipeline.startRunning()
        }
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
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "thumbnail cell", for: indexPath)
        
        if let thumbnailCell = cell as? ThumbnailCell {
            thumbnailCell.backgroundColor = #colorLiteral(red: 1, green: 0, blue: 0, alpha: 0)
            thumbnailCell.imageV.clipsToBounds = true
            thumbnailCell.imageV.contentMode = .scaleAspectFill
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let thumbnailCell = cell as? ThumbnailCell, let firstVideoTrack = composition?.tracks(withMediaType: AVMediaType.video).first else {
            return
        }
        
        let bias = CMTime(seconds: interval * Double(indexPath.item), preferredTimescale: 600)
        let thumbnailTime = firstVideoTrack.segments[indexPath.section].timeMapping.target.start + bias
        
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
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        guard let firstVideoTrack = composition?.tracks(withMediaType: AVMediaType.video).first else {
            return .zero
        }
        
        let duration = firstVideoTrack.segments[indexPath.section].timeMapping.target.duration.seconds
        
        let cellTimeDuration = duration - interval * Double(indexPath.item)
        if cellTimeDuration < interval {
            let width = CGFloat(cellTimeDuration / interval) * timelineV.bounds.height
            return CGSize(width: width, height: timelineV.bounds.height)
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
            if #available(iOS 10.0, *) {
                seekTimer?.invalidate()
                seekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
                    self.timelineV.contentOffset.x = CGFloat(self.currentTime/self.interval)*self.timelineV.bounds.height - self.timelineV.bounds.width/2
                })
            } else {
                // Fallback on earlier versions
            }
        }
        else {
            // Playing, so pause.
            player.pause()
            seekTimer?.invalidate()
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
        recordButton.setTitle("Stop", for: .normal)
    }
    
    func capturePipelineRecordingWillStop(_ capturePipeline: RosyWriterCapturePipeline) {
        // Disable record button until we are ready to start another recording
        recordButton.isEnabled = false
        recordButton.setTitle("Record", for: .normal)
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
                self.viewDidLayoutSubviews()
            }
        }
    }
    
    func capturePipeline(_ capturePipeline: RosyWriterCapturePipeline, recordingDidFailWithError error: Error) {
        recordingStopped()
        showError(error)
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
                
                compositionVideoTrack?.preferredTransform = videoAssetTrack.preferredTransform
                
                try! compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: newAsset.duration), of: videoAssetTrack, at: CMTime.zero)
                
                if let audioAssetTrack = newAsset.tracks(withMediaType: .audio).first {
                    try! compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: newAsset.duration), of: audioAssetTrack, at: CMTime.zero)
                    
                    assert(compositionAudioTrack?.timeRange == compositionVideoTrack?.timeRange)
                    
                }
                
                self.playerV.player = self.player
                self.playerV.playerLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                
                self.interval = self.composition!.duration.seconds / 5
                // update timeline
                self.updatePlayer()
                
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
                                self.downloadProcess = 0.5 + CGFloat(sampleBufferTime.seconds / self.composition!.duration.seconds)/2
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
                                            self.split(at: sampleBufferTime)
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
        guard composition != nil else {
            return
        }
        
        let firstVideoTrack = composition!.tracks(withMediaType: .video)[0]
        let secondVideoTrack = composition!.tracks(withMediaType: .video)[1]
        
        videoComposition = AVMutableVideoComposition()
        let renderSize = firstVideoTrack.naturalSize.applying(firstVideoTrack.preferredTransform)
        videoComposition!.renderSize = CGSize(width: abs(renderSize.width), height: abs(renderSize.height))
        videoComposition!.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        for segment in firstVideoTrack.segments {
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = segment.timeMapping.target
            
            if let segment2 = secondVideoTrack.segment(forTrackTime: segment.timeMapping.target.start),!segment2.isEmpty, segment2.timeMapping.target ==  segment.timeMapping.target {
                let transformer2 = AVMutableVideoCompositionLayerInstruction(assetTrack: secondVideoTrack)
                
                let renderSize2 = secondVideoTrack.naturalSize.applying(secondVideoTrack.preferredTransform)
                let renderScale = videoComposition!.renderSize.width / renderSize2.width
                let translateY = (renderSize2.height * renderScale - videoComposition!.renderSize.height) / 2
                transformer2.setTransform(secondVideoTrack.preferredTransform.scaledBy(x: renderScale, y: renderScale).concatenating(CGAffineTransform(translationX: 0, y: -translateY)), at: instruction.timeRange.start)
                instruction.layerInstructions = [transformer2]
            } else {
                let transformer1 = AVMutableVideoCompositionLayerInstruction(assetTrack: firstVideoTrack)
                transformer1.setTransform(firstVideoTrack.preferredTransform, at: instruction.timeRange.start)
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
        
        player.replaceCurrentItem(with: playerItem)
        
        timelineV.reloadData()
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
    
    // MARK: - layout
    override func viewDidLayoutSubviews() {
        let safeArea = view.bounds.inset(by: view.safeAreaInsets)
        if isRecording {
            playerV.frame = CGRect(x: 0, y: view.safeAreaInsets.top, width: safeArea.width/3, height: safeArea.height/3)
            playerV.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
            if let width = videoComposition?.renderSize.width, let height = videoComposition?.renderSize.height {
                let scale = safeArea.width / width
                let offsetY = (safeArea.height - height * scale) / 2
                _previewView?.frame = CGRect(x: 0, y: offsetY, width: safeArea.width, height: height * scale)
            }
        } else {
            playerV.frame = safeArea
            playerV.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            _previewView?.frame = safeArea
        }
    }
    
    // MARK: - Models
    
    
    var url: URL?
    
    var player = AVPlayer()
    
    var recordTimeRange = CMTimeRange.zero
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    var _currentIdx = 0
    
    let avaliableFilters = CoreImageFilters.avaliableFilters()
    
    var isRecording: Bool = false {
        didSet {
            recordButton.isHidden = !isRecording
        }
    }
    
    private var _recording: Bool = false
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
    
    /*
     A token obtained from calling `player`'s `addPeriodicTimeObserverForInterval(_:queue:usingBlock:)`
     method.
     */
    
    var downloadProgressLayer: CAShapeLayer?
    var downloadProcess: CGFloat = 0 {
        didSet {
            if downloadProcess != 0 {
                downloadProgressLayer?.fillColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
                downloadProgressLayer?.path = CGPath(rect: playerV.bounds, transform: nil)
                downloadProgressLayer?.borderWidth = 0
                downloadProgressLayer?.lineWidth = 10
                downloadProgressLayer?.strokeColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
                downloadProgressLayer?.strokeStart = 0
                downloadProgressLayer?.strokeEnd = downloadProcess
            } else {
                downloadProgressLayer?.path = nil
            }
        }
    }
}

class ThumbnailCell: UICollectionViewCell {
    @IBOutlet weak var imageV: UIImageView!
}
