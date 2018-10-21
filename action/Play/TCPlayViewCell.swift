/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The `UICollectionViewCell` used to represent data in the collection view.
*/

import UIKit
import Foundation
import AVFoundation
import MobileCoreServices
import Accelerate
import Photos

protocol TCPlayViewCellDelegate: NSObjectProtocol {
    func chorus(process processHandler: ((CGFloat) -> Void)!)
    func tapPlayViewCell()
    func funcIsRecording() -> Bool
}

final class TCPlayViewCell: UITableViewCell {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.playerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(TCPlayViewCell.tapPlayViewCell(_:))))
        downloadProgressLayer = CAShapeLayer()
        downloadProgressLayer!.frame = layer.bounds
        downloadProgressLayer!.position = CGPoint(x:bounds.width/2, y:bounds.height/2)
        self.layer.addSublayer(downloadProgressLayer!)
        playerView.player = player
    }
    
    override func layoutSubviews() {
        if delegate?.funcIsRecording() ?? false {
            playerView.frame = CGRect(x: 0, y: 0, width: bounds.width/3, height: bounds.height/3)
            playerView.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
        } else {
            playerView.frame = bounds
            playerView.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        }
    }
    
    @IBAction func tapPlayViewCell(_ sender: Any) {
        delegate?.tapPlayViewCell()
    }

    @IBAction func clickChorus(_ button: UIButton) {
        chorus.isHidden = true
        delegate?.chorus(process: { (process) in
            self.downloadProcess = sqrt(process)/2
        })
    }
    
    // MARK: Properties
    static let reuseIdentifier = "TCPlayViewCell"
    
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var chorus: UIButton!
    
    var player = AVPlayer()
    
    var delegate: TCPlayViewCellDelegate?
    var downloadProgressLayer: CAShapeLayer?
    var downloadProcess: CGFloat = 0 {
        didSet {
            if downloadProcess != 0 {
                self.downloadProgressLayer?.fillColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
                self.downloadProgressLayer?.path = CGPath(rect: bounds, transform: nil)
                self.downloadProgressLayer?.borderWidth = 0
                self.downloadProgressLayer?.lineWidth = 10
                self.downloadProgressLayer?.strokeColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
                self.downloadProgressLayer?.strokeStart = 0
                self.downloadProgressLayer?.strokeEnd = downloadProcess
            } else {
                self.downloadProgressLayer?.path = nil
            }
        }
    }
}

