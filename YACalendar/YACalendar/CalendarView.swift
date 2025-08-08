//
//  CalendarView.swift
//  YALCalendar
//
//  Created by Vodolazkyi Anton on 1/31/20.
//  Copyright © 2020 yalantis. All rights reserved.
//

import UIKit

@objc
public protocol CalendarViewDelegate: class {
    @objc optional func didSelectDate(_ date: Date)
    @objc optional func didSelectRange(_ startDate: Date, endDate: Date)
    @objc optional func didUpdateDisplayedDate(_ date: Date)
    @objc optional func didChangeOrientation(_ isPortrait: Bool)
}

public class CalendarView: UIView {
    
    public final class Config {
        public var month = MonthConfig()
        public var day = DayConfig()
        public var monthTitle = MonthHeaderConfig()
        public var yearHeader = YearHeaderConfig()
        public var daySymbols = DaySymbolsConfig()
    }
    
    // MARK: - Properties
    
    public var selectionType: SelectionType = .one
    public var config: Config = Config()
    public var currentDate: Date = Date()
    public var maxRangeSelectionDays: Int = 50
    
    public var isPagingEnabled: Bool {
        get {
            return scrollView.isPagingEnabled
        } set {
            scrollView.isPagingEnabled = newValue
        }
    }
    
    public weak var calendarDelegate: CalendarViewDelegate?
    
//    public var data: CalendarData? {
//        didSet {
//            guard let data = data else { return }
//            let calendar = Calendar.current
//            let today = calendar.startOfDay(for: currentDate)
//
//            data.allDays.forEach { day in
//                switch selectionType {
//                case .one, .many, .range:
//                    // For single/multiple/range selection, just disable past dates
//                    if day.date < today {
//                        day.setDisabled()
//                    } else {
//                        day.resetIndicator()
//                    }
//
//                case .weeklyRange:
//                    // For weekly selection, enable only same weekday for next 50 days
//                    let todayWeekday = calendar.component(.weekday, from: today)
//                    guard let endDate = calendar.date(byAdding: .day, value: maxRangeSelectionDays, to: today) else { return }
//
//                    if day.date < today {
//                        day.setDisabled()
//                    } else {
//                        let dayWeekday = calendar.component(.weekday, from: day.date)
//                        if dayWeekday == todayWeekday && day.date <= endDate {
//                            day.resetIndicator()
//                        } else {
//                            day.setDisabled()
//                        }
//                    }
//                }
//            }
//            redraw()
//        }
//    }
    
    public var data: CalendarData? {
        didSet {
            guard let data = data else { return }
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: currentDate)

            data.allDays.forEach { day in
                switch selectionType {
                case .one, .many, .range:
                    if day.date < today {
                        day.setDisabled()
                    } else {
                        day.resetIndicator()
                    }

                case .weeklyRange:
                    let todayWeekday = calendar.component(.weekday, from: today)
                    guard let endDate = calendar.date(byAdding: .day, value: maxRangeSelectionDays, to: today) else { return }

                    if day.date < today {
                        day.setDisabled()
                    } else {
                        let dayWeekday = calendar.component(.weekday, from: day.date)
                        if dayWeekday == todayWeekday && day.date <= endDate {
                            day.resetIndicator()
                        } else {
                            day.setDisabled()
                        }
                    }
                }
            }

            // Default selection logic - modified to properly select current date
            switch selectionType {
            case .range:
                if let endDate = calendar.date(byAdding: .day, value: maxRangeSelectionDays, to: today) {
                    // Make sure we select the current date (today) as start
                    selectRange(with: today, endDate: endDate)
                    // Pass the next date after start and before end
//                    let nextStartDate = calendar.date(byAdding: .day, value: 1, to: today)!
//                    let nextEndDate = calendar.date(byAdding: .day, value: 1, to: endDate)!
                    calendarDelegate?.didSelectRange?(today, endDate: endDate)
//                    calendarDelegate?.didSelectRange?(startDate, endDate: endDate)
                }

            case .weeklyRange:
                guard let endDate = calendar.date(byAdding: .day, value: maxRangeSelectionDays, to: today) else { break }
                // Make sure we select the current week starting from today
                selectWeeklyRange(from: today, to: endDate)
//                let nextStartDate = calendar.date(byAdding: .day, value: 1, to: today)!
//                let nextEndDate = calendar.date(byAdding: .day, value: 1, to: endDate)!
                calendarDelegate?.didSelectRange?(today, endDate: endDate)
//                calendarDelegate?.didSelectRange?(startDate, endDate: endDate)

            case .one:
                // Select today for single selection mode
                if let todayDay = data.day(with: today) {
                    todayDay.select()
                    let nextStartDate = calendar.date(byAdding: .day, value: 1, to: today)!
                    calendarDelegate?.didSelectDate?(nextStartDate)
                }

            default:
                break
            }

            redraw()
        }
    }

    public var grid: Grid = Grid() {
        didSet { redraw() }
    }
    
    public private(set) var isPortrait = true {
        didSet {
            calendarDelegate?.didChangeOrientation?(isPortrait)
        }
    }
    
    private let scrollView = UIScrollView()
    private let daysSymbolsSeparatorView = UIView()

    private let daysStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fillEqually
        return stackView
    }()

    // MARK: - Initializers
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        initialize()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        initialize()
    }
    
    // MARK: - Public Methods
    
//    public func scroll(to date: Date) {
//        guard let data = data, let monthWithCurrentDate = data.monthData(with: date) else { return }
//
//        var origin: CGPoint
//
//        if grid.calendarType == .week {
//            let monthOrigin = monthWithCurrentDate.element.rect.origin
//            let weekOrigin = monthWithCurrentDate.element.weeks.first(where: {
//                $0.days.contains(where: { data.calendar.isDate($0.date, inSameDayAs: date) })
//            })?.rect.origin ?? .zero
//
//            origin = CGPoint(x: monthOrigin.x + weekOrigin.x, y: monthOrigin.y)
//        } else {
//            origin = grid.originForMonth(
//                with: monthWithCurrentDate.offset,
//                position: monthWithCurrentDate.element.gridPosition,
//                data: data,
//                yearNumber: monthWithCurrentDate.element.yearNumber,
//                showTitle: config.month.showTitle,
//                rectSize: scrollView.frame.size,
//                isPortrait: isPortrait,
//                showDaysOut: config.month.showDaysOut
//            )
//        }
//
//        if origin == .zero {
//            origin.x += 1
//        }
//        scrollView.contentOffset = origin
//    }
    
    public func scroll(to date: Date) {
        guard let data = data, let monthWithCurrentDate = data.monthData(with: date) else { return }
        
        // Make sure we use the start of day for comparison
        let startOfDay = data.calendar.startOfDay(for: date)
        
        var origin: CGPoint
        
        if grid.calendarType == .week {
            let monthOrigin = monthWithCurrentDate.element.rect.origin
            let weekOrigin = monthWithCurrentDate.element.weeks.first(where: {
                $0.days.contains(where: { data.calendar.isDate($0.date, inSameDayAs: startOfDay) })
            })?.rect.origin ?? .zero
            
            origin = CGPoint(x: monthOrigin.x + weekOrigin.x, y: monthOrigin.y)
        } else {
            origin = grid.originForMonth(
                with: monthWithCurrentDate.offset,
                position: monthWithCurrentDate.element.gridPosition,
                data: data,
                yearNumber: monthWithCurrentDate.element.yearNumber,
                showTitle: config.month.showTitle,
                rectSize: scrollView.frame.size,
                isPortrait: isPortrait,
                showDaysOut: config.month.showDaysOut
            )
        }

        if origin == .zero {
            origin.x += 1
        }
        scrollView.contentOffset = origin
    }
    
    public func selectDay(with date: Date) {
        guard let day = data?.day(with: date) else { return }
        
        day.select()
        
        if grid.calendarType == .oneOnOne {
            day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
        }
    }
    
    public func selectDays(with dates: [Date]) {
        let days = data?.allDays
            .filter { $0.canSelect }
            .filter { day in
                return dates.contains(where: { data?.isDate($0, inSameDayAs: day.date) == true })
            }
                    
        days?.forEach {
            $0.select()
            
            if grid.calendarType == .oneOnOne {
                $0.view?.configure(with: config.day, day: $0, calendarType: grid.calendarType)
            }
        }
    }
    
    public func disableDays(with dates: [Date]) {
        let days = data?.allDays
            .filter { $0.state != .out }
            .filter { day in
                return dates.contains(where: { data?.isDate($0, inSameDayAs: day.date) == true })
            }
                    
        days?.forEach {
            $0.setDisabled()
            
            if grid.calendarType == .oneOnOne {
                $0.view?.configure(with: config.day, day: $0, calendarType: grid.calendarType)
            }
        }
    }
    
    public func setEvents(_ events: [CalendarEvent]) {
        let days = data?.setEvents(events)
        days?.forEach { $0.view?.updateEventIndicator(with: config.day, day: $0) }
    }
    
    public func selectRange(with startDay: Date, endDate: Date) {
        let days = data?.allDays
            .filter { $0.canSelect }
            .filter { $0.date >= startDay && $0.date <= endDate }
            .sorted(by: { $0.date < $1.date })

        days?.enumerated().forEach {
            if $0.offset == 0 {
                $0.element.fillStartRange()
            } else if $0.offset == (days?.count ?? 0) - 1 {
                $0.element.endRange()
            } else {
                $0.element.setInRange()
            }
            
            if grid.calendarType == .oneOnOne {
                $0.element.view?.configure(with: config.day, day: $0.element, calendarType: grid.calendarType)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func initialize() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        addGestureRecognizer(tapGesture)
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
        addSubview(daysStackView)
        addSubview(daysSymbolsSeparatorView)
    }
    
    @objc
    private func redraw() {
        scrollView.frame.size = bounds.size
        
        if (grid.calendarType == .oneOnOne || grid.calendarType == .week) && config.daySymbols.isEnabled {
            scrollView.frame.origin.y = config.daySymbols.height
            daysStackView.isHidden = false
            daysSymbolsSeparatorView.isHidden = false
        } else {
            scrollView.frame.origin.y = 0
            daysStackView.isHidden = true
            daysSymbolsSeparatorView.isHidden = true
        }
        
        scrollView.delegate = nil
        scrollView.contentOffset = .zero
        scrollView.subviews.forEach { $0.removeFromSuperview() }
        
        data?.months.forEach {
            $0.view = nil
        }
        
        calculateMonths()
        calculateContentSize()
        scrollView.delegate = self
        animateTransition()
        scroll(to: currentDate)
        
        guard let data = data else { return }
        
        if config.daySymbols.isEnabled {
            let symbols = config.daySymbols.type.names(from: data.calendar)
            setDays(symbols)
        }
    }
    
    @objc
    private func orientationChanged() {
        guard UIDevice.current.orientation.isValidInterfaceOrientation else {
            return
        }
        
        let newOrientationPortait = UIDevice.current.orientation.isPortrait
        
        if newOrientationPortait != isPortrait {
            isPortrait = newOrientationPortait
            redraw()
        }
    }
    
    public func selectWeeklyRange(from startDate: Date, to endDate: Date) {
        guard let data = data else { return }

        let calendar = Calendar.current
        var current = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        let allDays = data.allDays

        // Reset all previous weekly indicators
        allDays.forEach {
            if $0.canSelect {
                $0.resetIndicator()
                $0.isWeeklyStart = false
                $0.isWeeklyEnd = false
                $0.isInWeeklyRange = false
                $0.view?.configure(with: config.day, day: $0, calendarType: grid.calendarType)
            }
        }

        var selectedDates: [Date] = []

        while current <= end {
            selectedDates.append(current)
            current = calendar.date(byAdding: .day, value: 7, to: current)!
        }

        for (index, date) in selectedDates.enumerated() {
            guard let day = allDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) && $0.canSelect }) else { continue }

            if index == 0 {
                day.startRange()
                day.isWeeklyStart = true
            } else if index == selectedDates.count - 1 {
                day.endRange()
                day.isWeeklyEnd = true
            } else {
                day.setInWeeklyRange()
                day.isInWeeklyRange = true
            }

            day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
        }
    }
    
    @objc
    private func tapped(_ sender: UITapGestureRecognizer) {
        guard let data = data else { return }
        
        let tappedPoint = sender.location(in: scrollView)
        
        guard let tappedMonth = data.months.first(where: { $0.rect.contains(tappedPoint) }) else { return }
        
        if grid.calendarType == .oneOnOne || grid.calendarType == .week {
            let tappedPointInMonth = sender.location(in: tappedMonth.view)
            let tappedWeek = tappedMonth.weeks.first(where: { $0.rect.contains(tappedPointInMonth) })
            let tappedPointInWeek = sender.location(in: tappedWeek?.view)
            
            var selectedDay = tappedWeek?.days.first(where: { $0.rect.contains(tappedPointInWeek) })
            
            if selectedDay == nil {
                var currentDiff: CGFloat = abs(tappedPointInWeek.x - (tappedWeek?.days.first?.rect.midX ?? 0))
                selectedDay = tappedWeek?.days.first
                
                for day in (tappedWeek?.days ?? []) {
                    let diff = abs(tappedPointInWeek.x - day.rect.midX)
                    
                    if diff < currentDiff {
                        currentDiff = diff
                        selectedDay = day
                    }
                }
            }
            
            guard let day = selectedDay, day.canSelect else { return }
            
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: currentDate)
            let tappedDate = calendar.startOfDay(for: day.date)
            
            // Common function to disable past dates
            func disablePastDates() {
                data.allDays
                    .filter { $0.date < today }
                    .forEach { day in
                        day.setDisabled()
                        day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
                    }
            }
            
            switch selectionType {
            case .one:
                let allSelectedDays = data.allDays.filter { $0.isSelected }
                
                allSelectedDays.forEach { data in
                    data.select()
                    data.view?.configure(with: config.day, day: data, calendarType: grid.calendarType)
                }
                
                disablePastDates()
                
                day.select()
                day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
                calendarDelegate?.didSelectDate?(day.date)
                
            case .range:
                let allDays = data.allDays
                
                if allDays.contains(where: { $0.indicator == .startRange || $0.indicator == .startRangeFilled }) == false {
                    // First selection - set start date
                    day.startRange()
                    day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
                } else if allDays.contains(where: { $0.indicator == .endRange }) == false {
                    // Second selection - set end date
                    guard let startRangeDay = allDays.first(where: { $0.indicator == .startRange }) else { return }
                    
                    let components = calendar.dateComponents([.day], from: startRangeDay.date, to: day.date)
                    let daysDifference = abs(components.day ?? 0)
                    
                    if day.date <= startRangeDay.date {
                        // If selected date is before start date, reset and make this new start
                        startRangeDay.resetIndicator()
                        startRangeDay.view?.configure(with: config.day, day: startRangeDay, calendarType: grid.calendarType)
                        
                        day.startRange()
                        day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
                    } else {
                        // Calculate the maximum allowed end date (start date + 50 days)
                        let maxEndDate = calendar.date(byAdding: .day, value: maxRangeSelectionDays, to: startRangeDay.date)!
                        let endDate = min(day.date, maxEndDate)
                        
                        // Find the day view for the end date
                        guard let endDay = allDays.first(where: { data.calendar.isDate($0.date, inSameDayAs: endDate) }) else { return }
                        
                        // Update the range visualization
                        startRangeDay.fillStartRange()
                        startRangeDay.view?.configure(with: config.day, day: startRangeDay, calendarType: grid.calendarType)
                        
                        endDay.endRange()
                        endDay.view?.configure(with: config.day, day: endDay, calendarType: grid.calendarType)
                        
                        // Select all days in between
                        let inRangeDays = allDays.filter {
                            $0.date > startRangeDay.date &&
                            $0.date < endDate &&
                            $0.canSelect
                        }
                        
                        inRangeDays.forEach { day in
                            day.setInRange()
                            day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
                        }
                        
                        // Pass the next date after start and before end
//                        let nextStartDate = calendar.date(byAdding: .day, value: 1, to: startRangeDay.date)!
//                        let nextEndDate = calendar.date(byAdding: .day, value: 1, to: endDate)!
                        calendarDelegate?.didSelectRange?(startRangeDay.date, endDate: endDate)
                        
                        // Show feedback if range was limited
                        if day.date != endDate {
                            UIView.animate(withDuration: 0.1, animations: {
                                endDay.view?.transform = CGAffineTransform(translationX: 10, y: 0)
                            }) { _ in
                                UIView.animate(withDuration: 0.1, animations: {
                                    endDay.view?.transform = CGAffineTransform(translationX: -10, y: 0)
                                }) { _ in
                                    UIView.animate(withDuration: 0.1) {
                                        endDay.view?.transform = .identity
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Reset all selectable days
                    allDays.forEach { day in
                        if day.canSelect {
                            day.resetIndicator()
                            day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
                        }
                    }

                    disablePastDates()

                    // Start new range
                    day.startRange()
                    day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
                }
                
//            case .weekly:
//                guard tappedDate >= today else { return } // Prevent selecting past
//
//                let tappedWeekday = calendar.component(.weekday, from: tappedDate)
//                let month = calendar.component(.month, from: tappedDate)
//                let year = calendar.component(.year, from: tappedDate)
//
//                // Reset previously selected days
//                data.allDays.forEach { d in
//                    if d.isSelected || d.indicator != .none {
//                        d.resetIndicator()
//                        d.view?.configure(with: config.day, day: d, calendarType: grid.calendarType)
//                    }
//                }
//
//                // Select days on same weekday from tapped date till 50 days in future
//                var selectedDates: [Date] = []
//                var current = tappedDate
//                let maxDate = calendar.date(byAdding: .day, value: 50, to: today)!
//
//                while current <= maxDate {
//                    let currentWeekday = calendar.component(.weekday, from: current)
//                    if currentWeekday == tappedWeekday {
//                        selectedDates.append(current)
//                    }
//                    current = calendar.date(byAdding: .day, value: 1, to: current)!
//                }
//
//                // Filter valid selectable days from the calendar
//                let selectedDays = data.allDays.filter { day in
//                    selectedDates.contains(where: { calendar.isDate(day.date, inSameDayAs: $0) }) && day.canSelect
//                }
//
//                disablePastDates()
//
//                selectedDays.forEach { day in
//                    day.select()
//                    day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
//                }
//
//                if let first = selectedDays.first, let last = selectedDays.last {
//                    calendarDelegate?.didSelectRange?(first.date, endDate: last.date)
//                }
                
//            case .weeklyRange:
//                let calendar = Calendar.current
//                let tappedDate = day.date
//
//                // Clear previous selections
//                day.resetIndicator()
//
//                // Select 7-day range
//                if let endDate = calendar.date(byAdding: .day, value: 6, to: tappedDate) {
//                    selectRange(with: tappedDate, endDate: endDate)
//                    calendarDelegate?.didSelectRange?(tappedDate, endDate: endDate)
//                }
//
//                disablePastDates()
                
            case .weeklyRange:
                let allDays = data.allDays

                let calendar = data.calendar
                let selectedDate = day.date

                // Find current start range day (if any)
                let currentStartDay = allDays.first(where: { $0.isWeeklyStart })

                func weeklyDates(from startDate: Date, to endDate: Date) -> [Date] {
                    guard startDate <= endDate else { return [] }

                    var result: [Date] = []
                    var current = startDate
                    while current <= endDate {
                        result.append(current)
                        current = calendar.date(byAdding: .day, value: 7, to: current)!
                    }
                    return result
                }

                func clearAllWeeklySelections() {
                    for d in allDays where d.canSelect {
                        d.resetIndicator()
                        d.isWeeklyStart = false
                        d.isWeeklyEnd = false
                        d.isInWeeklyRange = false
                        d.view?.configure(with: config.day, day: d, calendarType: grid.calendarType)
                    }
                }

                if let startDay = currentStartDay {
                    let daysBetween = calendar.dateComponents([.day], from: startDay.date, to: selectedDate).day ?? 0

                    if calendar.isDate(startDay.date, inSameDayAs: selectedDate) {
                        // Same day tapped again, do nothing or reset
                        return
                    } else if selectedDate > startDay.date, daysBetween % 7 == 0 {
                        // Valid end date
                        clearAllWeeklySelections()

                        let datesInRange = weeklyDates(from: startDay.date, to: selectedDate)
                        for date in datesInRange {
                            if let d = allDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                                if date == startDay.date {
                                    d.startRange()
                                    d.isWeeklyStart = true
                                } else if date == selectedDate {
                                    d.endRange()
                                    d.isWeeklyEnd = true
                                } else {
                                    d.setInWeeklyRange()
                                    d.isInWeeklyRange = true
                                }

                                d.view?.configure(with: config.day, day: d, calendarType: grid.calendarType)
                            }
                        }

                        // Pass the next date after start and before end
//                        let nextStartDate = calendar.date(byAdding: .day, value: 1, to: startDay.date)!
//                        let nextEndDate = calendar.date(byAdding: .day, value: 1, to: selectedDate)!
                        calendarDelegate?.didSelectRange?(startDay.date, endDate: selectedDate)

                    } else {
                        // Invalid selection → reset and start new range
                        clearAllWeeklySelections()
                        day.startRange()
                        day.isWeeklyStart = true
                        day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
                    }

                } else {
                    // No start yet → select start
                    day.startRange()
                    day.isWeeklyStart = true
                    day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
                }


            case .many:
                day.select()
                day.view?.configure(with: config.day, day: day, calendarType: grid.calendarType)
                calendarDelegate?.didSelectDate?(day.date)
            }
        } else {
            calendarDelegate?.didSelectDate?(tappedMonth.startMonthDate)
        }
    }

    private func calculateMonths() {
        guard let data = data else { return }
        
        var column = 0
        var row = 0
        
        for month in data.months.enumerated() {
            // Months Calculation
            let isLastInRow = month.offset != 0 && column == grid.calendarType.matrix(isPortait: isPortrait).columns - 1
            
            if isLastInRow || (month.element.isFirstMonthInYear && month.offset != 0) {
                row += 1
                column = 0
            } else if month.offset != 0 {
                column += 1
            }
            
            let position = GridPostion(row: row, column: column)
            let monthRect = grid.monthRect(
                for: month.offset,
                data: data,
                position: position,
                showTitle: config.month.showTitle,
                yearNumber: month.element.yearNumber,
                rectSize: scrollView.frame.size,
                isPortrait: isPortrait,
                previousMonthMaxX: month.offset == 0 ? 0 : data.months[month.offset - 1].rect.maxX,
                showDaysOut: config.month.showDaysOut
            )
            month.element.gridPosition = position
            month.element.rect = monthRect
            
            for week in month.element.weeks.enumerated() where week.offset <= month.element.numberOfWeeks - 1 || config.month.showDaysOut {
                // Weeks Calculation
                let weekRect: CGRect
                
                if grid.calendarType == .week {
                    weekRect = grid.weekRectForWeekView(
                        monthData: month.element,
                        weekIndex: week.offset,
                        screenWidth: scrollView.frame.size.width,
                        previousWeekEndX: week.offset == 0 ? 0.0 : month.element.weeks[week.offset - 1].rect.maxX
                    )
                } else {
                    weekRect = grid.weekRect(for: week.offset, showTitle: config.month.showTitle, rect: monthRect)
                }
                week.element.rect = weekRect
                
                let days = grid.calendarType == .week ? week.element.days.filter { $0.state != .out } : week.element.days
                
                for day in days.enumerated() {
                    // Days Calculation
                    if grid.calendarType == .week {
                        if day.element.state == .out {
                            continue
                        }
                        day.element.rect = grid.dayRectForWeekView(
                            for: day.offset,
                            weekRect: weekRect,
                            screenWidth: scrollView.frame.size.width
                        )
                    } else {
                        day.element.rect = grid.dayRect(
                            for: day.offset,
                            weekRect: weekRect
                        )
                    }
                }
            }
        }
    }
    
    private func drawVisibleMonths(visibleRect: CGRect) {
        for monthData in (data?.months ?? []) where monthData.view == nil && monthData.rect.intersects(visibleRect) {
            
            let monthView = UIView(frame: monthData.rect)
            scrollView.addSubview(monthView)
            monthData.view = monthView
            
            if monthData.isFirstMonthInYear && grid.calendarType != .oneOnOne && grid.scrollDirection == .vertical {
                let yearHeaderViewRect = grid.yearHeaderRect(monthRect: monthData.rect, containerRect: frame)
                let yearHeaderView = YearHeaderView(frame: yearHeaderViewRect)
                yearHeaderView.configure(
                    
                    with: config.yearHeader,
                    isCurrentYear: monthData.isCurrentYear,
                    yearDate: monthData.startMonthDate,
                    calendarType: grid.calendarType
                )
                scrollView.addSubview(yearHeaderView)
            }
            
            if config.month.showTitle {
                let monthHeaderView = MonthHeaderView(frame: grid.monthHeaderRect(monthWidth: monthData.rect.width))
                monthHeaderView.configure(with: config.monthTitle, monthData: monthData, calendarType: grid.calendarType)
                monthView.addSubview(monthHeaderView)
            }
            
            monthData.weeks.forEach { week in
                guard week.rect != .zero else { return }

                let weekView = UIView(frame: week.rect)
                week.view = weekView
                monthView.addSubview(weekView)

                week.days.forEach { day in
                    if config.month.showDaysOut || monthData.containsDate(day.date) {
                        let dayView = DayView(frame: day.rect)
                        day.view = dayView
                        dayView.configure(with: config.day, day: day, calendarType: grid.calendarType)
                        weekView.addSubview(dayView)
                    }
                }
            }
        }
        
        if let month = data?.months
            .sorted(by: { $0.rect.origin.x < $1.rect.origin.x })
            .first(where: { $0.rect.intersects(visibleRect) }) {
            calendarDelegate?.didUpdateDisplayedDate?(month.startMonthDate)
        }
    }
    
    private func calculateContentSize() {
        guard let data = data else {
            scrollView.contentSize = .zero
            return
        }
        
        let gridSize = grid.contentSize(
            for: data,
            rectSize: scrollView.frame.size,
            showTitle: config.month.showTitle,
            isPortrait: isPortrait,
            showDaysOut: config.month.showDaysOut
        )
        scrollView.contentSize = gridSize
    }
    
    private func setDays(_ days: [String]) {
        daysStackView.arrangedSubviews.forEach {
            daysStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
                
        for day in days {
            let label = UILabel()
            label.text = day.uppercased()
            label.font = config.daySymbols.font
            label.textColor = config.daySymbols.textColor
            label.textAlignment = config.daySymbols.textAlignment
            daysStackView.addArrangedSubview(label)
        }
        
        var inset: CGFloat = 0.0
        
        if grid.calendarType == .oneOnOne {
            inset = (scrollView.frame.width - (CGFloat(grid.calendarType.matrix(isPortait: isPortrait).columns) * grid.calendarType.monthSize(showTitle: config.month.showTitle).width)) / 2
        } else {
            inset = 0
        }
        daysStackView.frame.origin.x = inset
        daysStackView.frame.size = CGSize(width: frame.width - (inset * 2), height: config.daySymbols.height)
        daysSymbolsSeparatorView.frame = CGRect(x: 0, y: daysStackView.frame.maxY, width: scrollView.frame.width, height: 1)
        daysSymbolsSeparatorView.backgroundColor = config.daySymbols.separatorColor
    }
    
    private func animateTransition() {
        let transition = CATransition()
        transition.duration = 0.2
        transition.timingFunction = CAMediaTimingFunction(name: .easeIn)
        transition.type = .fade
        layer.add(transition, forKey: nil)
    }
}

extension CalendarView: UIScrollViewDelegate {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let visibleRect = CGRect(origin: scrollView.contentOffset, size: scrollView.frame.size)
        drawVisibleMonths(visibleRect: visibleRect)
    }
}
