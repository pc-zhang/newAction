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

class EditUserInfoVC : SpinnerViewController, UITextFieldDelegate, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    private var avatarURL : URL? {
        didSet {
            if let path = avatarURL?.path {
                avatarV.image = UIImage(contentsOfFile: path)
            }
        }
    }
    
    private lazy var picker : UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.sourceType = .savedPhotosAlbum
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
        spinner.startAnimating()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func userCacheDidChange(_ notification: Notification) {
        
        if let userCache = userCacheOrNil {
            userCache.performReaderBlockAndWait {
                if let imagePath = userCache.avatarImage?.fileURL.path {
                    let advTimeGif = UIImage(contentsOfFile: imagePath)
                    self.avatarV.image = advTimeGif
                }
                
                self.nickNameTextField.text = userCache.nickName
                self.sexLabel.text = userCache.sex
                self.locationTextField.text = userCache.location
                self.signTextV.text = userCache.sign
                self.textVCharCountLabel.text = "\(self.signTextV.text.count)/120"
            }
            
        }
        
        spinner.stopAnimating()
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
        presentingViewController?.dismiss(animated: true, completion: {})
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        resignAllTextFirstResponder()
        if nickNameTextField.text != "" && locationTextField.text != "" {
            if let userCache = userCacheOrNil {
                userCache.changeUserInfo(avatarURL: avatarURL ?? URL(fileURLWithPath: ""), nickName: nickNameTextField.text ?? "", sex: sexLabel.text ?? "", location: locationTextField.text ?? "", sign: signTextV.text)
                spinner.startAnimating()
            }
            return true
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
        
        if indexPath.row == 0 {
            let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            actionSheet.addAction(UIAlertAction(title: "拍照", style: .default, handler: { (action) in
                self.picker.sourceType = .camera
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
            let actionSheet = UIAlertController(title: "选择性别", message: nil, preferredStyle: .actionSheet)
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
        
        if let imageURL = info[UIImagePickerController.InfoKey.imageURL] as? URL {
            DispatchQueue.main.async {
                self.avatarURL = imageURL
            }
        } else if let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
            if let imageURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("\(UUID().uuidString).png") {
                FileManager.default.createFile(atPath: imageURL.path, contents: image.pngData(), attributes: nil)
                DispatchQueue.main.async {
                    self.avatarURL = imageURL
                }
            }
        }

        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
}
