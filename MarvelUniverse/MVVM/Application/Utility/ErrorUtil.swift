//
//  ErrorUtil.swift
//  MarvelUniverse
//
//  Created by Aniruddha Kadam on 17/04/22.
//

import Foundation

class ErrorUtil: NSObject {
     var errorCode: NSNumber?
     var errorMessage: String?
    
    override init(){
        super.init()
        
    }
    
    convenience init(withDataDictionary dictionary: [String: Any]) {
        self.init()
      //  self.setSafeValuesForKeysWith(dictionary)
    }
    
    class func noInternetError() -> ErrorUtil {
        return ErrorUtil(withDataDictionary: ["errorCode": -1, "errorMessage": "NETWORK_UNAVAILABLE_NO_INTERNET_CONNECTION".localized])
    }
}
