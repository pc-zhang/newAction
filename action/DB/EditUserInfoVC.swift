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

class EditUserInfoVC : SpinnerViewController, UITextFieldDelegate, UITextViewDelegate {
    
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
                if let imagePath = userCache.avatarURL?.path {
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
    @IBOutlet weak var avatarV: UIImageView! {
        didSet {
            avatarV.layer.cornerRadius = 8
            avatarV.layer.masksToBounds = true
            avatarV.layer.borderColor = #colorLiteral(red: 0.3529411765, green: 0.3450980392, blue: 0.4235294118, alpha: 1)
            avatarV.layer.borderWidth = 1
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
                userCache.changeUserInfo(avatarURL: userCache.avatarURL ?? URL(fileURLWithPath: ""), nickName: nickNameTextField.text ?? "", sex: sexLabel.text ?? "", location: locationTextField.text ?? "", sign: signTextV.text)
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
            actionSheet.addAction(UIAlertAction(title: "拍照", style: .default, handler: nil))
            actionSheet.addAction(UIAlertAction(title: "相册", style: .default, handler: nil))
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
    
}
