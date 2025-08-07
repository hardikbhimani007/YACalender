//
//  DayData.swift
//  YALCalendar
//
//  Created by Vodolazkyi Anton on 1/31/20.
//  Copyright © 2020 yalantis. All rights reserved.
//

import UIKit

final class DayData {
    
    let date: Date
    let inFuture: Bool
    
    var rect: CGRect = .zero
    var view: DayView? = nil
    var canSelect: Bool { state != .out && indicator != .disabled }
    var isSelected: Bool { indicator == .selected }
    var events = [CalendarEvent]()
    
    private(set) var state: DayState
    private(set) var indicator: DayIndicator
    
    public var isWeeklyStart: Bool = false
    public var isWeeklyEnd: Bool = false
    public var isInWeeklyRange: Bool = false

    init(date: Date, inFuture: Bool, state: DayState, indicator: DayIndicator) {
        self.date = date
        self.inFuture = inFuture
        self.state = state
        self.indicator = indicator
    }
    
    func select() {
        indicator = indicator == .selected ? .none : .selected
    }
    
    func startRange() {
        indicator = .startRange
    }
    
    func fillStartRange() {
        indicator = .startRangeFilled
    }
    
    func endRange() {
        indicator = .endRange
    }
    
    func setInRange() {
        indicator = .inRange
    }
    
    func setDisabled() {
        indicator = .disabled
    }
    
    func resetIndicator() {
        indicator = .none
    }
    
    func setInWeeklyRange() {
        self.indicator = .none
        self.isInWeeklyRange = true
    }

    public func resetWeeklyIndicators() {
        self.indicator = .none
        isWeeklyStart = false
        isWeeklyEnd = false
        isInWeeklyRange = false
    }
}
