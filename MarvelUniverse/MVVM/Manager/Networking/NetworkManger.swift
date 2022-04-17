//
//  NetworkManger.swift
//  MarvelUniverse
//
//  Created by Aniruddha Kadam on 17/04/22.
//

import Foundation

enum StatusCode {
    case Success
    case SuccessWithNoResponse
    case SuccessWithPartialInformation
    case SuccessWithAccepted
    case SuccessWithCreated
    
    case BadRequest
    case SlowNetConnection
    case NoNetConnection
    case Internal500
    case SessionExpire
    
    var value: Int {
        switch self {
        case .Success: return 200
        case .SuccessWithNoResponse: return 204
        case .SuccessWithPartialInformation: return 203
        case .SuccessWithAccepted: return 202
        case .SuccessWithCreated: return 201
            
        case .SlowNetConnection: return -1001
        case .NoNetConnection: return -1009
        case .BadRequest: return 400
        case .Internal500: return 500
        case .SessionExpire: return 123
        }
    }
}

enum MethodType {
    
    case GET
    case POST
    case PUT
    case DELETE
    
    var type: String {
        switch self {
        case .GET: return "GET";
        case .POST: return "POST";
        case .PUT: return "PUT";
        case .DELETE: return "DELETE";
        }
    }
}

@objc class NetworkRequestConfiguration: NSObject {
    var methodType: MethodType = .GET
    @objc var methodTypeValue: String = "" {
        didSet {
            switch methodTypeValue {
            case MethodType.GET.type:
                methodType = .GET
            case MethodType.DELETE.type:
                methodType = .DELETE
            case MethodType.POST.type:
                methodType = .POST
            case MethodType.PUT.type:
                methodType = .PUT
            default: break
            }
        }
    }
    @objc var urlString: String = ""
    @objc var postBody: Data?
    @objc var additionalHeader = [String: AnyObject]()
    @objc var completeUrlString: String = ""
    
    override init() {
        super.init()
        
    }
    
    convenience init(withMethodType type: MethodType, urlString ulrStr: String) {
        self.init()
        self.methodType = type
        self.urlString = ulrStr
    }
}

final class RCNetworkManager: NSObject {
    
    var timeInterval: TimeInterval = 45
    var operationQueue = OperationQueue()
    var showLog: Bool = true
    private let configuration = URLSessionConfiguration.default
    private var session: URLSession?
    
    @objc static let sharedInstance : RCNetworkManager = {
        let instance = RCNetworkManager()
        return instance
    }()
    
    override init() {
        super.init()
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)
    }
    
    @objc func apiRequest(withConfigurations requestConfig: NetworkRequestConfiguration, completion: @escaping ((_ success: Bool, _ response: AnyObject?, _ error: ErrorUtil?)->Void)) {
        
        if Constants.appDelegate.internetReach.currentReachabilityStatus() == NotReachable {
            //no internet connection
            let noInternetConnection: [String: Any] = ["errorCode": -1, "errorMessage": "NETWORK_UNAVAILABLE_NO_INTERNET_CONNECTION".localized]
            let errorUtill = ErrorUtil(withDataDictionary: noInternetConnection)
            completion(false, nil, errorUtill);
            
        } else {
            if var request = urlRequest(forRequestConfiguration: requestConfig) {
                request.timeoutInterval = 30
                session?.dataTask(with: request, completionHandler: { (data, response, error) in
                    var responseObject: AnyObject?
                    var isSuccess = false
                    var errorUtil: ErrorUtil?
                    
                    //Check HTTP Response for successful request
                    guard let httpResponse = response as? HTTPURLResponse, let receivedData = data else {
                        completion(false, nil, nil)
                        return
                    }
  
                   
                    switch (httpResponse.statusCode) {
                        
                    case StatusCode.Success.value,
                         StatusCode.SuccessWithNoResponse.value,
                         StatusCode.SuccessWithPartialInformation.value,
                         StatusCode.SuccessWithAccepted.value,
                         StatusCode.SuccessWithCreated.value:
                        
                        if let responseString = String(data: receivedData, encoding: .utf8) {
                            
                            isSuccess = true
                            
                            if responseString.count > 0 {
                                if let thisDict = data?.convertToDict() {
                                    responseObject = thisDict
                                } else {
                                    responseObject = responseString as NSString
                                }
                            }
                        }
                        
                    case StatusCode.BadRequest.value:
                        isSuccess = false
                        if self.showLog {
                            print("URL: \(requestConfig.completeUrlString) \nType : \(requestConfig.methodType.type) \nErrorStatusCode: \(httpResponse.statusCode)")
                        }
                        
                        
                    case StatusCode.NoNetConnection.value:
                        isSuccess = false
                        let noInternetConnection: [String: Any] = ["errorCode": -1, "errorMessage": "NETWORK_UNAVAILABLE_NO_INTERNET_CONNECTION".localized]
                        errorUtil = ErrorUtil(withDataDictionary: noInternetConnection)
                        
                        
                    case StatusCode.Internal500.value:
                        isSuccess = false
                        if let thisDict = data?.convertToDict() as? [String: Any] {
                            errorUtil = ErrorUtil(withDataDictionary: thisDict)
                            
                            if errorUtil?.errorMessage == nil {
                                if let innerDict = thisDict["ConstraintViolationException"] as? [String : Any] {
                                    errorUtil = ErrorUtil(withDataDictionary: innerDict)
                                }
                            }
                        }
                        
                    default:
                        if self.showLog {
                            print("URL: \(requestConfig.completeUrlString) \nType : \(requestConfig.methodType.type) \nErrorStatusCode: \(httpResponse.statusCode)")
                        }
                        isSuccess = false
                        if let thisDict = data?.convertToDict() as? [String: Any] {
                            errorUtil = ErrorUtil(withDataDictionary: thisDict)
                        }
                    }
                    
                    if let responseString = String(data: receivedData, encoding: .utf8) {
                        
                        if self.showLog {
                            print(String(format:"RequestUrl : %@\nResponse : %@", requestConfig.completeUrlString, responseString))
                        }
                    }
                    
                    completion(isSuccess, responseObject, errorUtil);
                }).resume()
            }
        }
    }
    
    @objc func requestWithConfig(_ config: NetworkRequestConfiguration, completion: @escaping ((Data?, HTTPURLResponse?, ErrorUtil?) -> Void)) {
        
        if Constants.appDelegate.internetReach.currentReachabilityStatus() == NotReachable {
            //no internet connection
            completion(nil, nil, ErrorUtil.noInternetError());
        } else {
            
            if let request = urlRequest(forRequestConfiguration: config) {
                
                session?.dataTask(with: request, completionHandler: { (data, response, error) in
                    
                    var errorUtil: ErrorUtil?
                    
                    //Check HTTP Response for successful request
                    guard let httpResponse = response as? HTTPURLResponse, let receivedData = data else {
                        
                        if let hasError = error {
                            print("error:  \(hasError.localizedDescription)")
                        }
                        
                        completion(nil, nil, errorUtil)
                        return
                    }
                    
                    if self.showLog {
                        print("URL: \(config.completeUrlString) \nType : \(config.methodType.type) \nStatusCode: \(httpResponse.statusCode)")
                        if let responseString = String(data: receivedData, encoding: .utf8) {
                            print("Response : \(responseString)")
                        }
                    }

                    if let thisDict = receivedData.convertToDict() as? [String: Any] {
                        errorUtil = ErrorUtil(withDataDictionary: thisDict)
                    }
                    
                    //return the completion handler
                    completion(receivedData, httpResponse, errorUtil);
                    
                }).resume()
            }
        }
    }
    
    @objc func downloadRequest(withConfigurations requestConfig: NetworkRequestConfiguration, completion: @escaping ((_ success: Bool, _ location: URL?, _ error: ErrorUtil?)->Void)) {
        if Constants.appDelegate.internetReach.currentReachabilityStatus() == NotReachable {
            
            //no internet connection
            let noInternetConnection: [String: Any] = ["errorCode": -1, "errorMessage": "NETWORK_UNAVAILABLE_NO_INTERNET_CONNECTION".localized]
            let errorUtill = ErrorUtil(withDataDictionary: noInternetConnection)
            completion(false, nil, errorUtill);
            
        } else {
            if let request = urlRequest(forRequestConfiguration: requestConfig) {
                session?.downloadTask(with: request) { (location, response, error) in
                    guard let httpResponse = response as? HTTPURLResponse else {
                        completion(false, nil, nil)
                        return
                    }
                    
                    var isSuccess: Bool = false
                    var errorUtil: ErrorUtil?
                    
                    switch (httpResponse.statusCode) {
                        
                    case StatusCode.Success.value,
                         StatusCode.SuccessWithNoResponse.value,
                         StatusCode.SuccessWithPartialInformation.value,
                         StatusCode.SuccessWithAccepted.value,
                         StatusCode.SuccessWithCreated.value:
                        
                        if location != nil {
                            isSuccess = true
                        }
                        
                    case StatusCode.BadRequest.value:
                        isSuccess = false
                        if self.showLog {
                            print("URL: \(requestConfig.completeUrlString) \nType : \(requestConfig.methodType.type) \nErrorStatusCode: \(httpResponse.statusCode)")
                        }
                        
                        
                    case StatusCode.NoNetConnection.value:
                        isSuccess = false
                        let noInternetConnection: [String: Any] = ["errorCode": -1, "errorMessage": "NETWORK_UNAVAILABLE_NO_INTERNET_CONNECTION".localized]
                        errorUtil = ErrorUtil(withDataDictionary: noInternetConnection)
                        
                    default:
                        if self.showLog {
                            print("URL: \(requestConfig.completeUrlString) \nType : \(requestConfig.methodType.type) \nErrorStatusCode: \(httpResponse.statusCode)")
                        }
                        isSuccess = false
                    }
                    completion(isSuccess, location, errorUtil)
                    }.resume()
            }
        }
    }
    
    func urlRequest(forRequestConfiguration requestConfig: NetworkRequestConfiguration) -> URLRequest? {
            if requestConfig.urlString.starts(with: "https://") {
                requestConfig.completeUrlString = requestConfig.urlString
            } else {
                requestConfig.completeUrlString = Constants.BASE_API_URL+"/"+requestConfig.urlString
            }
            if let thisUrlString = StringUtil.getEncodedUrl(requestConfig.completeUrlString), let url = URL(string: thisUrlString) {
                
                var request = URLRequest(url: url)
                
                request.httpMethod = requestConfig.methodType.type
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")

                //setting additional headers
                for (_, key) in requestConfig.additionalHeader.keys.enumerated() {
                    if let thisString = requestConfig.additionalHeader[key] as? String {
                        request.setValue(thisString, forHTTPHeaderField: key)
                    }
                }
                
                //POST body handling
                if requestConfig.methodType == .POST || requestConfig.methodType == .PUT || requestConfig.methodType == .DELETE {
                    if let thisData = requestConfig.postBody {
                        request.httpBody = thisData
                    }
                }
                
                return request
            }
        return nil
    }

    
    private func cancelTasksByUrl(tasks: [URLSessionTask], url: String){
        for task in tasks{
            if let oldUrl = task.currentRequest?.url{
                if oldUrl.description.contains(url){
                    task.cancel()
                }
            }
        }
    }
    
    func cancelRequests(url: String){
        self.session?.getTasksWithCompletionHandler{
            (dataTasks, uploadTasks, downloadTasks) -> Void in
            self.cancelTasksByUrl(tasks: dataTasks     as [URLSessionTask], url: url)
            self.cancelTasksByUrl(tasks: uploadTasks   as [URLSessionTask], url: url)
            self.cancelTasksByUrl(tasks: downloadTasks as [URLSessionTask], url: url)
        }
    }
}

extension RCNetworkManager: URLSessionDelegate {
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        
        var disposition: URLSession.AuthChallengeDisposition = URLSession.AuthChallengeDisposition.performDefaultHandling
        var credential:URLCredential?
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            
            if let serverTrust = challenge.protectionSpace.serverTrust {
                credential = URLCredential(trust: serverTrust)
                disposition = URLSession.AuthChallengeDisposition.useCredential
            } else {
                disposition = URLSession.AuthChallengeDisposition.performDefaultHandling
            }
            
        } else {
            disposition = URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge
        }
        
        completionHandler(disposition, credential);
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        
    }
}

