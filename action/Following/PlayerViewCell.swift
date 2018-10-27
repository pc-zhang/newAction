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

final class PlayerViewCell: UICollectionViewCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        playerView.player = player
    }
    
    // MARK: Properties
    static let reuseIdentifier = "PlayerViewCell"
    
    var player = AVPlayer()
    @IBOutlet weak var playerView: PlayerView!
}

