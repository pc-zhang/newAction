//
//  UserInfoVC.swift
//  NIM
//
//  Created by zpc on 2018/10/16.
//  Copyright © 2018年 Netease. All rights reserved.
//

import Foundation
import CloudKit
import UIKit
import MobileCoreServices

class EditUserInfoVC : UITableViewController, UITextFieldDelegate, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    lazy var spinner: UIActivityIndicatorView = {
        return UIActivityIndicatorView(style: .gray)
    }()
    
    private var avatarAsset : CKAsset? {
        didSet {
            if let path = avatarAsset?.fileURL.path {
                avatarV.image = UIImage(contentsOfFile: path)
            }
        }
    }
    
    private var littleAvatarAsset : CKAsset?
    
    private lazy var picker : UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.mediaTypes = [kUTTypeImage as String]
        picker.delegate = self
        picker.allowsEditing = true
        return picker
    }()
    
    private var userCacheOrNil: UserLocalCache? {
        return (UIApplication.shared.delegate as? AppDelegate)?.userCacheOrNil
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self, selector: #selector(type(of:self).userCacheDidChange(_:)),
            name: .userCacheDidChange, object: nil)
        view.addSubview(spinner)
        view.bringSubviewToFront(spinner)
        spinner.hidesWhenStopped = true
        spinner.color = .blue
        spinner.center = CGPoint(x: view.frame.size.width / 2,
                                 y: view.frame.size.height / 2)
//        spinner.startAnimating()
        updateUI()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func userCacheDidChange(_ notification: Notification) {
        updateUI()
        
        spinner.stopAnimating()
    }
    
    func updateUI() {
        var imageURL: URL?
        var nickName: String?
        var sex: String?
        var location: String?
        var sign: String?
        
            imageURL = (userCacheOrNil!.myInfoRecord?["avatarImage"] as? CKAsset)?.fileURL
            nickName = userCacheOrNil!.myInfoRecord?["nickName"] as? String
            sex = userCacheOrNil!.myInfoRecord?["sex"] as? String
            location = userCacheOrNil!.myInfoRecord?["location"] as? String
            sign = userCacheOrNil!.myInfoRecord?["sign"] as? String
        
        if let imageURL = imageURL {
            self.avatarAsset = CKAsset(fileURL: imageURL)
        }
        self.nickNameTextField.text = nickName
        self.sexLabel.text = sex
        self.locationTextField.text = location
        self.signTextV.text = sign
        self.textVCharCountLabel.text = "\(self.signTextV.text.count)/120"
    }

    @IBOutlet weak var signTextV: UITextView! 
    @IBOutlet weak var nickNameTextField: UITextField!
    @IBOutlet weak var locationTextField: UITextField!
    @IBOutlet weak var textVCharCountLabel: UILabel!
    
    @IBOutlet weak var sexLabel: UILabel!

    @IBOutlet weak var avatarWrapperV: UIView! {
        didSet {
            avatarWrapperV.layer.cornerRadius = avatarWrapperV.bounds.width / 10
            avatarWrapperV.layer.masksToBounds = true
            avatarWrapperV.layer.borderColor = #colorLiteral(red: 0.3529411765, green: 0.3450980392, blue: 0.4235294118, alpha: 1)
            avatarWrapperV.layer.borderWidth = 1
        }
    }
    
    @IBOutlet weak var avatarV: UIImageView! {
        didSet {
            avatarV.contentMode = .scaleAspectFill
        }
    }
    
    @IBAction func cancel(_ sender: Any) {
        resignAllTextFirstResponder()
        navigationController?.popViewController(animated: true)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        resignAllTextFirstResponder()
        if nickNameTextField.text != "" && locationTextField.text != "" {
            guard let avatarAsset = avatarAsset, let littleAvatarAsset = littleAvatarAsset, let nickName = nickNameTextField?.text, let sex = sexLabel?.text, let location = locationTextField?.text, let sign = signTextV?.text else {
                let alert = UIAlertController(title: "保存失败", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .cancel, handler: nil))
                present(alert, animated: true)
                
                return false
            }
            
            spinner.startAnimating()

            let succeed = userCacheOrNil?.changeUserInfo(avatarAsset: avatarAsset, littleAvatarAsset: littleAvatarAsset, nickName: nickName, sex: sex, location: location, sign: sign)
            
            spinner.stopAnimating()
            
            if let succeed = succeed, succeed == true {
                return true
            }

            let alert = UIAlertController(title: "保存失败", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .cancel, handler: nil))
            present(alert, animated: true)
            
            return false
            
        } else {
            let alert = UIAlertController(title: "昵称和地区不能为空", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .cancel, handler: nil))
            present(alert, animated: true)
            
            return false
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        _ = 1
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        resignAllTextFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        return updatedText.count <= 10
    }
    
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        if text == "\n" {
            resignAllTextFirstResponder()
            return false
        }
        
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        
        let changedText = currentText.replacingCharacters(in: stringRange, with: text)
        
        return changedText.count <= 120
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.textVCharCountLabel.text = "\(signTextV.text.count)/120"
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.row != 1 && indexPath.row != 3 && indexPath.row != 5 {
            resignAllTextFirstResponder()
        }
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.popoverPresentationController?.sourceView = self.tableView.cellForRow(at: indexPath)
        actionSheet.popoverPresentationController?.sourceRect = self.tableView.cellForRow(at: indexPath)?.bounds ?? .zero
        
        if indexPath.row == 0 {
            actionSheet.addAction(UIAlertAction(title: "拍照", style: .default, handler: { (action) in
                self.picker.sourceType = .camera
                self.picker.cameraFlashMode = .off
                self.present(self.picker, animated: true)
            }))
            actionSheet.addAction(UIAlertAction(title: "相册", style: .default, handler: { (action) in
                self.picker.sourceType = .savedPhotosAlbum
                self.present(self.picker, animated: true)
            }))
            actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            
            present(actionSheet, animated: true)
        }
        if indexPath.row == 1 {
            nickNameTextField.becomeFirstResponder()
        }
        if indexPath.row == 2 {
            actionSheet.title = "选择性别"
            actionSheet.addAction(UIAlertAction(title: "男", style: .default, handler: { (action) in
                self.sexLabel.text = action.title
            }))
            actionSheet.addAction(UIAlertAction(title: "女", style: .default, handler: { (action) in
                self.sexLabel.text = action.title
            }))
            actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            
            present(actionSheet, animated: true)
        }
        if indexPath.row == 3 {
            locationTextField.becomeFirstResponder()
        }
        if indexPath.row == 4 {
            signTextV.becomeFirstResponder()
        }
        
        return nil
    }
    
    func resignAllTextFirstResponder() {
        nickNameTextField.resignFirstResponder()
        locationTextField.resignFirstResponder()
        signTextV.resignFirstResponder()
    }
    
    // MARK: UIImagePickerControllerDelegate, UINavigationControllerDelegate
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage, let avatarImageURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(UUID().uuidString).png"), let littleAvatarImageURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(UUID().uuidString).png") {
            
            let avatarImage = image.resize(targetSize: avatarV.bounds.size)
            let littleAvatarImage = image.resize(targetSize: CGSize(width: 50, height: 50))

            FileManager.default.createFile(atPath: avatarImageURL.path, contents: avatarImage.pngData(), attributes: nil)
            FileManager.default.createFile(atPath: littleAvatarImageURL.path, contents: littleAvatarImage.pngData(), attributes: nil)
            DispatchQueue.main.async {
                self.avatarAsset = CKAsset(fileURL: avatarImageURL)
                self.littleAvatarAsset = CKAsset(fileURL: littleAvatarImageURL)
            }
        }

        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
}

extension UIImage {
    func resize(targetSize: CGSize) -> UIImage {
        let size = self.size
        
        let widthRatio  = targetSize.width  / self.size.width
        let heightRatio = targetSize.height / self.size.height
        
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}
