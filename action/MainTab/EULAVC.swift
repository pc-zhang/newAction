//
//  EULAVC.swift
//  action
//
//  Created by zpc on 2018/12/20.
//  Copyright © 2018 zpc. All rights reserved.
//

import UIKit

class EULAVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func agree(_ sender: Any) {
        UserDefaults.standard.set(true, forKey: "eulaAgreed")

        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
