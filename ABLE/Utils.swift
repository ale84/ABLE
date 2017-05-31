//
//  Utils.swift
//  Cinello
//
//  Created by Alessio Orlando on 08/03/16.
//  Copyright © 2016 Cinello. All rights reserved.
//

import Foundation

/// Delays the execution of a given closure.
///
/// - Parameters:
///   - delay: Delay time in seconds.
///   - closure: A closure.
func delay(_ delay:Double, closure:@escaping ()->()) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}
