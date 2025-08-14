//
//  DaySymbolsConfig.swift
//  YALCalendar
//
//  Created by Vodolazkyi Anton on 2/4/20.
//  Copyright © 2020 yalantis. All rights reserved.
//

import UIKit

public class DaySymbolsConfig {
    
    public var isEnabled: Bool = true
    public var type: DaySymbols = .veryShort
    public var height: CGFloat = 40
    public var textColor: UIColor = UIColor(displayP3Red: 188 / 255, green: 188 / 255, blue: 188 / 255, alpha: 1.0)
    public var font = FontWithSize(fontGTAmericaMedium, 13)//UIFont.systemFont(ofSize: 12, weight: .regular)
    public var textAlignment: NSTextAlignment = .center
    public var separatorColor: UIColor = .white.withAlphaComponent(0.2)//UIColor(displayP3Red: 240 / 255, green: 240 / 255, blue: 240 / 255, alpha: 1.0)
}
