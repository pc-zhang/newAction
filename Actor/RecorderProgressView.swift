//
//  RecorderProgressView.swift
//  Actor
//
//  Created by zpc on 2019/7/15.
//  Copyright © 2019 zpc. All rights reserved.
//

import UIKit

@objc(RecorderProgressViewDelegate)
protocol RecorderProgressViewDelegate: NSObjectProtocol {
    
    func getPositions(_ recorderProgressView: RecorderProgressView) -> [CGFloat]
    
}

class RecorderProgressView: UIView {
    
    weak var delegate: RecorderProgressViewDelegate?

    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
        
        super.draw(rect)
        
        if let positions = delegate?.getPositions(self), let context = UIGraphicsGetCurrentContext() {
            context.setStrokeColor(UIColor.black.cgColor)
            context.setLineWidth(2)
            
            for position in positions {
                context.move(to: CGPoint(x: position * self.bounds.width, y: 0))
                context.addLine(to: CGPoint(x: position * self.bounds.width, y: bounds.height))
                context.strokePath()
            }
        }
    }

}
