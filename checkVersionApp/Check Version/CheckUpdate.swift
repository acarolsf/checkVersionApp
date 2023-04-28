//
//  CheckUpdate.swift
//  checkVersionApp
//
//  Created by Ana Carolina Ferreira on 27/04/23.
//

import Foundation
import UIKit

enum VersionError: Error {
    case invalidBundleInfo, invalidResponse, dataError
}

struct LookupResult: Decodable {
    let data: [TestFlightInfo]?
    let results: [AppInfo]?
}

struct TestFlightInfo: Decodable {
    let type: String
    let attributes: Attributes
}

struct Attributes: Decodable {
    let version: String
    let expired: String
}

struct AppInfo: Decodable {
    let version: String
    let trackViewUrl: String
}

class CheckUpdate: NSObject {

    static let shared = CheckUpdate()
    var isTestFlight: Bool = false

    private let appStoreId = "6446998023" // Id Example
    
    func showUpdate(withConfirmation: Bool, isTestFlight: Bool) {
        self.isTestFlight = isTestFlight
        DispatchQueue.global().async {
            self.checkVersion(force : !withConfirmation)
        }
    }

    private  func checkVersion(force: Bool) {
        if let currentVersion = self.getBundle(key: "CFBundleShortVersionString") {
            _ = getAppInfo { (data, info, error) in
                
                let store = self .isTestFlight ? "TestFlight" : "AppStore"
                
                if let error = error {
                    print("error getting app \(store) version: ", error)
                }
                
                if let appStoreAppVersion = info?.version {
                    if appStoreAppVersion <= currentVersion {
                        print("Already on the last app version: ", currentVersion)
                    } else {
                        print("Needs update: \(store) Version: \(appStoreAppVersion) > Current version: ", currentVersion)
                        DispatchQueue.main.async {
                            let topController: UIViewController = (UIApplication.shared.windows.first?.rootViewController)!
                            topController.showAppUpdateAlert(version: appStoreAppVersion, force: force, appURL: (info?.trackViewUrl)!, isTestFlight: self.isTestFlight)
                        }
                    }
                } else if let testFlightAppVersion = data?.attributes.version {
                    if testFlightAppVersion <= currentVersion {
                        print("Already on the last app version: ",currentVersion)
                    } else {
                        print("Needs update: \(store) Version: \(testFlightAppVersion) > Current version: ", currentVersion)
                        DispatchQueue.main.async {
                            let topController: UIViewController = (UIApplication.shared.windows.first?.rootViewController)!
                            topController.showAppUpdateAlert(version: testFlightAppVersion, force: force, appURL: (info?.trackViewUrl)!, isTestFlight: self.isTestFlight)
                        }
                    }
                } else {
                    print("App does not exist on \(store)")
                }
            }
        }
    }
    
    private func getUrl(from identifier: String) -> String {
        // You should pay attention on the country that your app is located, in my case I put Brazil */br/*
        // Você deve prestar atenção em que país o app está disponível, no meu caso eu coloquei Brasil */br/*
        let testflightURL = "https://api.appstoreconnect.apple.com/v1/apps/\(self.appStoreId)/builds"
        let appStoreURL = "http://itunes.apple.com/br/lookup?bundleId=\(identifier)"

        return isTestFlight ? testflightURL : appStoreURL
    }

    private func getAppInfo(completion: @escaping (TestFlightInfo?, AppInfo?, Error?) -> Void) -> URLSessionDataTask? {
    
      // You should pay attention on the country that your app is located, in my case I put Brazil */br/*
      // Você deve prestar atenção em que país o app está disponível, no meu caso eu coloquei Brasil */br/*
      
        guard let identifier = self.getBundle(key: "CFBundleIdentifier"),
              let url = URL(string: getUrl(from: identifier)) else {
                DispatchQueue.main.async {
                    completion(nil, nil, VersionError.invalidBundleInfo)
                }
                return nil
        }
        
        // You need to generate an authorization token to access the TestFlight versions and then you replace the ```***``` with the JWT token.
        // Você precisa gerar um token de autorização para acessar as versões de TestFlight e depois você substitui o ```***``` com o token JWT gerado.
        // https://developer.apple.com/documentation/appstoreconnectapi/generating_tokens_for_api_requests
        
        let authorization = "Bearer ***"
        
        var request = URLRequest(url: url)
        
        // You just need to add an authorization header if you are checking TestFlight version
        // Você só precisa adicionar uma autorização no header se você está checando a versão de testflight
        if self.isTestFlight {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            self.debug(request, nil, response, error, data)
                do {
                    if let error = error { throw error }
                    guard let data = data else { throw VersionError.invalidResponse }
                    
                    let result = try JSONDecoder().decode(LookupResult.self, from: data)
                    print(result)
                    
                    if self.isTestFlight {
                        let info = result.data?.first
                        completion(info, nil, nil)
                    } else {
                        let info = result.results?.first
                        completion(nil, info, nil)
                    }

                } catch {
                    completion(nil, nil, error)
                }
            }
        
        task.resume()
        return task

    }

    func getBundle(key: String) -> String? {

        guard let filePath = Bundle.main.path(forResource: "Info", ofType: "plist") else {
          fatalError("Couldn't find file 'Info.plist'.")
        }
        // 2 - Add the file to a dictionary
        let plist = NSDictionary(contentsOfFile: filePath)
        // Check if the variable on plist exists
        guard let value = plist?.object(forKey: key) as? String else {
          fatalError("Couldn't find key '\(key)' in 'Info.plist'.")
        }
        return value
    }
}

extension CheckUpdate {
    func debug(_ request: URLRequest, _ httpBody: Data?, _ response: URLResponse?, _ error: Error?, _ data: Data?) {
        #if DEBUG
        let line = "--------------------------------------------------------------------------------"

        print(line); print(); defer { print(line); print() }

        print(request.curlString)
        print()

        if request.httpMethod != "GET" {
            if let httpBody = httpBody, let requestData = String(data: httpBody, encoding: String.Encoding.utf8) {
                print("Request body: \(String(describing: requestData))")
                print()
            }
        }

        if let response = response {
            print("Response: \(response)")
            print()
        }

        if let error = error {
            print("Errors: \(error)")
            print()
        }
        else {
            if let data = data, let responseData = String(data: data, encoding: String.Encoding.utf8) {
                print("Response body: \(responseData)")
                print()
            }
        }
        #endif
    }
}

extension UIViewController {
    @objc fileprivate func showAppUpdateAlert(version : String, force: Bool, appURL: String, isTestFlight: Bool) {
        guard let appName = CheckUpdate.shared.getBundle(key: "CFBundleName") else { return } //Bundle.appName()

        let alertTitle = "New version"
        let alertMessage = "A new version of \(appName) is available on \(isTestFlight ? "TestFlight" : "AppStore"). Update now!"

        let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)

        if !force {
            let notNowButton = UIAlertAction(title: "Not now", style: .default)
            alertController.addAction(notNowButton)
        }

        let updateButton = UIAlertAction(title: "Update", style: .default) { (action:UIAlertAction) in
            guard let url = URL(string: appURL) else {
                return
            }
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.openURL(url)
            }
        }

        alertController.addAction(updateButton)
        self.present(alertController, animated: true, completion: nil)
    }
}


extension URLRequest {
    var curlString: String {
        guard let url = url else {
            return ""
        }

        var baseCommand = "curl \(url.absoluteString)"

        if httpMethod == "HEAD" {
            baseCommand += " --head"
        }

        var command = [baseCommand]

        if let method = httpMethod, method != "GET" && method != "HEAD" {
            command.append("-X \(method)")
        }

        if let headers = allHTTPHeaderFields {
            for (key, value) in headers where key != "Cookie" && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                command.append("-H '\(key): \(value)'")
            }
        }

        if let data = httpBody, let body = String(data: data, encoding: .utf8) {
            command.append("-d '\(body)'")
        }

        return command.joined(separator: " \\\n\t")
    }
}
