//
//  ViewController.swift
//  SwiftClock
//
//  Created by Joseph Daniels on 31/08/16.
//  Copyright © 2016 Joseph Daniels. All rights reserved.
//

import UIKit
import TenClock

class ViewController: UITableViewController {
    
    // MARK: - IBActions
    
    /// 當顏色預覽的分段控制器數值改變時觸發
    /// - Parameter sender: 分段控制器
    @IBAction func colorPreviewValueChanged(_ sender: UISegmentedControl) {
        switch(sender.selectedSegmentIndex){
        case 0:
            // 使用系統預設的藍色，並設定透明度為 0.1
            let color = UIButton(type: .system).titleColor(for: .normal)!
            clock.trackColor = color.withAlphaComponent(0.1)
        case 1:
            // 使用綠色，並設定透明度為 0.1
            let color = UIColor.white
            clock.trackColor = color.withAlphaComponent(0.1)
        case 2:
            // 使用紫色，並設定透明度為 0.1
            let color = UIColor.purple
            clock.trackColor = color.withAlphaComponent(0.1)
        default:()
        }
        
        // 更新時鐘顯示
        clock.update()
    }

    /// 時鐘控件的 IBOutlet 連結
    @IBOutlet weak var clock: TenClock!
    
    /// 當背景顏色的分段控制器數值改變時觸發
    /// - Parameter sender: 分段控制器
    @IBAction func backgroundValueChanged(_ sender: UISegmentedControl) {
        var bg:UIColor?, fg:UIColor?
        switch(sender.selectedSegmentIndex){
        case 0:
            // 灰色背景，黑色前景
            bg = .gray
            fg = .black
        case 1:
            // 黑色背景，灰色前景
            fg = .gray
            bg = .black
        default:()
        }

        // 更新所有 cell 的背景色
        cells.forEach({
            $0.backgroundColor = bg
        })
        // 更新所有 label 的文字顏色
        labels.forEach({
            $0.textColor = fg
        })
    }

    /// 當啟用/停用開關被切換時觸發
    /// - Parameter sender: 開關控件
    @IBAction func enabledValueChanged(_ sender: AnyObject) {
        clock.disabled = !clock.disabled
    }
    
    /// 當漸層開關被切換時觸發（目前為空實作）
    /// - Parameter sender: 開關控件
    @IBAction func gradientValueChanged(_ sender: AnyObject) {
        
    }
    
    // MARK: - IBOutlets
    
    /// 所有的 TableViewCell 陣列
    @IBOutlet var cells: [UITableViewCell]!
    /// 所有的 Label 陣列
    @IBOutlet var labels: [UILabel]!
    /// 所有的分段控制器陣列
    @IBOutlet var controls: [UISegmentedControl]!
    /// 顯示結束時間的 Label
    @IBOutlet weak var endTime: UILabel!
    /// 顯示開始時間的 Label
    @IBOutlet weak var beginTime: UILabel!
    
    // MARK: - Properties
    
    /// 日期格式化器，用於將日期轉換為 "時:分 上午/下午" 的格式
    lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "hh:mm a"
        return dateFormatter
    }()
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        
        if let x = self.tableView as? ConditionallyScrollingTableView{
            x.avoidingView = clock
            x.delaysContentTouches = false
        }
        
        // === 時鐘基本設定 ===
        clock.clockHourType = ._24Hour
        clock.clockOffset = Double.pi
        
        // === 縮小時鐘、放大白色間距 ===
        clock.insetAmount = 45
        clock.pathWidth = 31
        clock.trackSpace = 25
        clock.internalShift = 45
        
        // === 讓數字和圓點在同一圓周上 ===
        clock.numeralInsetPadding = 3   // 數字的內距
        clock.iconInsetPadding = 3      // 圓點的內距（設定和數字一樣）
        clock.customIconSize = CGSize(width: 2, height: 2)  // 圓點大小
        
        // === 顏色設定 ===
        clock.trackColor = .white
        clock.pathColor = UIColor(red: 35/255, green: 52/255, blue: 64/255, alpha: 1.0)
        
        // === 頭尾標記設定 ===
        clock.headBackgroundColor = .white
        clock.tailBackgroundColor = .white
        clock.isReversePathDraw = true
        
        // === 刻度與數字設定 ===
        clock.isShowDetailTicks = false  // 關閉原本的刻度線
        clock.isShowHourTicks = false    // 關閉原本的粗刻度
        clock.numeralsFont = .init(name: "PingFangTC-Medium", size: 12)
        clock.numeralsColor = .black
        
        // === 其他設定 ===
        clock.isShowCenterTitle = false
        clock.isUserRotatePathEnabled = false
        
        // === 設定初始時間範圍 ===
        clock.endDate = Date().addingTimeInterval(60 * 60 * 8)
        clock.startDate = Date()
        
        clock.delegate = self
        clock.update()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        refresh()
    }
    
    /// 用於存儲時鐘實例的變數（目前未使用）
    var c:TenClock?
    
    /// 注入方法，用於重新載入（可能用於熱重載）
    func injected(){
        refresh()
    }
    
    /// 刷新方法，移除並重建時鐘
    func refresh(){
        if let c=c{
            c.removeFromSuperview()
        }
    }
    
    /// 當裝置旋轉時觸發
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation){
        refresh()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // 釋放任何可以重建的資源
    }
}

// MARK: - TenClockDelegate

extension ViewController: TenClockDelegate{
    
    func timesUpdated(_ clock:TenClock, startDate:Date, endDate:Date) -> (){
        self.beginTime.text = dateFormatter.string(from: startDate)
        self.endTime.text = dateFormatter.string(from: endDate)
    }
    
    func timesChanged(_ clock:TenClock, startDate:Date, endDate:Date) -> (){
        print("start at: \(startDate), end at: \(endDate), isTouchHead: \(clock.isTouchHead), isTouchTail: \(clock.isTouchTail), isTouchPath: \(clock.isTouchPath)")
    }
    
    func isGradientPath(_ clock: TenClock) -> Bool {
        return false
    }
    
    func imageForHead(_ clock: TenClock) -> UIImage? {
        return .init(named: "icon_indicator_yellow")
    }
    
    func imageSizeForHead(_ clock: TenClock) -> CGSize {
        return .init(width: 38, height: 38)
    }
    
    func imageForTail(_ clock: TenClock) -> UIImage? {
        return .init(named: "icon_indicator_blue")
    }
    
    func imageSizeForTail(_ clock: TenClock) -> CGSize {
        return .init(width: 38, height: 38)
    }
    
    /// 顯示 8 個數字
    func numberOfNumerals(_ clock: TenClock) -> Int {
        return 8
    }
    
    /// 提供數字文字：3, 6, 9, 12, 15, 18, 21, 0
    func tenClock(_ clock: TenClock, textForNumeralsAt index: Int) -> String {
        let hours = [3, 6, 9, 12, 15, 18, 21, 0]
        return "\(hours[index])"
    }
    
    /// 顯示 24 個圓點（8個數字 + 16個圓點 = 24個位置）
    func numberOfIcons(_ clock: TenClock) -> Int {
        return 24  // 每個位置間隔 15 度（360度/24）
    }
    
    /// 提供圓點圖示
    func tenClock(_ clock: TenClock, imageForIconsAt index: Int) -> UIImage? {
        // 如果是數字位置（3的倍數），不顯示圓點
        if index % 3 == 0 {
            return nil
        }
        
        // 其他位置顯示圓點
        let dotSize = CGSize(width: 2, height: 2)
        let dotColor = UIColor(red: 35/255, green: 52/255, blue: 64/255, alpha: 1.0)
        
        UIGraphicsBeginImageContextWithOptions(dotSize, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.setFillColor(dotColor.cgColor)
        context.fillEllipse(in: CGRect(x: 0, y: 0, width: dotSize.width, height: dotSize.height))
        
        let dotImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return dotImage
    }
}
