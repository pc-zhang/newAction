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
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        _ = 1
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return true
    }
}
