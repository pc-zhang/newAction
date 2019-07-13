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
import MobileCoreServices

class RecorderVC: UIViewController, RosyWriterCapturePipelineDelegate {
    
    override func viewDidLayoutSubviews() {
        if !_recording && (composition?.tracks(withMediaType: .video).first?.timeRange.duration == .zero || composition!.tracks(withMediaType: .video).first!.timeRange.duration.isValid == false) {
            deleteButton.isHidden = true
            recordProgressView.isHidden = true
            recordedSecondsWrapper.isHidden = true
            recordedSecondsLabel.isHidden = true
            recordProgressBar.isHidden = true
        } else {
            deleteButton.isHidden = false
            recordProgressView.isHidden = false
            recordedSecondsWrapper.isHidden = false
            recordedSecondsLabel.isHidden = false
            recordProgressBar.isHidden = false
        }
    }
    
    @IBOutlet weak var nextButton: UIButton! {
        didSet {
            nextButton.layer.cornerRadius = 14
        }
    }
    
    @IBOutlet weak var recordProgressBar: UIView!
    
    @IBOutlet weak var recordProgressView: UIProgressView!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var recordedSecondsLabel: UILabel!
    @IBOutlet weak var recordedSecondsWrapper: UIView!
    private var _recording: Bool = false
    @IBOutlet weak var recordButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var recordButton: UIButton!
    
    @IBOutlet weak var recordWhiteCircle: UIView! {
        didSet {
            recordWhiteCircle.layer.cornerRadius = recordWhiteCircle.bounds.width / 2
        }
    }
    @IBOutlet weak var recordWhiteCircleInner: UIView! {
        didSet {
            recordWhiteCircleInner.layer.cornerRadius = recordWhiteCircleInner.bounds.width / 2
        }
    }
    @IBOutlet weak var recordRedCircle: UIView! { didSet {
            recordRedCircle.layer.cornerRadius = recordRedCircle.bounds.width / 2
        }
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
            
            recordButton.isEnabled = false // re-enabled once recording has finished starting
            
            _capturePipeline.startRecording()
            
            _recording = true
        }
        
        self.viewDidLayoutSubviews()
    }
    
    private var _backgroundRecordingID: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: 0)
    private var _allowedToUseGPU: Bool = false
    private var _previewView: OpenGLPixelBufferView? = nil
    @IBOutlet weak var _previewWrapperView: UIView!
    
    private var _capturePipeline: RosyWriterCapturePipeline!
    
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
    
    //MARK: - View lifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        _capturePipeline.startRunning(0)
        
        if _previewView == nil {
            setupPreviewView()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        _capturePipeline.stopRunning()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
    
    private var recordTimer : Timer?
    
    // Recording
    func capturePipelineRecordingDidStart(_ capturePipeline: RosyWriterCapturePipeline) {
        recordButton.isEnabled = true
        
        UIView.animate(withDuration: 0.3) {
            self.recordButtonWidthConstraint.constant = 30
            self.recordRedCircle.layer.cornerRadius = 4
            self.view.layoutIfNeeded()
        }
        
        recordTimer?.invalidate()
        let currentDuration = self.composition!.tracks(withMediaType: .video).first!.timeRange.duration
        if currentDuration.isValid {
            self.recordProgressView.progress = Float(currentDuration.seconds / 60.0)
        } else {
            self.recordProgressView.progress = 0
        }
        recordTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true ) { (timer) in
            self.recordProgressView.progress += 1 / 600.0
            self.recordedSecondsLabel.text = String(format: "%.1fs", self.recordProgressView.progress * 60)
        }
    }
    
    func capturePipelineRecordingWillStop(_ capturePipeline: RosyWriterCapturePipeline) {
        // Disable record button until we are ready to start another recording
        recordButton.isEnabled = false
        
        UIView.animate(withDuration: 0.3) {
            self.recordButtonWidthConstraint.constant = 68
            self.recordRedCircle.layer.cornerRadius = 34
            self.view.layoutIfNeeded()
        }
        
        recordTimer?.invalidate()
    }
    
    @IBAction func deleteLast(_ sender: Any) {
        if stack.isEmpty {
            viewDidLayoutSubviews()
            return
        }
        
        stack.removeLast()
        if stack.isEmpty {
            composition = {
                let _composition = AVMutableComposition()
                // Add two video tracks and two audio tracks.
                _ = _composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
                
                _ = _composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                
                return _composition
            } ()
        } else {
            composition = stack.last!.mutableCopy() as! AVMutableComposition
        }
        
        let currentDuration = self.composition!.tracks(withMediaType: .video).first!.timeRange.duration
        if currentDuration.isValid {
            self.recordProgressView.progress = Float(currentDuration.seconds / 60.0)
        } else {
            self.recordProgressView.progress = 0
        }

        viewDidLayoutSubviews()
    }
    
    // Attempt load and test these asset keys before playing.
    static let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    
    lazy var composition: AVMutableComposition? = {
        let _composition = AVMutableComposition()
        // Add two video tracks and two audio tracks.
        _ = _composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        _ = _composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        return _composition
    } ()
    
    var videoCompositionRenderSize : CGSize = .zero
    
    func capturePipelineRecordingDidStop(_ capturePipeline: RosyWriterCapturePipeline) {
        
        recordingStopped()
        
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
                    
                    let videoTrack = self.composition!.tracks(withMediaType: .video).first!
                    
                    try! videoTrack.insertTimeRange(videoAssetTrack.timeRange, of: videoAssetTrack, at: videoTrack.timeRange.end)
                    
                    let renderSize = videoAssetTrack.naturalSize.applying(videoAssetTrack.preferredTransform)
                    self.videoCompositionRenderSize = CGSize(width: abs(renderSize.width), height: abs(renderSize.width) * 4.0/3.0)
                    
                    videoTrack.preferredTransform = videoAssetTrack.getTransform(renderSize: self.videoCompositionRenderSize)
                }
                
                if let audioAssetTrack = newAsset.tracks(withMediaType: .audio).first {
                    let audioTrack = self.composition!.tracks(withMediaType: .audio).first!
                    
                    try! audioTrack.insertTimeRange(audioAssetTrack.timeRange, of: audioAssetTrack, at:audioTrack.timeRange.end)
                }
                
                self.push()
            }
        }
        
    }
    
    var stack: [AVMutableComposition] = []
    
    func push() {
        let newComposition = composition!.mutableCopy() as! AVMutableComposition
        
        stack.append(newComposition)
        print(composition?.tracks(withMediaType: .video).first?.timeRange.duration.seconds)
    }
    
    func capturePipeline(_ capturePipeline: RosyWriterCapturePipeline, recordingDidFailWithError error: Error) {
        recordingStopped()
        showError(error)
    }
    
    
    private func recordingStopped() {
        _recording = false
        recordButton.isEnabled = true
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
        
        _previewWrapperView.insertSubview(_previewView!, at: 0)
        _previewView!.frame = _previewWrapperView.bounds
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
    
    @IBAction func done(bySegue: UIStoryboardSegue) {
        if bySegue.identifier == "" {
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "recorder to editor" {
            if let editorVC = segue.destination as? VideoEditVC {
                editorVC.composition = composition!.mutableCopy() as! AVMutableComposition
                editorVC.videoCompositionRenderSize = videoCompositionRenderSize
            }
        }
    }
}
