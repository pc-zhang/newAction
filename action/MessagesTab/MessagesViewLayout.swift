// 
//  FSPagerViewLayout.swift
//  FSPagerView
//
//  Created by Wenchao Ding on 20/12/2016.
//  Copyright © 2016 Wenchao Ding. All rights reserved.
//

import UIKit

class MessagesViewLayout: UICollectionViewFlowLayout {
    
    override init() {
        super.init()
        self.commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    deinit {
        
    }
    
    override open var collectionViewContentSize: CGSize {
        let height = CGFloat(collectionView!.numberOfItems(inSection: 0)) * (collectionView!.bounds.height - 2) + 2
        let contentSize = CGSize(width: collectionView!.frame.width, height: height)
        return contentSize
    }
    
    override open func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var layoutAttributes = [UICollectionViewLayoutAttributes]()
        
        let rect = rect.intersection(CGRect(origin: .zero, size: collectionViewContentSize))
        guard !rect.isEmpty else {
            return layoutAttributes
        }
        
        let count = collectionView!.numberOfItems(inSection: 0)
        
        for i in 0..<count {
            if let attributes = layoutAttributesForItem(at: IndexPath(item: i, section: 0)), !rect.intersection(attributes.frame).isEmpty {
                layoutAttributes.append(attributes)
            }
        }
        return layoutAttributes
        
    }
    
    override open func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = super.layoutAttributesForItem(at: indexPath)
        
        let frame = CGRect(x: 0, y: CGFloat(indexPath.row) * (collectionView!.bounds.height - 2)+1, width: collectionView!.bounds.width, height: (collectionView!.bounds.height - 2))
        let center = CGPoint(x: frame.midX, y: frame.midY)
        attributes!.center = center
        attributes!.size = frame.size
        attributes!.frame = frame
        return attributes
    }
    
    override open func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        
        let index = Int((proposedContentOffset.y + collectionView!.bounds.height/2) / (collectionView!.bounds.height - 2))
        let proposedContentOffsetY = CGFloat(index) * (collectionView!.bounds.height - 2)
        let targetContentOffset = CGPoint(x: proposedContentOffset.x, y: proposedContentOffsetY)
        return targetContentOffset
    }
    
    // MARK:- Internal functions
    
//
//    internal func contentOffset(for indexPath: IndexPath) -> CGPoint {
//        let origin = self.frame(for: indexPath).origin
//        guard let collectionView = self.collectionView else {
//            return origin
//        }
//        let contentOffsetX: CGFloat = {
//            if self.scrollDirection == .vertical {
//                return 0
//            }
//            let contentOffsetX = origin.x - (collectionView.frame.width*0.5-self.actualItemSize.width*0.5)
//            return contentOffsetX
//        }()
//        let contentOffsetY: CGFloat = {
//            if self.scrollDirection == .horizontal {
//                return 0
//            }
//            let contentOffsetY = origin.y - (collectionView.frame.height*0.5-self.actualItemSize.height*0.5)
//            return contentOffsetY
//        }()
//        let contentOffset = CGPoint(x: contentOffsetX, y: contentOffsetY)
//        return contentOffset
//    }
    
    
    // MARK:- Private functions
    
    fileprivate func commonInit() {
        scrollDirection = .vertical
    }
    
//    fileprivate func applyTransform(to attributes: FSPagerViewLayoutAttributes, with transformer: FSPagerViewTransformer?) {
//        guard let collectionView = self.collectionView else {
//            return
//        }
//        guard let transformer = transformer else {
//            return
//        }
//        switch self.scrollDirection {
//        case .horizontal:
//            let ruler = collectionView.bounds.midX
//            attributes.position = (attributes.center.x-ruler)/self.itemSpacing
//        case .vertical:
//            let ruler = collectionView.bounds.midY
//            attributes.position = (attributes.center.y-ruler)/self.itemSpacing
//        }
//        attributes.zIndex = Int(self.numberOfItems)-Int(attributes.position)
//        transformer.applyTransform(to: attributes)
//    }

}


