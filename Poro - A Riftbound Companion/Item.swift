//
//  Item.swift
//  Poro - A Riftbound Companion
//
//  Created by Bruno Ferreira on 17/02/2026.
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
