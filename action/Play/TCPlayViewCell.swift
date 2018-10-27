/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The `UICollectionViewCell` used to represent data in the collection view.
*/

import UIKit
import AVFoundation

protocol TCPlayViewCellDelegate: NSObjectProtocol {
    func chorus(url: URL)
    func tapPlayViewCell()
    func funcIsRecording() -> Bool
}

final class TCPlayViewCell: UITableViewCell, URLSessionDownloadDelegate {
    
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
        let backgroundTask = urlSession.downloadTask(with: url!)
        backgroundTask.resume()
    }
    
    // #MARK: - URLSessionDownloadDelegate
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                let backgroundCompletionHandler =
                appDelegate.backgroundCompletionHandler else {
                    return
            }
            backgroundCompletionHandler()
        }
    }
    
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let httpResponse = downloadTask.response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {
                print ("server error")
                return
        }
        do {
            let documentsURL = try
                FileManager.default.url(for: .documentDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: nil,
                                        create: false)
            let savedURL = documentsURL.appendingPathComponent(
                location.lastPathComponent).appendingPathExtension("mp4")
            try FileManager.default.moveItem(at: location, to: savedURL)
            
            delegate?.chorus(url: savedURL)
            
            DispatchQueue.main.async {
                self.downloadProcess = 0.5
            }
        } catch {
            print ("file error: \(error)")
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // println("download task did write data")
        
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            self.downloadProcess = CGFloat(sqrt(progress)/2)
        }
    }
    
    
    // MARK: Properties
    static let reuseIdentifier = "TCPlayViewCell"
    
    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var chorus: UIButton!
    
    var player = AVPlayer()
    var url : URL?
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "MySession")
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
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

