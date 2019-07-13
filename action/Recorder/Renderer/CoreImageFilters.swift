//
//  CoreImageFilters.swift
//  FilterShop
//
//  Created by Xue Yu on 9/17/17.
//  Copyright © 2017 XueYu. All rights reserved.
//

import CoreImage

/// This struct provide all the avliable Filters from CoreImage
struct CoreImageFilters {
    
    /**
      return all avaliable filters names as array of String
    */
    static func avaliableFilters() -> [String] {
        
        var avaliableFilters = ["CIPhotoEffectChrome",
                                "CIPhotoEffectFade",
                                "CIPhotoEffectInstant",
                                "CIPhotoEffectMono",
                                "CIPhotoEffectNoir",
                                "CIPhotoEffectProcess",
                                "CIPhotoEffectTonal",
                                "CIPhotoEffectTransfer"]
        
        return avaliableFilters
    }
    
    static func avaliableFiltersName() -> [String] {
        
        var avaliableFiltersName = ["橘子汽水",
                                "神仙高光",
                                "蜜桃少女",
                                "朝阳",
                                "海蓝",
                                "黑白",
                                "经典",
                                "巴厘岛"]
        
        return avaliableFiltersName
    }
}
