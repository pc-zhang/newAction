/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The `UICollectionViewCell` used to represent data in the collection view.
*/

import UIKit
import AVFoundation


final class FollowingViewCell: UITableViewCell {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        playerV.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(type(of: self).tapPlayViewCell(_:))))
        
        playerV.player = player
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
    
    @IBOutlet weak var playerV: PlayerView!
    
    static let reuseIdentifier = "FollowingViewCell"
    var player = AVPlayer()
    var url : URL?
    @IBOutlet weak var avatarV: UIImageView!
    @IBOutlet weak var nickNameV: UILabel!
    @IBOutlet weak var titleV: UILabel!
    @IBOutlet weak var likesAndReviews: UILabel!
    @IBOutlet weak var createTimeV: UILabel!
    
}

