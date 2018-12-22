//
//  TimelineLayout.swift
//  action
//
//  Created by zpc on 2018/11/23.
//  Copyright © 2018 zpc. All rights reserved.
//

import UIKit

class TimelineLayout: UICollectionViewFlowLayout {
    override var collectionViewContentSize: CGSize {
        return CGSize(width: collectionView!.bounds.width, height: collectionView!.bounds.height)
    }
}
