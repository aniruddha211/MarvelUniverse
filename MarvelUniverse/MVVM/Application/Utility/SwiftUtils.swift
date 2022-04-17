//
//  SwiftUtils.swift
//  MarvelUniverse
//
//  Created by Aniruddha Kadam on 17/04/22.
//

import Foundation


//MARK:- String extensions
extension String {
    
    var localized: String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "")
    }
    
    func localized(withComment comment:String) -> String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: comment)
    }
    
}


extension Data {
    
    func convertToDict() -> AnyObject? {
        
        do {
            let message = try JSONSerialization.jsonObject(with: self, options:.mutableContainers)
            if let jsonResult = message as? [AnyObject] {
                return jsonResult as AnyObject //Will return the json array output
                
            } else if let jsonResult = message as? [NSObject: AnyObject] {
                return jsonResult as AnyObject //Will return the json dictionary output
                
            } else {
                return nil
            }
        } catch let error as NSError {
            print("An data parsing error occurred: \(error)")
            return nil
        }
    }
}
