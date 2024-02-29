//
//  Date+Display.swift
//
//  Created by Leo Shimonaka on 2/29/24.
//

import Foundation

extension Date {
    
    func stringForDisplay() -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: self)
    }
    
}
