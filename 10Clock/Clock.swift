//
//  Clock.swift
//  SwiftClock
//
//  Created by Joseph Daniels on 01/09/16.
//  Copyright © 2016 Joseph Daniels. All rights reserved.
//

import Foundation
import UIKit

// MARK: - TenClockDelegate Protocol

/// TenClock 的代理協議，用於處理時間變更和自訂外觀
@objc public protocol TenClockDelegate {
    /// 每次觸摸移動時執行
    @objc optional func timesUpdated(_ clock:TenClock, startDate:Date, endDate:Date) -> ()
    /// 使用者放開手指後執行
    @objc optional func timesChanged(_ clock:TenClock, startDate:Date, endDate:Date) -> ()
    
    /// 是否使用漸層路徑
    @objc optional func isGradientPath(_ clock:TenClock) -> Bool
    /// 漸層路徑的顏色陣列
    @objc optional func colorForGradientPath(_ clock:TenClock) -> [UIColor]
    
    /// 開始時間標記的圖片
    @objc optional func imageForHead(_ clock:TenClock) -> UIImage?
    /// 開始時間標記圖片的大小
    @objc optional func imageSizeForHead(_ clock:TenClock) -> CGSize
    /// 結束時間標記的圖片
    @objc optional func imageForTail(_ clock:TenClock) -> UIImage?
    /// 結束時間標記圖片的大小
    @objc optional func imageSizeForTail(_ clock:TenClock) -> CGSize
    
    /// 時鐘上顯示的數字數量
    @objc optional func numberOfNumerals(_ clock:TenClock) -> Int
    /// 指定位置的數字文字
    @objc optional func tenClock(_ clock:TenClock, textForNumeralsAt index: Int) -> String
    /// 時鐘上顯示的圖示數量
    @objc optional func numberOfIcons(_ clock:TenClock) -> Int
    /// 指定位置的圖示圖片
    @objc optional func tenClock(_ clock:TenClock, imageForIconsAt index: Int) -> UIImage?
}

// MARK: - Helper Functions

/// 中值步進函數，將數值對齊到最接近的步進大小
/// - Parameters:
///   - val: 輸入值
///   - stepSize: 步進大小
/// - Returns: 對齊後的值
func medStepFunction(_ val: CGFloat, stepSize:CGFloat) -> CGFloat{
    let dStepSize = Double(stepSize)
    let dval  = Double(val)
    let nsf = floor(dval/dStepSize)  // 計算有多少個完整步進
    let rest = dval - dStepSize * nsf  // 計算餘數
    // 如果餘數大於半個步進，則進位到下一個步進
    return CGFloat(rest > dStepSize / 2 ? dStepSize * (nsf + 1) : dStepSize * nsf)
}

// MARK: - TenClock Class

/// TenClock：一個可自訂的圓形時間選擇器控件
open class TenClock : UIControl{
    
    // MARK: - Enums
    
    /// 時鐘類型：12 小時制或 24 小時制
    public enum ClockHourType: Int{
        case _12Hour = 12
        case _24Hour = 24
    }

    // MARK: - Public Properties
    
    /// 代理物件
    open weak var delegate:TenClockDelegate?
    
    /// 整體內縮量，控制所有尺寸
    @IBInspectable open var insetAmount: CGFloat = 40
    /// 時鐘類型（12/24 小時制）
    open var clockHourType: ClockHourType = ._12Hour
    /// 時鐘旋轉偏移量（弧度）
    open var clockOffset: Double = Double.zero
    /// 內部偏移量（中心區域的大小）
    open var internalShift: CGFloat = 5
    /// 路徑寬度（已選擇部分的寬度）
    open var pathWidth:CGFloat = 54

    /// 時間步進大小（分鐘）
    var timeStepSize: CGFloat = 5
    
    // MARK: - CALayer Properties
    
    /// 漸層圖層
    let gradientLayer = CAGradientLayer()
    /// 軌道圖層（未選擇部分）
    let trackLayer = CAShapeLayer()
    /// 路徑圖層（已選擇部分）
    let pathLayer = CAShapeLayer()
    /// 開始時間標記圖層（底層）
    let headLayer = CAShapeLayer()
    /// 結束時間標記圖層（底層）
    let tailLayer = CAShapeLayer()
    /// 開始時間標記圖層（頂層）
    let topHeadLayer = CAShapeLayer()
    /// 結束時間標記圖層（頂層）
    let topTailLayer = CAShapeLayer()
    /// 數字圖層容器
    let numeralsLayer = CALayer()
    /// 圖示圖層容器
    let iconsLayer = CALayer()
    /// 中央標題文字圖層
    let titleTextLayer = CATextLayer()
    /// 整體路徑圖層容器
    let overallPathLayer = CALayer()
    /// 內圈白色圓圈圖層
    let innerWhiteCircleLayer = CAShapeLayer()
    /// 外圈白色圓圈圖層
    let outerWhiteCircleLayer = CAShapeLayer()
    /// 302x302 白色底圖圓形背景圖層
    let backgroundCircleLayer = CAShapeLayer()
    /// 未滑動軌跡的圖層（淺灰色）
    let unselectedTrackLayer = CAShapeLayer()
    /// 星星圖示圖層
    let starIconLayer = CALayer()
    /// 太陽圖示圖層
    let sunIconLayer = CALayer()
    
    // MARK: - Appearance Properties
    
    /// 外圓的空白間隔
    open var trackSpace: CGFloat = 0
    /// 外圓的底色
    open var trackColor: UIColor = .black.withAlphaComponent(0.1)
    /// 路徑的顏色
    open var pathColor: UIColor = .white
    
    /// 是否顯示詳細刻度（48 個細刻度）
    open var isShowDetailTicks = true
    
    /// 詳細刻度的複製圖層（16 個刻度，每 3 小時 2 個點）
    let repLayer:CAReplicatorLayer = {
        var r = CAReplicatorLayer()
        r.instanceCount = 16  // 改成 16 個刻度（8個數字 x 2個點）
        r.instanceTransform =
            CATransform3DMakeRotation(
                CGFloat(2*Double.pi) / CGFloat(r.instanceCount),  // 每個刻度旋轉 22.5 度
                0,0,1)
        return r
    }()

    /// 是否顯示小時刻度（24 個粗刻度）
    open var isShowHourTicks = true
    
    /// 小時刻度的複製圖層（24 個刻度）
    let repLayer2:CAReplicatorLayer = {
        var r = CAReplicatorLayer()
        r.instanceCount = 24  // 24 個刻度（每小時一個）
        r.instanceTransform =
            CATransform3DMakeRotation(
                CGFloat(2*Double.pi) / CGFloat(r.instanceCount),  // 每個刻度旋轉 15 度
                0,0,1)
        return r
    }()
    
    // MARK: - Angle Properties
    
    /// 2π 常數
    let twoPi =  CGFloat(2 * Double.pi)
    /// 4π 常數
    let fourPi =  CGFloat(4 * Double.pi)
    
    /// 結束時間的角度（弧度），範圍 π/2 到 π/2 + 4π
    var headAngle: CGFloat = 0{
        didSet{
            // 確保角度在有效範圍內（π/2 到 π/2 + 4π）
            if (headAngle > fourPi  +  CGFloat(Double.pi / 2)){
                headAngle -= fourPi
            }
            if (headAngle <  CGFloat(Double.pi / 2) ){
                headAngle += fourPi
            }
        }
    }

    /// 開始時間的角度（弧度）
    var tailAngle: CGFloat = 0.7 * CGFloat(Double.pi) {
        didSet{
            // 確保 tailAngle 在 headAngle 和 headAngle + 4π 之間
            if (tailAngle  > headAngle + fourPi){
                tailAngle -= fourPi
            } else if (tailAngle  < headAngle ){
                tailAngle += fourPi
            }
        }
    }

    /// 是否允許移動結束時間標記
    open var shouldMoveHead = true
    /// 是否允許移動開始時間標記
    open var shouldMoveTail = true
    
    // MARK: - Style Properties
    
    /// 數字字型
    open var numeralsFont: UIFont? = nil
    /// 數字顏色
    open var numeralsColor:UIColor? = UIColor.darkGray
    /// 細刻度顏色
    open var minorTicksColor:UIColor? = UIColor.lightGray
    /// 粗刻度顏色
    open var majorTicksColor:UIColor? = UIColor.blue
    /// 中央文字字型
    open var centerTextFont: UIFont? = nil
    /// 中央文字顏色
    open var centerTextColor:UIColor? = UIColor.darkGray

    /// 標題顏色
    open var titleColor = UIColor.lightGray
    /// 標題是否使用漸層遮罩
    open var titleGradientMask = false

    /// 是否禁用最近的父視圖滾動（在有效觸摸期間）
    var disableSuperviewScroll = false

    /// 開始時間標記的背景色
    open var headBackgroundColor = UIColor.white.withAlphaComponent(0.8)
    /// 結束時間標記的背景色
    open var tailBackgroundColor = UIColor.white.withAlphaComponent(0.8)

    /// 開始時間標記的底層背景色
    open var headBgColor = UIColor.white
    /// 結束時間標記的底層背景色
    open var tailBgColor = UIColor.white
    /// 開始時間標記的文字
    open var headText: String = "Start"
    /// 結束時間標記的文字
    open var tailText: String = "End"
    /// 開始時間標記的文字顏色
    open var headTextColor = UIColor.black
    /// 結束時間標記的文字顏色
    open var tailTextColor = UIColor.black
    
    /// 是否反向繪製路徑（逆時針）
    open var isReversePathDraw: Bool = false
    /// 時刻文字內距 Padding 值
    open var numeralInsetPadding: CGFloat = 10
    /// 時刻圖示內距 Padding 值
    open var iconInsetPadding: CGFloat = 25
    /// 自訂時刻圖示大小
    open var customIconSize: CGSize? = nil
    /// 是否顯示正中間文字（預設為時間差）
    open var isShowCenterTitle: Bool = true
    /// 是否讓使用者可以旋轉路徑
    open var isUserRotatePathEnabled: Bool = true
    
    // MARK: - Touch State Properties
    
    /// 內部變數：是否觸碰到開始時間標記
    var touchHead: Bool = true
    /// 是否觸碰到開始時間標記（公開屬性）
    open var isTouchHead: Bool{
        return touchHead
    }
    
    /// 內部變數：是否觸碰到結束時間標記
    var touchTail: Bool = true
    /// 是否觸碰到結束時間標記（公開屬性）
    open var isTouchTail: Bool{
        return touchTail
    }
    
    /// 內部變數：是否觸碰到路徑
    var touchPath: Bool = true
    /// 是否觸碰到路徑（公開屬性）
    open var isTouchPath: Bool{
        return touchPath
    }
    
    /// 是否啟用細刻度
    open var minorTicksEnabled:Bool = true
    /// 是否啟用粗刻度
    open var majorTicksEnabled:Bool = true
    
    /// 是否禁用控件
    @objc open var disabled:Bool = false {
        didSet{
            update()
        }
    }
    
    /// 標記按鈕的內縮量
    open var buttonInset:CGFloat = 2
    
    /// 將顏色轉換為禁用狀態的灰階顏色
    /// - Parameter color: 原始顏色
    /// - Returns: 如果禁用則返回灰階，否則返回原色
    func disabledFormattedColor(_ color:UIColor) -> UIColor{
        return disabled ? color.greyscale : color
    }

    // MARK: - Computed Properties
    
    /// 軌道寬度（路徑寬度 + 間隔）
    var trackWidth: CGFloat { return pathWidth + trackSpace }
    
    /// 將角度投影到圓周上的點
    /// - Parameter theta: 角度（弧度）
    /// - Returns: 圓周上的點
    func proj(_ theta:Angle) -> CGPoint{
        let center = self.layer.center
        return CGPoint(x: center.x + trackRadius * cos(theta) ,
                           y: center.y - trackRadius * sin(theta) )
    }

    /// 結束時間標記的位置
    var headPoint: CGPoint{
        return proj(headAngle)
    }
    /// 開始時間標記的位置
    var tailPoint: CGPoint{
        return proj(tailAngle)
    }

    /// 日曆物件（使用公曆）
    lazy internal var calendar = Calendar(identifier:Calendar.Identifier.gregorian)
    
    /// 將分鐘數轉換為日期
    /// - Parameter val: 分鐘數
    /// - Returns: 對應的日期
    func toDate(_ val:CGFloat)-> Date {
        return calendar.date(byAdding: Calendar.Component.minute , value: Int(val), to: Date().startOfDay as Date)!
    }
    
    /// 開始日期（從 tailAngle 計算）
    open var startDate: Date{
        get{return angleToTime(tailAngle) }
        set{ tailAngle = timeToAngle(newValue) }
    }
    /// 結束日期（從 headAngle 計算）
    open var endDate: Date{
        get{return angleToTime(headAngle) }
        set{ headAngle = timeToAngle(newValue) }
    }

    /// 內部圓的半徑
    var internalRadius:CGFloat {
        return internalInset.height
    }
    /// 外部內縮矩形
    var inset:CGRect{
        return self.layer.bounds.insetBy(dx: insetAmount, dy: insetAmount)
    }
    /// 內部內縮矩形（刻度線的範圍）
    var internalInset:CGRect{
        let reInsetAmount = trackWidth / 2 + internalShift
        return self.inset.insetBy(dx: reInsetAmount, dy: reInsetAmount)
    }
    /// 數字的內縮矩形（數字顯示的範圍）
    var numeralInset:CGRect{
        let reInsetAmount = trackWidth / 2 + numeralInsetPadding
        return self.inset.insetBy(dx: reInsetAmount, dy: reInsetAmount)
    }
    /// 圖示的內縮矩形（圖示顯示的範圍）
    var iconInset:CGRect{
        let reInsetAmount = trackWidth / 2 + iconInsetPadding
        return self.inset.insetBy(dx: reInsetAmount, dy: reInsetAmount)
    }
    /// 中央標題文字的內縮矩形
    var titleTextInset:CGRect{
        let reInsetAmount = trackWidth.checked / 2 + 4 * internalShift
        return (self.inset).insetBy(dx: reInsetAmount, dy: reInsetAmount)
    }
    /// 軌道半徑
    var trackRadius:CGFloat { return inset.height / 2}
    /// 標記按鈕半徑
    var buttonRadius:CGFloat { return pathWidth / 2 }
    /// 標記按鈕內部半徑（扣除內縮）
    var iButtonRadius:CGFloat { return buttonRadius - buttonInset }

    // MARK: - Time/Angle Conversion
    
    /// 將日期轉換為角度（0 到 4π）
    /// - Parameter date: 輸入日期
    /// - Returns: 對應的角度（弧度）
    func timeToAngle(_ date: Date) -> Angle{
        let units : Set<Calendar.Component> = [.hour, .minute]
        let components = self.calendar.dateComponents(units, from: date)
        let min = Double(  60 * components.hour! + components.minute! )

        if clockHourType == ._24Hour{
            // 24 小時制：將分鐘數轉換為 0-4π 的角度
            // π/2 + clockOffset 是起始角度（12 點鐘方向）
            // 減去時間比例乘以 2π（逆時針）
            // 對齊到 5 分鐘的步進
            return medStepFunction(CGFloat(Double.pi / 2 + clockOffset - ( min / (24 * 60)) * 2 * Double.pi), stepSize: CGFloat( 2 * Double.pi / (24 * 60 / 5)))
        }else{
            // 12 小時制：類似邏輯但使用 12 小時
            return medStepFunction(CGFloat(Double.pi / 2 + clockOffset - ( min / (12 * 60)) * 2 * Double.pi), stepSize: CGFloat( 2 * Double.pi / (12 * 60 / 5)))
        }
    }

    /// 將角度轉換為日期（0 到 4π）
    /// - Parameter angle: 輸入角度（弧度）
    /// - Returns: 對應的日期
    func angleToTime(_ angle: Angle) -> Date{
        let dAngle = Double(angle)
        var minutes: CGFloat = 12 * 60  // 預設 12 小時制（720 分鐘）
        if clockHourType == ._24Hour{
            minutes = 24 * 60  // 24 小時制（1440 分鐘）
        }

        // 0點在上方
        // 因為 clockOffset = π，所以 π/2 - π = -π/2
        // 要讓正上方（π/2）對應到 0:00，需要調整計算
        let min = CGFloat(((Double.pi / 2 - dAngle) / (2 * Double.pi)) * Double(minutes))
        
        let startOfToday = Calendar.current.startOfDay(for: Date())
        
        // 對齊到 5 分鐘的步進，並加到今天的開始時間
        return self.calendar.date(byAdding: .minute, value: Int(medStepFunction(min, stepSize: 5)), to: startOfToday)!
    }
    
    // MARK: - Interface Builder Support
    
    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        update()
    }
    
    // MARK: - Update Methods
    
    /// 更新 302x302 白色底圖圓形背景
    func updateBackgroundCircle() {
        let circleRadius: CGFloat = 151  // 302 / 2
        let backgroundCircle = UIBezierPath(
            arcCenter: CGPoint(x: layer.bounds.width / 2, y: layer.bounds.height / 2),
            radius: circleRadius,
            startAngle: 0,
            endAngle: CGFloat(2 * Double.pi),
            clockwise: true)
        backgroundCircleLayer.path = backgroundCircle.cgPath
        backgroundCircleLayer.fillColor = UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1.0).cgColor
        backgroundCircleLayer.frame = layer.bounds
    }
    
    /// 更新所有視覺元素
    open func update() {
        // 確保控件為正方形
        let mm = min(self.layer.bounds.size.height, self.layer.bounds.size.width)
        CATransaction.begin()
        self.layer.size = CGSize(width: mm, height: mm)

        // 更新顏色（支援深色模式）
        trackLayer.strokeColor = trackColor.resolvedColor(with: self.traitCollection).cgColor
        pathLayer.strokeColor = pathColor.resolvedColor(with: self.traitCollection).cgColor
        overallPathLayer.occupation = layer.occupation
        gradientLayer.occupation = layer.occupation

        trackLayer.occupation = (inset.size, layer.center)

        pathLayer.occupation = (inset.size, overallPathLayer.center)
        repLayer.occupation = (internalInset.size, overallPathLayer.center)
        repLayer2.occupation  =  (internalInset.size, overallPathLayer.center)
        numeralsLayer.occupation = (numeralInset.size, layer.center)
        iconsLayer.occupation = (iconInset.size, layer.center)

        trackLayer.fillColor = UIColor.clear.cgColor
        pathLayer.fillColor = UIColor.clear.cgColor

        // 禁用隱式動畫
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        updateBackgroundCircle()
        updateGradientLayer()
        updateTrackLayerPath()
        updateUnselectedTrackLayerPath()
        updateWhiteCircles()
        updatePathLayerPath()
        updateHeadTailLayers()
        updateWatchFaceTicks()
        updateWatchFaceNumerals()
        updateWatchFaceIcons()
        updateWatchFaceTitle()
        updateFixedIcons()
        CATransaction.commit()
    }
    
    /// 更新漸層圖層
    func updateGradientLayer() {
        let isGradientPath = delegate?.isGradientPath?(self) ?? true
        if isGradientPath{
            // 使用代理提供的漸層顏色，或使用預設的漸層
            let colors = delegate?.colorForGradientPath?(self) ?? [tintColor, tintColor.modified(withAdditionalHue: -0.08, additionalSaturation: 0.15, additionalBrightness: 0.2)].map(disabledFormattedColor)
            gradientLayer.colors = colors.map({ $0.resolvedColor(with: self.traitCollection).cgColor })
            gradientLayer.mask = overallPathLayer
            gradientLayer.startPoint = CGPoint(x:0,y:0)
        }else{
            // 不使用漸層，使用單一顏色
            gradientLayer.colors = [pathColor.resolvedColor(with: self.traitCollection).cgColor, pathColor.resolvedColor(with: self.traitCollection).cgColor]
            gradientLayer.mask = overallPathLayer
            gradientLayer.startPoint = CGPoint(x:0,y:0)
        }
    }

    /// 更新軌道圖層路徑（完整圓環）
    func updateTrackLayerPath() {
        let circle = UIBezierPath(
            ovalIn: CGRect(
                origin:CGPoint(x: 0, y: 00),
                size: CGSize(width:trackLayer.size.width,
                    height: trackLayer.size.width)))
        trackLayer.lineWidth = trackWidth
        trackLayer.path = circle.cgPath
    }
    
    /// 更新未滑動軌跡圖層路徑（淺灰色圓環）
    func updateUnselectedTrackLayerPath() {
        let circle = UIBezierPath(
            ovalIn: CGRect(
                origin: CGPoint(x: 0, y: 0),
                size: CGSize(width: trackLayer.size.width,
                            height: trackLayer.size.width)))
        unselectedTrackLayer.lineWidth = 15
        unselectedTrackLayer.path = circle.cgPath
        unselectedTrackLayer.strokeColor = UIColor(red: 246/255, green: 246/255, blue: 246/255, alpha: 1.0).cgColor
        unselectedTrackLayer.fillColor = UIColor.clear.cgColor
        unselectedTrackLayer.occupation = (inset.size, layer.center)
    }
    
    /// 更新白色圓圈（內外兩個白色邊框）
    func updateWhiteCircles() {
        // 外圈白色圓圈
        let outerRadius = trackRadius + trackWidth / 2
        let outerCircle = UIBezierPath(
            arcCenter: CGPoint(x: layer.bounds.width / 2, y: layer.bounds.height / 2),
            radius: outerRadius,
            startAngle: 0,
            endAngle: CGFloat(2 * Double.pi),
            clockwise: true)
        outerWhiteCircleLayer.path = outerCircle.cgPath
        outerWhiteCircleLayer.strokeColor = UIColor.white.cgColor
        outerWhiteCircleLayer.fillColor = UIColor.clear.cgColor
        outerWhiteCircleLayer.lineWidth = 3
        outerWhiteCircleLayer.frame = layer.bounds
        
        // 內圈白色圓圈
        let innerRadius = trackRadius - trackWidth / 2
        let innerCircle = UIBezierPath(
            arcCenter: CGPoint(x: layer.bounds.width / 2, y: layer.bounds.height / 2),
            radius: innerRadius,
            startAngle: 0,
            endAngle: CGFloat(2 * Double.pi),
            clockwise: true)
        innerWhiteCircleLayer.path = innerCircle.cgPath
        innerWhiteCircleLayer.strokeColor = UIColor.white.cgColor
        innerWhiteCircleLayer.fillColor = UIColor.clear.cgColor
        innerWhiteCircleLayer.lineWidth = 3
        innerWhiteCircleLayer.frame = layer.bounds
    }
    
    override open func layoutSubviews() {
        update()
    }

    /// 更新路徑圖層（已選擇的弧形部分）
    func updatePathLayerPath() {
        let arcCenter = pathLayer.center
        pathLayer.fillColor = UIColor.clear.cgColor
        pathLayer.lineWidth = pathWidth
        if isReversePathDraw{
            // 反向繪製（逆時針）
            pathLayer.path = UIBezierPath(
                arcCenter: arcCenter,
                radius: trackRadius,
                startAngle: (twoPi) - headAngle,
                endAngle: (twoPi) - ((tailAngle - headAngle) >= twoPi ? tailAngle - twoPi : tailAngle),
                clockwise: true).cgPath
        }else{
            // 正向繪製（順時針）
            pathLayer.path = UIBezierPath(
                arcCenter: arcCenter,
                radius: trackRadius,
                startAngle: (twoPi) - ((tailAngle - headAngle) >= twoPi ? tailAngle - twoPi : tailAngle),
                endAngle: (twoPi) - headAngle,
                clockwise: true).cgPath
        }
    }

    /// 建立文字圖層
    /// - Parameters:
    ///   - str: 文字內容
    ///   - color: 文字顏色
    /// - Returns: CATextLayer 物件
    func tlabel(_ str:String, color:UIColor? = nil) -> CATextLayer{
        let f = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption2)
        let cgFont = CTFontCreateWithName(f.fontName as CFString, f.pointSize/2,nil)
        let l = CATextLayer()
        l.bounds.size = CGSize(width: 30, height: 15)
        l.fontSize = f.pointSize
        l.foregroundColor =  disabledFormattedColor(color ?? tintColor).resolvedColor(with: self.traitCollection).cgColor
        l.alignmentMode = CATextLayerAlignmentMode.center
        l.contentsScale = UIScreen.main.scale
        l.font = cgFont
        l.string = str

        return l
    }
    
    /// 更新開始和結束時間標記圖層
    func updateHeadTailLayers() {
        let size = CGSize(width: 2 * buttonRadius, height: 2 * buttonRadius)
        let iSize = CGSize(width: 2 * iButtonRadius, height: 2 * iButtonRadius)
        let circle = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: 0, y:0), size: size)).cgPath
        let iCircle = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: 0, y:0), size: iSize)).cgPath
        
        // 設定底層圓形
        tailLayer.path = circle
        headLayer.path = circle
        tailLayer.size = size
        headLayer.size = size
        tailLayer.position = tailPoint
        headLayer.position = headPoint
        
        // 設定頂層圓形
        topTailLayer.position = tailPoint
        topHeadLayer.position = headPoint
        headLayer.fillColor = tailBgColor.resolvedColor(with: self.traitCollection).cgColor
        tailLayer.fillColor = headBgColor.resolvedColor(with: self.traitCollection).cgColor
        topTailLayer.path = iCircle
        topHeadLayer.path = iCircle
        topTailLayer.size = iSize
        topHeadLayer.size = iSize
        topHeadLayer.fillColor = disabledFormattedColor(headBackgroundColor).resolvedColor(with: self.traitCollection).cgColor
        topTailLayer.fillColor = disabledFormattedColor(tailBackgroundColor).resolvedColor(with: self.traitCollection).cgColor
        
        // 清除舊的子圖層
        topHeadLayer.sublayers?.forEach({$0.removeFromSuperlayer()})
        topTailLayer.sublayers?.forEach({$0.removeFromSuperlayer()})
        
        // 使用開始時間標記圖片或文字
        if let headImage = delegate?.imageForHead?(self){
            let autoSize: CGSize = CGSize(width: min(headImage.size.width, iSize.width), height: min(headImage.size.height, iSize.height))
            let imgSize = delegate?.imageSizeForHead?(self) ?? autoSize
            let startImg = CALayer()
            startImg.backgroundColor = UIColor.clear.cgColor
            startImg.bounds = CGRect(x: 0, y: 0 , width: imgSize.width, height: imgSize.height)
            startImg.position = topTailLayer.center
            startImg.contents = headImage.imageAsset?.image(with: self.traitCollection).cgImage ?? headImage.cgImage
            topTailLayer.addSublayer(startImg)
        }else{
            let stText = tlabel(headText, color: disabledFormattedColor(headTextColor))
            stText.position = topTailLayer.center
            topTailLayer.addSublayer(stText)
        }
        
        // 使用結束時間標記圖片或文字
        if let tailImage = delegate?.imageForTail?(self){
            let autoSize: CGSize = CGSize(width: min(tailImage.size.width, iSize.width), height: min(tailImage.size.height, iSize.height))
            let imgSize = delegate?.imageSizeForTail?(self) ?? autoSize
            let endImg = CALayer()
            endImg.backgroundColor = UIColor.clear.cgColor
            endImg.bounds = CGRect(x: 0, y: 0 , width: imgSize.width, height: imgSize.height)
            endImg.position = topHeadLayer.center
            endImg.contents = tailImage.imageAsset?.image(with: self.traitCollection).cgImage ?? tailImage.cgImage
            topHeadLayer.addSublayer(endImg)
        }else{
            let endText = tlabel(tailText, color: disabledFormattedColor(tailTextColor))
            endText.position = topHeadLayer.center
            topHeadLayer.addSublayer(endText)
        }
    }

    /// 更新時鐘面上的數字
    func updateWatchFaceNumerals() {
        numeralsLayer.sublayers?.forEach({$0.removeFromSuperlayer()})
        let f = numeralsFont ?? UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption2)
        let cgFont = CTFontCreateWithName(f.fontName as CFString, f.pointSize/2,nil)
        let startPos = CGPoint(x: numeralsLayer.bounds.midX, y: 15)
        let origin = numeralsLayer.center
        
        let count: Int = delegate?.numberOfNumerals?(self) ?? clockHourType.rawValue
        guard count > 0 else { return }
        
        let step = (2 * Double.pi) / Double(count)
        for i in (1 ... count){
            let l = CATextLayer()
            l.fontSize = f.pointSize
            l.alignmentMode = CATextLayerAlignmentMode.center
            l.contentsScale = UIScreen.main.scale
            l.font = cgFont
            l.string = delegate?.tenClock?(self, textForNumeralsAt: i-1) ?? "\(i)"
            l.foregroundColor = disabledFormattedColor(numeralsColor ?? tintColor).resolvedColor(with: self.traitCollection).cgColor
            l.bounds.size = l.preferredFrameSize()
            // 計算數字的位置（圓周上均勻分布）
            l.position = CGVector(from:origin, to:startPos).rotate( CGFloat(Double(i) * step)).add(origin.vector).point.checked
            numeralsLayer.addSublayer(l)
        }
    }
    
    /// 更新時鐘面上的圖示
    func updateWatchFaceIcons(){
        iconsLayer.sublayers?.forEach({$0.removeFromSuperlayer()})
        let startPos = CGPoint(x: iconsLayer.bounds.midX, y: 15)
        let origin = iconsLayer.center
        
        let count: Int = delegate?.numberOfIcons?(self) ?? 0
        guard count > 0 else { return }
        
        let step = (2 * Double.pi) / Double(count)
        // 向左旋轉 30 度（兩個單位 = 2 * 15度）
        let angleOffset = step * 2  // 兩個單位 = 30度
        
        for i in (1 ... count){
            if let icon = delegate?.tenClock?(self, imageForIconsAt: i-1){
                let iconLayer = CALayer()
                iconLayer.backgroundColor = UIColor.clear.cgColor
                iconLayer.bounds = CGRect(x: 0, y: 0 , width: customIconSize?.width ?? icon.size.width, height: customIconSize?.height ?? icon.size.height)
                iconLayer.contents = icon.imageAsset?.image(with: self.traitCollection).cgImage ?? icon.cgImage
                // 計算圖示的位置 + 往左偏移兩個位置
                iconLayer.position = CGVector(from:origin, to:startPos).rotate(CGFloat(Double(i) * step) + angleOffset).add(origin.vector).point.checked
                iconsLayer.addSublayer(iconLayer)
            }
        }
    }
    
    /// 更新中央標題文字（顯示時間差）
    func updateWatchFaceTitle(){
        if isShowCenterTitle{
            titleTextLayer.isHidden = false
            let f = centerTextFont ?? UIFont.preferredFont(forTextStyle: UIFont.TextStyle.title1)
            let cgFont = CTFontCreateWithName(f.fontName as CFString, f.pointSize/2,nil)
            titleTextLayer.bounds.size = CGSize( width: titleTextInset.size.width, height: 50)
            titleTextLayer.fontSize = f.pointSize
            titleTextLayer.alignmentMode = CATextLayerAlignmentMode.center
            titleTextLayer.foregroundColor = disabledFormattedColor(centerTextColor ?? tintColor).resolvedColor(with: self.traitCollection).cgColor
            titleTextLayer.contentsScale = UIScreen.main.scale
            titleTextLayer.font = cgFont
            
            // 計算時間差（以 5 分鐘為單位）
            var fiveMinIncrements = Int( ((tailAngle - headAngle) / twoPi) * 12 * 12)
            if fiveMinIncrements < 0 {
                print("tenClock:Err: is negative")
                fiveMinIncrements += (24 * (60/5))
            }
            
            // 顯示 "X hr Y min" 格式
            titleTextLayer.string = "\(fiveMinIncrements / 12)hr \((fiveMinIncrements % 12) * 5)min"
            titleTextLayer.position = gradientLayer.center
        }else{
            titleTextLayer.isHidden = true
        }
    }
    
    /// 建立刻度線
    /// 建立刻度線（改成圓點）
    func tick() -> CAShapeLayer{
        let tick = CAShapeLayer()
        
        // 創建圓點路徑（2x2 的圓）
        let dotPath = UIBezierPath(ovalIn: CGRect(x: -1, y: -1, width: 2, height: 2))
        
        tick.path = dotPath.cgPath
        tick.bounds.size = CGSize(width: 2, height: 2)
        tick.fillColor = UIColor(red: 35/255, green: 52/255, blue: 64/255, alpha: 1.0).cgColor
        
        return tick
    }
    /// 更新時鐘面上的刻度線
    func updateWatchFaceTicks() {
        repLayer.sublayers?.forEach({$0.removeFromSuperlayer()})
        if isShowDetailTicks{
            // 顯示 16 個圓點刻度
            let t = tick()
            // 調整 y 值讓圓點和數字在同一圓上
            t.position = CGPoint(x: repLayer.bounds.midX, y: 10)  // 可以調整這個 10 的數值
            repLayer.addSublayer(t)
            repLayer.position = self.bounds.center
            repLayer.bounds.size = self.internalInset.size
        }
        
        repLayer2.sublayers?.forEach({$0.removeFromSuperlayer()})
        // 不使用 repLayer2
    }
    
    func updateFixedIcons() {
        let center = layer.center
        
        // 計算數字 0 所在的半徑（numeralInset 決定數字的位置）
        let numeralRadius = numeralInset.width / 2
        
        let starAngle = CGFloat(Double.pi / 2)  // 0 點的角度（最上方）
        let starRadius = numeralRadius - 35
        let starX = center.x + starRadius * cos(starAngle)
        let starY = center.y - starRadius * sin(starAngle)
        
        if let starImage = UIImage(named: "icon_star") {
            starIconLayer.contents = starImage.cgImage
            starIconLayer.bounds = CGRect(x: 0, y: 0, width: 11, height: 12)
            starIconLayer.position = CGPoint(x: starX, y: starY)
            starIconLayer.contentsGravity = .resizeAspect
        }
        
        let sunAngle = CGFloat(-Double.pi / 2)  // 12 點的角度（最下方）
        let sunRadius = numeralRadius - 35
        let sunX = center.x + sunRadius * cos(sunAngle)
        let sunY = center.y - sunRadius * sin(sunAngle)
        
        if let sunImage = UIImage(named: "icon_sun") {
            sunIconLayer.contents = sunImage.cgImage
            sunIconLayer.bounds = CGRect(x: 0, y: 0, width: 11, height: 11)
            sunIconLayer.position = CGPoint(x: sunX, y: sunY)
            sunIconLayer.contentsGravity = .resizeAspect
        }
    }
    
    /// 指標長度（未使用）
    var pointerLength:CGFloat = 0.0

    /// 建立所有子圖層
    func createSublayers() {
        // 先添加 302x302 白色底圖圓，確保在最底層
        layer.addSublayer(backgroundCircleLayer)
        
        layer.addSublayer(repLayer2)
        layer.addSublayer(repLayer)
        layer.addSublayer(numeralsLayer)
        layer.addSublayer(iconsLayer)
        layer.addSublayer(trackLayer)
        layer.addSublayer(unselectedTrackLayer)
        layer.addSublayer(starIconLayer)
        layer.addSublayer(sunIconLayer)

        overallPathLayer.addSublayer(pathLayer)
        overallPathLayer.addSublayer(headLayer)
        overallPathLayer.addSublayer(tailLayer)
        overallPathLayer.addSublayer(titleTextLayer)
        layer.addSublayer(overallPathLayer)
        layer.addSublayer(gradientLayer)
        
        // 白色圓圈要在 gradientLayer 之後添加，這樣才會顯示在最上層
        layer.addSublayer(outerWhiteCircleLayer)
        layer.addSublayer(innerWhiteCircleLayer)
        
        gradientLayer.addSublayer(topHeadLayer)
        gradientLayer.addSublayer(topTailLayer)
        update()
        trackLayer.strokeColor = trackColor.resolvedColor(with: self.traitCollection).cgColor
        pathLayer.strokeColor = pathColor.resolvedColor(with: self.traitCollection).cgColor
    }
    
    // MARK: - Initializers
    
    override public init(frame: CGRect) {
        super.init(frame:frame)
        backgroundColor = UIColor ( red: 0.1149, green: 0.115, blue: 0.1149, alpha: 0.0 )
        createSublayers()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = UIColor ( red: 0.1149, green: 0.115, blue: 0.1149, alpha: 0.0 )
        createSublayers()
    }

    // MARK: - Value Properties (UIControl)
    
    fileprivate var backingValue: Float = 0.0

    var value: Float {
        get { return backingValue }
        set { setValue(newValue, animated: false) }
    }

    func setValue(_ value: Float, animated: Bool) {
        if value != backingValue {
            backingValue = min(maximumValue, max(minimumValue, value))
        }
    }

    var minimumValue: Float = 0.0
    var maximumValue: Float = 1.0
    var continuous = true
    var valueChanged = false

    // MARK: - Touch Handling
    
    /// 點移動函數（用於處理拖曳）
    var pointMover:((CGPoint) ->())?
    
    /// 觸摸開始
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !disabled  else {
            pointMover = nil
            return
        }
        
        let touch = touches.first!
        let pointOfTouch = touch.location(in: self)
        guard let layer = self.overallPathLayer.hitTest( pointOfTouch ) else { return }

        var prev = pointOfTouch
        
        // 建立點移動函數的工廠函數
        // g: 獲取當前角度的函數
        // s: 設定角度變化的函數
        let pointerMoverProducer: (@escaping (CGPoint) -> Angle, @escaping (Angle)->()) -> (CGPoint) -> () = { g, s in
            return { p in
                let c = self.layer.center
                let computedP = CGPoint(x: p.x, y: self.layer.bounds.height - p.y)
                let v1 = CGVector(from: c, to: computedP)
                let v2 = CGVector(angle:g( p ))

                var steps = 12 * 60 / 5  // 12 小時制的步進數
                if self.clockHourType == ._24Hour{
                    steps = 24 * 60 / 5  // 24 小時制的步進數
                }
                // 計算並設定角度變化（離散化到步進）
                s(clockDescretization(CGVector.signedTheta(v1, vec2: v2), steps: steps))
                self.update()
            }
        }

        // 重置觸摸狀態為 false
        touchTail = false
        touchHead = false
        touchPath = false
        
        // 根據觸摸的圖層決定行為
        switch(layer){
        case headLayer:
            // 觸摸到結束時間標記
            touchTail = true
            if (shouldMoveHead) {
                pointMover = pointerMoverProducer({ _ in self.headAngle}, {self.headAngle += $0; self.tailAngle += 0})
            } else {
                pointMover = nil
            }
        case tailLayer:
            // 觸摸到開始時間標記
            touchHead = true
            if (shouldMoveHead) {
                pointMover = pointerMoverProducer({_ in self.tailAngle}, {self.headAngle += 0;self.tailAngle += $0})
            } else {
                pointMover = nil
            }
        case pathLayer:
            // 觸摸到路徑（可以旋轉整個選擇範圍）
            touchPath = true
            if (shouldMoveHead && isUserRotatePathEnabled) {
                pointMover = pointerMoverProducer({ pt in
                    let x = CGVector(from: self.bounds.center,
                                     to:CGPoint(x: prev.x, y: self.layer.bounds.height - prev.y)).theta;
                    prev = pt;
                    return x
                }, {self.headAngle += $0; self.tailAngle += $0 })
            } else {
                pointMover = nil
            }
        default: break
        }
    }
    
    /// 觸摸取消
    override open  func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    }
    
    /// 觸摸結束
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        pointMover = nil
        delegate?.timesChanged?(self, startDate: self.startDate, endDate: endDate)
    }
    
    /// 觸摸移動
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let pointMover = pointMover else { return }
        pointMover(touch.location(in: self))
        delegate?.timesUpdated?(self, startDate: self.startDate, endDate: endDate)
    }
}
