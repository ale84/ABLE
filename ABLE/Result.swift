//
//  Response.swift
//  Cinello
//
//  Created by Alessio Orlando on 29/10/15.
//  Copyright © 2015 Class. All rights reserved.
//

import Foundation
/**
 Represents a generic operation with success/failure status.
 
 - Success:  The operation succeded with the given result value
 - Failure:  The operation failed with the given error

 */
public enum Result <T>{
    case success (T)
    case failure (Error)
    
    public func map<P>(_ f: (T) -> P) -> Result<P> {
        switch self {
        case .success(let value):
            return .success(f(value))
        case .failure(let error):
            return .failure(error)
        }
    }
}

extension Result {
    var description: (T?, Error?) {
        switch self {
        case .success(let value):
            return (value, nil)
        case .failure(let error):
            return (nil, error)
        }
    }
}
