//
//  Date+Display.swift
//
//  Created by Leo Shimonaka on 2/29/24.
//

import Foundation

extension Date {
    
    func asDateTimeString() -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: self)
    }

    func asDateString() -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateStyle = .short
        df.timeStyle = .none
        return df.string(from: self)
    }

}
