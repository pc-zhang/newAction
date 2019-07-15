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
    
    @IBOutlet weak var thumbnailDraggableImageV: UIImageView! {
        didSet {
            thumbnailDraggableImageV.layer.cornerRadius = 1
        }
    }
    
    @IBOutlet weak var thumbnailDaggableImageViewWrapper: UIView! {
        didSet {
            thumbnailDaggableImageViewWrapper.layer.cornerRadius = 2
        }
    }
    
    @IBOutlet weak var thumbnailCollectionV: UICollectionView!
    
    @IBOutlet weak var filterCollectionVLeading: NSLayoutConstraint!
    
    @IBOutlet weak var filterDot: UIView! {
        didSet {
            filterDot.layer.cornerRadius = filterDot.bounds.width / 2
        }
    }
    
    @IBOutlet weak var cutDot: UIView! {
        didSet {
            cutDot.layer.cornerRadius = cutDot.bounds.width / 2
        }
    }
    
    @IBOutlet weak var thumbnailDot: UIView! {
        didSet {
            thumbnailDot.layer.cornerRadius = thumbnailDot.bounds.width / 2
        }
    }
    
    @IBOutlet weak var filterLabel: UILabel!
    
    @IBOutlet weak var cutLabel: UILabel!
    
    @IBOutlet weak var thumbnailLabel: UILabel!
    
    @IBAction func changeFilterPage(_ sender: Any) {
        filterLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        cutLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.7)
        thumbnailLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.7)
        filterDot.isHidden = false
        cutDot.isHidden = true
        thumbnailDot.isHidden = true
        
        filterCollectionVLeading.constant = 0
    }
    
    @IBAction func changeCutPage(_ sender: Any) {
        filterLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.7)
        cutLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        thumbnailLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.7)
        filterDot.isHidden = true
        cutDot.isHidden = false
        thumbnailDot.isHidden = true
        
        filterCollectionVLeading.constant = -UIScreen.main.bounds.width

    }
    
    @IBAction func changeThumbnailPage(_ sender: Any) {
        filterLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.7)
        cutLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.7)
        thumbnailLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        filterDot.isHidden = true
        cutDot.isHidden = true
        thumbnailDot.isHidden = false
        
        filterCollectionVLeading.constant = -UIScreen.main.bounds.width * 2

    }
    
    
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
        
        filterCell.filterNameLabel.text = avaliableFiltersName[indexPath.item]
        
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
                        
                        self.thumbnailDraggableImageV.image = self._thumbnail
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
    private let avaliableFiltersName = CoreImageFilters.avaliableFiltersName()
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
    
    private var thumbnailDelegate : ThumbnailDelegate?
    private var thumbnailDataSource : ThumbnailDataSource?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        thumbnailDelegate = ThumbnailDelegate(self)
        thumbnailDataSource = ThumbnailDataSource()
        thumbnailCollectionV.delegate = thumbnailDelegate
        thumbnailCollectionV.dataSource = thumbnailDataSource
        
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

class ThumbnailCell2: UICollectionViewCell {
    @IBOutlet weak var imageV: UIImageView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}

class ThumbnailDelegate : NSObject, UICollectionViewDelegate {
    
    init(_ videoEditVC: VideoEditVC) {
        super.init()
        
        self._videoEditVC = videoEditVC
    }
    
    private weak var _videoEditVC: VideoEditVC?
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let thumbnailCell = cell as? ThumbnailCell2 else {
            return
        }
        
        let imageGenerator = AVAssetImageGenerator.init(asset: _videoEditVC!.composition!)
        imageGenerator.videoComposition = _videoEditVC!.videoComposition
        imageGenerator.maximumSize = CGSize(width: cell.bounds.width, height: cell.bounds.height)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.generateCGImagesAsynchronously(forTimes: [CMTime.zero as NSValue]) { (requestedTime, image, actualTime, result, error) in
            if let image = image {
                DispatchQueue.main.async {
                    thumbnailCell.imageV.image = UIImage(cgImage: image)
                }
            }
        }
        
    }
}

class ThumbnailDataSource : NSObject, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 7
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "thumbnail cell", for: indexPath)
        
        if let thumbnailCell = cell as? ThumbnailCell2 {
            
        }
        
        return cell
    }
    
    
}
