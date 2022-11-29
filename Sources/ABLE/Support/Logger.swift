//
//  Created by Alessio Orlando on 14/06/18.
//  Copyright (c) 2018 Alessio Orlando. All rights reserved.
//

import Foundation

public class Logger {
    public class func debug(_ message:String? = nil, function: String = #function, file: String = #file, line: Int = #line) {
#if DEBUG
        if let message = message {
            print("\(file):\(function):\(line): \(message)")
        } else {
            print("\(file):\(function):\(line)")
        }
#endif
    }

}
