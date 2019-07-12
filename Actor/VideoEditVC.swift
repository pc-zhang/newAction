//
//  VideoEditVC.swift
//  Actor
//
//  Created by zpc on 2019/7/12.
//  Copyright © 2019 zpc. All rights reserved.
//

import UIKit
import Accelerate
import AVFoundation
import CoreServices
import MobileCoreServices

class VideoEditVC: UIViewController {
    
    @IBAction func previous(_ sender: Any) {
        self.navigationController?.popViewController(animated: false)
    }
    
    var composition: AVMutableComposition?
    var videoComposition: AVMutableVideoComposition? = nil
    var audioMix: AVMutableAudioMix? = nil
    
    var firstTrackTransform: CGAffineTransform = CGAffineTransform.identity
    
    @IBOutlet weak var playerV: PlayerView!
    @IBOutlet weak var playImage: UIImageView!
    lazy var player : AVPlayer = {
        return AVPlayer()
    } ()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerV.player = player
        playerV.playerLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        
        player.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions(rawValue: NSKeyValueObservingOptions.new.rawValue | NSKeyValueObservingOptions.old.rawValue), context: nil)
        
        updatePlayer()
        player.play()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(type(of: self).playerDidFinishPlaying(note:)),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        _ = 1
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return true
    }
    
    func updatePlayer() {
        guard composition != nil else {
            return
        }
        
        let firstVideoTrack = composition!.tracks(withMediaType: .video)[0]
        
        videoComposition?.instructions = []
        videoComposition?.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        for segment in firstVideoTrack.segments {
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = segment.timeMapping.target
            
            let transformer1 = AVMutableVideoCompositionLayerInstruction(assetTrack: firstVideoTrack)
            transformer1.setTransform(firstTrackTransform, at: instruction.timeRange.start)
            
            instruction.layerInstructions = [transformer1]
            
            videoComposition?.instructions.append(instruction)
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
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            if player.rate == 1  {
                playImage.isHidden = true
            }else{
                playImage.isHidden = false
            }
        }
    }
    
    @objc func playerDidFinishPlaying(note: NSNotification) {
        
        player.seek(to: .zero)
        player.play()
        
    }
    
    @IBAction func tapPlayView(_ sender: Any) {
        if player.rate == 0 {
            
            player.play()
            
//            seekTimer?.invalidate()
//            seekTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
//                self.timelineV.contentOffset.x = CGFloat(self.currentTime/self.interval)*self.timelineV.bounds.height - self.timelineV.bounds.width/2
//            })
        }
        else {
            // Playing, so pause.
            player.pause()
//            seekTimer?.invalidate()
        }
    }
}
