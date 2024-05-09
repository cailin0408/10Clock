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
    
    @IBAction func colorPreviewValueChanged(_ sender: UISegmentedControl) {
        switch(sender.selectedSegmentIndex){
        case 0:
            let color = UIButton(type: .system).titleColor(for: .normal)!
            //self.view.tintColor =  UIButton(type: .system).titleColor(for: .normal)!
            clock.trackColor = color.withAlphaComponent(0.1)
        case 1:
            //self.view.tintColor = UIColor(red: 0, green: 0.7, blue: 0, alpha: 1)
            let color = UIColor(red: 0, green: 0.7, blue: 0, alpha: 1)
            clock.trackColor = color.withAlphaComponent(0.1)
        case 2:
            //self.view.tintColor = .purple
            let color = UIColor.purple
            clock.trackColor = color.withAlphaComponent(0.1)
        default:()
        }
        
     	clock.update()
    }

    @IBOutlet weak var clock: TenClock!
    
    @IBAction func backgroundValueChanged(_ sender: UISegmentedControl) {
        var bg:UIColor?, fg:UIColor?
        switch(sender.selectedSegmentIndex){
        case 0:
            bg = .white
            fg = .black
        case 1:
            fg = .white
            bg = .black
        default:()
        }

        cells.forEach({
            $0.backgroundColor = bg
        })
        labels.forEach({
            $0.textColor = fg
        })
    }

    @IBAction func enabledValueChanged(_ sender: AnyObject) {
        clock.disabled = !clock.disabled
    }
    @IBAction func gradientValueChanged(_ sender: AnyObject) {
        
    }
    @IBOutlet var cells: [UITableViewCell]!
    @IBOutlet var labels: [UILabel]!
    @IBOutlet var controls: [UISegmentedControl]!
    @IBOutlet weak var endTime: UILabel!
    @IBOutlet weak var beginTime: UILabel!
    
    lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "hh:mm a"
        return dateFormatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if let x = self.tableView as? ConditionallyScrollingTableView{
            x.avoidingView = clock
            x.delaysContentTouches = false
        }
        
        clock.clockHourType = ._24Hour
        clock.clockOffset = Double.pi //時鐘轉180度
        clock.trackSpace = 10
        //clock.trackColor = .yellow.withAlphaComponent(0.5)
        clock.pathColor = .black
        clock.pathWidth = 58
        clock.internalShift = 3
        clock.headBackgroundColor = .white
        clock.tailBackgroundColor = .white
        clock.headImage = .init(named: "icon_s1")
        clock.tailImage = .init(named: "icon_s5")
        clock.isReversePathDraw = true
        clock.isShowDetailTicks = false
        clock.numeralsFont = .init(name: "PingFangTC-Medium", size: 12)
        clock.numeralsColor = .black
        clock.isShowCenterTitle = false
        clock.isUserRotatePathEnabled = false
        
        clock.trackColor = clock.tintColor.withAlphaComponent(0.1)
        //first set endDate, then set startDate
        clock.endDate = Date().addingTimeInterval(60 * 60 * 8)
        clock.startDate = Date()
        clock.delegate = self
        clock.update()
    }
    override func viewWillAppear(_ animated: Bool) {
        refresh()
    }
    var c:TenClock?
	
    func injected(){
        refresh()
    }
    func refresh(){
        if let c=c{
            c.removeFromSuperview()
        }
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation){
        refresh()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ViewController: TenClockDelegate{
    func timesChanged(_ clock:TenClock, startDate:Date, endDate:Date) -> (){
        print("start at: \(startDate), end at: \(endDate)")
    }
    
    func timesUpdated(_ clock:TenClock, startDate:Date, endDate:Date) -> (){
        self.beginTime.text = dateFormatter.string(from: startDate)
        self.endTime.text = dateFormatter.string(from: endDate)
    }
    
    func isGradientPath(_ clock: TenClock) -> Bool {
        return true
    }
    
    func numberOfNumerals(_ clock: TenClock) -> Int {
        return 4
    }
    
    func tenClock(_ clock: TenClock, textForNumeralsAt index: Int) -> String {
        switch index{
        case 0:
            return "18"
        case 1:
            return "24"
        case 2:
            return "6"
        case 3:
            return "12"
        default:
            break
        }
        
        return ""
    }
    
    func numberOfIcons(_ clock: TenClock) -> Int {
        return 2
    }
    
    func tenClock(_ clock: TenClock, imageForIconsAt index: Int) -> UIImage? {
        switch index{
        case 0:
            guard let img = UIImage(named: "icon_s5") else { return nil }
            
            let reSize = CGSize.init(width: 14, height: 14)
            UIGraphicsBeginImageContextWithOptions(reSize, false, UIScreen.main.scale)
            img.draw(in: CGRect(x: 0, y: 0, width: reSize.width, height: reSize.height))
            let reSizeImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
    
            return reSizeImage
        case 1:
            guard let img = UIImage(named: "icon_s1") else { return nil }
            
            let reSize = CGSize.init(width: 9, height: 9)
            UIGraphicsBeginImageContextWithOptions(reSize, false, UIScreen.main.scale)
            img.draw(in: CGRect(x: 0, y: 0, width: reSize.width, height: reSize.height))
            let reSizeImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
    
            return reSizeImage
        default:
            break
        }
        
        return nil
    }
}
