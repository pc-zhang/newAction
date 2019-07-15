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

class VideoEditVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var thumbnailDraggableImagePositionX: NSLayoutConstraint!
    
    @IBAction func dragThumbnail(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self.view)
        thumbnailDraggableImagePositionX.constant += translation.x
        if thumbnailDraggableImagePositionX.constant < 20 {
            thumbnailDraggableImagePositionX.constant = 20
        } else if thumbnailDraggableImagePositionX.constant > UIScreen.main.bounds.width - 20 - 59 {
            thumbnailDraggableImagePositionX.constant = UIScreen.main.bounds.width - 20 - 59
        }
        recognizer.setTranslation(.zero, in: self.view)
        
        let position = Double(thumbnailDraggableImagePositionX.constant - 20) / Double(thumbnailCollectionV.bounds.width - thumbnailCollectionV.contentInset.left - thumbnailCollectionV.contentInset.right)
        let seekTime = CMTime(seconds: position * composition!.duration.seconds , preferredTimescale: 60)
        player.pause()
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
        
        let imageGenerator = AVAssetImageGenerator.init(asset: composition!)
        imageGenerator.videoComposition = videoComposition!
        imageGenerator.maximumSize = CGSize(width: thumbnailCollectionV.bounds.height, height: thumbnailCollectionV.bounds.height)
        imageGenerator.appliesPreferredTrackTransform = true
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: [seekTime as NSValue]) { (requestedTime, image, actualTime, result, error) in
            if let image = image {
                DispatchQueue.main.async {
                    self.thumbnailDraggableImageV.image = UIImage(cgImage: image)
                }
            }
        }
    }
    
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
        
        player.pause()
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        
        let imageGenerator = AVAssetImageGenerator.init(asset: composition!)
        imageGenerator.videoComposition = videoComposition!
        imageGenerator.maximumSize = CGSize(width: thumbnailCollectionV.bounds.height, height: thumbnailCollectionV.bounds.height)
        imageGenerator.appliesPreferredTrackTransform = true
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: [CMTime.zero as NSValue]) { (requestedTime, image, actualTime, result, error) in
            if let image = image {
                DispatchQueue.main.async {
                    self.thumbnailDraggableImageV.image = UIImage(cgImage: image)
                }
            }
        }
        
        filterCollectionVLeading.constant = -UIScreen.main.bounds.width * 2
        thumbnailDraggableImagePositionX.constant = 20
        thumbnailCollectionV.reloadData()
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
        player.play()
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
        thumbnailDataSource = ThumbnailDataSource(self)
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
    
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
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
            if player.rate == 1 || thumbnailDot.isHidden == false {
                playImage.isHidden = true
            } else {
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

class ThumbnailDelegate : NSObject, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    init(_ videoEditVC: VideoEditVC) {
        super.init()
        
        self._videoEditVC = videoEditVC
    }
    
    private weak var _videoEditVC: VideoEditVC!
    
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//
//        let width = _videoEditVC.thumbnailCollectionV.bounds.width - _videoEditVC.thumbnailCollectionV.contentInset.left - _videoEditVC.thumbnailCollectionV.contentInset.right
//        let itemWidthNormalized = Double(_videoEditVC.thumbnailCollectionV.bounds.height / width)
//        let positionXNormalized = Double(indexPath.item) * itemWidthNormalized
//
//        if positionXNormalized + itemWidthNormalized > 1 {
//            return CGSize(width: CGFloat(1 - positionXNormalized) * width, height: collectionView.bounds.height)
//        }
//
//        return CGSize(width: collectionView.bounds.height, height: collectionView.bounds.height)
//    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let thumbnailCell = cell as? ThumbnailCell2 else {
            return
        }
        
        
        let width = _videoEditVC.thumbnailCollectionV.bounds.width - _videoEditVC.thumbnailCollectionV.contentInset.left - _videoEditVC.thumbnailCollectionV.contentInset.right
        let itemWidthNormalized = Double(_videoEditVC.thumbnailCollectionV.bounds.height / width)
        let positionXNormalized = Double(indexPath.item) * itemWidthNormalized

        let seekTime = CMTime(seconds: positionXNormalized * _videoEditVC.composition!.duration.seconds, preferredTimescale: 60)
        
        let imageGenerator = AVAssetImageGenerator.init(asset: _videoEditVC.composition!)
        imageGenerator.videoComposition = _videoEditVC.videoComposition
        imageGenerator.maximumSize = CGSize(width: cell.bounds.width, height: cell.bounds.height)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.generateCGImagesAsynchronously(forTimes: [seekTime as NSValue]) { (requestedTime, image, actualTime, result, error) in
            if let image = image {
                DispatchQueue.main.async {
                    thumbnailCell.imageV.image = UIImage(cgImage: image)
                }
            }
        }
        
    }
}

class ThumbnailDataSource : NSObject, UICollectionViewDataSource {
    
    init(_ videoEditVC: VideoEditVC) {
        super.init()
        
        self._videoEditVC = videoEditVC
    }
    
    private weak var _videoEditVC: VideoEditVC!
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        let numberOfItems = (_videoEditVC.thumbnailCollectionV.bounds.width - _videoEditVC.thumbnailCollectionV.contentInset.left - _videoEditVC.thumbnailCollectionV.contentInset.right) / _videoEditVC.thumbnailCollectionV.bounds.height
        
        return Int(floor(numberOfItems))
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "thumbnail cell", for: indexPath)
        
        if let thumbnailCell = cell as? ThumbnailCell2 {
            
        }
        
        return cell
    }
    
    
}
