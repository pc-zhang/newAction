//
//  RootViewController.swift
//  page
//
//  Created by zpc on 2019/7/10.
//  Copyright © 2019 zpc. All rights reserved.
//

import UIKit

class PageViewController: UIPageViewController, UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    private(set) lazy var orderedViewControllers: [UIViewController] = {
        return [UIStoryboard(name: "Main", bundle: nil) .
            instantiateViewController(withIdentifier: "release_video_1"),
                UIStoryboard(name: "Main", bundle: nil) .
                    instantiateViewController(withIdentifier: "release_video_2"),
                UIStoryboard(name: "Main", bundle: nil) .
                    instantiateViewController(withIdentifier: "release_video_3"),
                UIStoryboard(name: "Main", bundle: nil) .
                    instantiateViewController(withIdentifier: "release_video_4"),
                UIStoryboard(name: "Main", bundle: nil) .
                    instantiateViewController(withIdentifier: "release_video_5")]
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self
        self.dataSource = self

        let viewControllers = [orderedViewControllers.first!]
        self.setViewControllers(viewControllers, direction: .forward, animated: false, completion: {done in })
    }

    // MARK: - UIPageViewController delegate methods

    // MARK: - Page View Controller Data Source
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.index(of: viewController) else {
            return nil
        }
        
        let previousIndex = viewControllerIndex - 1
        
        guard previousIndex >= 0 else {
            return nil
        }
        
        guard orderedViewControllers.count > previousIndex else {
            return nil
        }
        
        return orderedViewControllers[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.index(of: viewController) else {
            return nil
        }
        
        let nextIndex = viewControllerIndex + 1
        let orderedViewControllersCount = orderedViewControllers.count
        
        guard orderedViewControllersCount != nextIndex else {
            return nil
        }
        
        guard orderedViewControllersCount > nextIndex else {
            return nil
        }
        
        return orderedViewControllers[nextIndex]
    }
}

