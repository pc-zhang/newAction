/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The `UICollectionViewCell` used to represent data in the collection view.
*/

import UIKit
import AVFoundation

final class MainViewCell: UITableViewCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.playerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(MainViewCell.tapPlayViewCell(_:))))
        
        playerView.player = player
    }
    
    @IBAction func tapPlayViewCell(_ sender: Any) {
        if player.rate == 0 {
            // Not playing forward, so play.
            if player.currentTime() == player.currentItem?.duration {
                // At end, so got back to begining.
                player.seek(to: .zero)
            }
            
            player.play()
        }
        else {
            // Playing, so pause.
            player.pause()
        }
        
    }
    
    // MARK: Properties
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var chorus: UIButton!
    @IBOutlet weak var avatarV: UIImageView!
    @IBOutlet weak var nickNameLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var likesLabel: UILabel!
    @IBOutlet weak var reviewsLabel: UILabel!
    
    static let reuseIdentifier = "TCPlayViewCell"
    var player = AVPlayer()
    var url : URL?
}

