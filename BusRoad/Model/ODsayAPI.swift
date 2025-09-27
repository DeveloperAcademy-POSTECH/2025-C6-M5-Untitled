import Foundation
import UIKit

class ViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
  }
}

func odsayAPI(apiKey: String, urlString: String, params: [String: Any], completion: @escaping (Bool, Any) -> Void) {
    guard let encodedApiKey = apiKey.addingPercentEncoding(withAllowedCharacters: .controlCharacters) else {
        print("Error: Failed to encode API key")
        completion(false, "Failed to encode API key")
        return
    }
    var queryParams = "apiKey=\(encodedApiKey)"
    for key in params.keys {
        guard let value = params[key] else { continue }
        if queryParams.isEmpty {
            queryParams = "\(key)=\(value)"
        } else {
            queryParams += "&\(key)=\(value)"
        }
    }
    let urlStr = "\(urlString)?\(queryParams)"
    guard let url = URL(string: urlStr) else {
        print("Error: Invalid URL string")
        completion(false, "Invalid URL string")
        return
    }
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpMethod = "GET"
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error: error calling GET")
            print(error)
            completion(false, error)
            return
        }
        guard let data = data else {
            print("Error: Did not receive data")
            completion(false, "Did not receive data")
            return
        }
        guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300) ~= httpResponse.statusCode else {
            print("Error: HTTP request failed")
            completion(false, data)
            return
        }
        completion(true, data)
    }.resume()
}
