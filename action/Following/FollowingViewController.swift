//
//  TCVodPlayViewController.swift
//  TXXiaoShiPinDemo
//
//  Created by zpc on 2018/9/24.
//  Copyright © 2018年 tencent. All rights reserved.
//


import UIKit
import AVFoundation

class FollowingViewController: UIViewController, FSPagerViewDataSource,FSPagerViewDelegate {
    
    // MARK: - Models
    
    var liveListMgr: TCLiveListMgr?
    var isLoading: Bool = false
    var lives: [TCLiveInfo] = []
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.lives = []
        liveListMgr = TCLiveListMgr.shared()
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(newDataAvailable),
//            name: NSNotification.Name(rawValue: kTCLiveListNewDataAvailable),
//            object: nil)
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(listDataUpdated),
//            name: NSNotification.Name(rawValue: kTCLiveListUpdated),
//            object: nil)
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(svrError),
//            name: NSNotification.Name(rawValue: kTCLiveListSvrError),
//            object: nil)
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(playError),
//            name: NSNotification.Name(rawValue: kTCLivePlayError),
//            object: nil)
    }
    
    // MARK: - ViewController Life Cycles
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        liveListMgr?.queryVideoList(.up)
    }
    
    
    // MARK: Net fetch
    /**
     * 拉取直播列表。TCLiveListMgr在启动是，会将所有数据下载下来。在未全部下载完前，通过loadLives借口，
     * 能取到部分数据。通过finish接口，判断是否已取到最后的数据
     *
     */
    func doFetchList() {
        let range = NSMakeRange(self.lives.count, 20)
        
        var finish: ObjCBool = false
        var result = liveListMgr?.readVods(range, finish: &finish)
        
        if result != nil {
            result = mergeResult(result: result! as! [TCLiveInfo])
            self.lives.append(contentsOf: result! as! [TCLiveInfo])
        } else {
            if finish.boolValue {
//                let hud = HUDHelper.sharedInstance()?.tipMessage("没有啦")
//                hud?.isUserInteractionEnabled = false
            }
        }
    }
    
    /**
     *  将取到的数据于已存在的数据进行合并。
     *
     *  @param result 新拉取到的数据
     *
     *  @return 新数据去除已存在记录后，剩余的数据
     */
    func mergeResult(result: [TCLiveInfo]) -> [TCLiveInfo] {
        // 每个直播的播放地址不同，通过其进行去重处理
        let existArray = self.lives.map { (obj) -> String in
            obj.playurl
        }
        
        let newArray = result.filter { (obj) -> Bool in
            !existArray.contains(obj.playurl)
        }
        
        return newArray
    }
    
    /**
     *  TCLiveListMgr有新数据过来
     *
     *  @param noti
     */
    @objc func newDataAvailable(noti: NSNotification) {
        doFetchList()
        pagerView.reloadData()
    }
    
    /**
     *  TCLiveListMgr数据有更新
     *
     *  @param noti
     */
    @objc func listDataUpdated(noti: NSNotification) {
        //    [self setup];
    }
    
    
    /**
     *  TCLiveListMgr内部出错
     *
     *  @param noti
     */
    @objc func svrError(noti: NSNotification) {
        let e = noti.object
        if ((e as? NSError) != nil) {
//            HUDHelper.alert(e.debugDescription)
        }
        
        // 如果还在加载，停止加载动画
        if self.isLoading {
            self.isLoading = false
        }
    }
    
    /**
     *  TCPlayViewController出错，加入房间失败
     *
     */
    @objc func playError(noti: NSNotification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(0.5), execute: {
            //        [self.tableView.mj_header beginRefreshing];
            //加房间失败后，刷新列表，不需要刷新动画
            self.lives = []
            self.isLoading = true
            self.liveListMgr?.queryVideoList(.up)
        })
    }
    
    
    fileprivate let imageNames = ["1.jpg","2.jpg","3.jpg","4.jpg","5.jpg","6.jpg","7.jpg"]
    fileprivate let transformerNames = ["coverflow"]
    fileprivate let transformerTypes: [FSPagerViewTransformerType] = [.coverFlow]
    fileprivate var typeIndex = 0 {
        didSet {
            let type = self.transformerTypes[typeIndex]
            self.pagerView.transformer = FSPagerViewTransformer(type:type)
            switch type {
            case .crossFading, .zoomOut, .depth:
                self.pagerView.itemSize = FSPagerView.automaticSize
                self.pagerView.decelerationDistance = 1
            case .linear, .overlap:
                let transform = CGAffineTransform(scaleX: 0.6, y: 0.75)
                self.pagerView.itemSize = self.pagerView.frame.size.applying(transform)
                self.pagerView.decelerationDistance = FSPagerView.automaticDistance
            case .ferrisWheel, .invertedFerrisWheel:
                self.pagerView.itemSize = CGSize(width: 180, height: 140)
                self.pagerView.decelerationDistance = FSPagerView.automaticDistance
            case .coverFlow:
                self.pagerView.itemSize = CGSize(width: pagerView.bounds.width / 2.3, height: pagerView.bounds.width / 2.3 * 16.0 / 9.0)
                self.pagerView.decelerationDistance = FSPagerView.automaticDistance
            case .cubic:
                let transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                self.pagerView.itemSize = self.pagerView.frame.size.applying(transform)
                self.pagerView.decelerationDistance = 1
            }
        }
    }
    
    @IBOutlet weak var pagerView: FSPagerView! {
        didSet {
            self.pagerView.register(FSPagerViewCell.self, forCellWithReuseIdentifier: "cell")
            self.typeIndex = 0
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let index = self.typeIndex
        self.typeIndex = index // Manually trigger didSet
    }
    
    // MARK:- FSPagerViewDataSource
    
    public func numberOfItems(in pagerView: FSPagerView) -> Int {
        return lives.count
    }
    
    public func pagerView(_ pagerView: FSPagerView, cellForItemAt index: Int) -> FSPagerViewCell {
        let cell = pagerView.dequeueReusableCell(withReuseIdentifier: "cell", at: index)
        return cell
    }
    
    func pagerView(_ pagerView: FSPagerView, didSelectItemAt index: Int) {
        pagerView.deselectItem(at: index, animated: true)
        pagerView.scrollToItem(at: index, animated: true)
    }
    
    func pagerView(_ pagerView: FSPagerView, willDisplay cell: FSPagerViewCell, forItemAt index: Int) {
        
        if index < lives.count {
            let liveInfo = lives[index]
            let playerItem = AVPlayerItem(url: URL(string: liveInfo.playurl)!)
            cell.player.replaceCurrentItem(with: playerItem)
            cell.player.seek(to: .zero)
        }
    }
    
    func pagerView(_ pagerView: FSPagerView, didEndDisplaying cell: FSPagerViewCell, forItemAt index: Int) {
        
        cell.player.pause()
        cell.player.replaceCurrentItem(with: nil)
    }
    
    func pagerViewDidEndDecelerating(_ pagerView: FSPagerView) {
        if let cell = pagerView.collectionView.visibleCells[1] as? FSPagerViewCell {
            cell.player.play()
        }
        if let cell = pagerView.collectionView.visibleCells[0] as? FSPagerViewCell {
            cell.player.pause()
        }
        if let cell = pagerView.collectionView.visibleCells[2] as? FSPagerViewCell {
            cell.player.pause()
        }
    }
    
}

