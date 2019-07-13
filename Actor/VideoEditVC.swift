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

class VideoEditVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    
    @IBOutlet weak var filterCollectionV: UICollectionView!
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: collectionView.bounds.height * 3 / 4.0, height: collectionView.bounds.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return avaliableFilters.count
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "filter cell", for: indexPath)
        
        if let filterCell = cell as? FilterCell {
            
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let filterCell = cell as? FilterCell else {
            return
        }
        
        if indexPath.item == selectedFilterIndex {
            filterCell.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.3)
        } else {
            filterCell.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
        }
        
        filterCell.filterNameLabel.text = avaliableFilters[indexPath.item]
        
        if _thumbnail == nil {
            _thumbnail = UIImage()
            let imageGenerator = AVAssetImageGenerator.init(asset: composition!)
            imageGenerator.maximumSize = CGSize(width: cell.bounds.width, height: cell.bounds.height)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.generateCGImagesAsynchronously(forTimes: [CMTime.zero as NSValue]) { (requestedTime, image, actualTime, result, error) in
                if let image = image {
                    DispatchQueue.main.async {
                        self._thumbnail = UIImage.init(cgImage: image)
                        self.filterCollectionV.reloadData()
                    }
                }
            }
        }
        
        let sourceImage = CIImage(image: _thumbnail!)
        if indexPath.item < avaliableFilters.count, let newFilter = CIFilter(name: avaliableFilters[indexPath.item]) {
            newFilter.setValue(sourceImage, forKey: kCIInputImageKey)
            if let filteredImage = newFilter.value(forKey: kCIOutputImageKey) as! CIImage? {
                filterCell.imageV.image = UIImage(ciImage: filteredImage)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if selectedFilterIndex == indexPath.item {
            selectedFilterIndex = -1
            _filter = nil
        } else {
            selectedFilterIndex = indexPath.item
            _filter = CIFilter(name: self.avaliableFilters[indexPath.item])
        }
        
        collectionView.reloadData()
    }
    
    private var _thumbnail : UIImage?
    private let avaliableFilters = CoreImageFilters.avaliableFilters()
    private var selectedFilterIndex: Int = -1
    
    @IBAction func previous(_ sender: Any) {
        self.navigationController?.popViewController(animated: false)
    }
    
    var composition: AVMutableComposition?
    var videoComposition: AVMutableVideoComposition? = nil
    var audioMix: AVMutableAudioMix? = nil
    
    var _filter: CIFilter? = nil
    var videoCompositionRenderSize: CGSize = .zero
    
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
        
        videoComposition = AVMutableVideoComposition(asset: composition!, applyingCIFiltersWithHandler: { (request) in
            
            self._filter?.setValue(request.sourceImage, forKey: kCIInputImageKey)
            let filteredImage = self._filter?.value(forKey: kCIOutputImageKey) as! CIImage?
            
            request.finish(with: filteredImage ?? request.sourceImage, context: nil)
        })
        videoComposition?.frameDuration = CMTimeMake(value: 1, timescale: 30)
        videoComposition?.renderSize = videoCompositionRenderSize
        
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

class FilterCell: UICollectionViewCell {
    @IBOutlet weak var imageV: UIImageView! {
        didSet {
            imageV.layer.cornerRadius = 10
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.layer.cornerRadius = 10
    }
    
    @IBOutlet weak var filterNameLabel: UILabel!
    
}
