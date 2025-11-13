//
//  Item.swift
//  ForcingFunction
//
//  Created by Nilesh Kumar on 12/11/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
