//
//  Network.swift
//  DivaBot
//
//  Created by Shane Qi on 6/5/18.
//

import ZEGBot
import Foundation

private var transmissionSessionId = ""

func addTorrent(with torrentUrlString: String, completion: ((Result<TorrentAddResponse>) -> Void)?) {
	var urlRequest = URLRequest(url: URL(string:
		transmissionRPCScheme + transmissionRPCUsername + ":" + transmissionRPCPassword + "@"
			+ transmissionRPCHost + ":" + transmissionRPCPort + "/transmission/rpc")!)
	urlRequest.httpMethod = "POST"
	urlRequest.addValue(transmissionSessionId, forHTTPHeaderField: "X-Transmission-Session-Id")
	urlRequest.httpBody = """
		{
			"method": "torrent-add",
			"arguments": {
				"filename": "\(torrentUrlString)"
			}
		}
		""".data(using: .utf8)
	let urlSessionTask = URLSession(configuration: .default).dataTask(with: urlRequest) { data, response, error in
		let urlResponse = response as! HTTPURLResponse
		guard urlResponse.statusCode != 409 else {
			if let sessionId = urlResponse.allHeaderFields["X-Transmission-Session-Id"] as? String {
				transmissionSessionId = sessionId
				addTorrent(with: torrentUrlString, completion: completion)
			} else {
				completion?(.failure(Error.unknown))
			}
			return
		}
		if let data = data {
			do {
				completion?(.success(try JSONDecoder().decode(TorrentAddResponse.self, from: data)))
			} catch let decodingErorr {
				completion?(.failure(decodingErorr))
			}
		} else if let error = error {
			completion?(.failure(error))
		} else {
			completion?(.failure(Error.unknown))
		}
	}
	urlSessionTask.resume()
}

enum TorrentAddResponse: Decodable {

	case addedTorrent(name: String)
	case duplicatedTorrent(name: String)
	case failure(message: String)

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let resultMessage = try container.decode(String.self, forKey: .resultMessage)
		let argumentsContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .arguments)
		if argumentsContainer.contains(.addedTorrent) {
			self = .addedTorrent(name:
				try argumentsContainer.nestedContainer(keyedBy: CodingKeys.self, forKey: .addedTorrent)
					.decode(String.self, forKey: .name))
		} else if argumentsContainer.contains(.duplicatedTorrent) {
			self = .duplicatedTorrent(name:
				try argumentsContainer.nestedContainer(keyedBy: CodingKeys.self, forKey: .duplicatedTorrent)
					.decode(String.self, forKey: .name))
		} else {
			self = .failure(message: resultMessage)
		}
	}

	private enum CodingKeys: String, CodingKey {
		case resultMessage = "result"
		case arguments
		case addedTorrent = "torrent-added"
		case duplicatedTorrent = "torrent-duplicate"
		case name
	}

}

enum Error: Swift.Error {

	case stringDecoding(Data)
	case unknown

}

func refreshBlog() {
	var urlRequest = URLRequest(url: URL(string: "https://server.shaneqi.com/hooks/rusty_blog")!)
	urlRequest.httpMethod = "POST"
	let session = URLSession(configuration: URLSessionConfiguration.default)
	session.dataTask(with: urlRequest) { _, _, _ in }.resume()
}

func createAppCenterBuild(
	project: String, branch: String, commit: String, config: Data, completion: ((String) -> Void)?) {
	guard let encodedProject = project.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
		completion?("Failed to encode '\(project)'.")
		return
	}
	guard let encodedBranch = branch.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
		completion?("Failed to encode '\(branch)'.")
		return
	}
	var urlRequest = URLRequest(url: URL(
		string: "https://api.appcenter.ms/v0.1/apps/shaneqi/\(encodedProject)/branches/\(encodedBranch)/config")!)
	urlRequest.httpMethod = "PUT"
	urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
	urlRequest.addValue(appCenterApiToken, forHTTPHeaderField: "X-API-Token")
	urlRequest.httpBody = config
	let session = URLSession(configuration: URLSessionConfiguration.default)
	session.dataTask(with: urlRequest) { data, response, _ in
		let code = (response as? HTTPURLResponse)?.statusCode
		var responseString = [String]()
		if code == 200 {
			createAppCenterBuild(project: encodedProject, branch: encodedBranch, commit: commit, completion: completion)
		} else {
			if let code = code {
				responseString += ["\(code)"]
			} else {
				responseString += ["unknown status code"]
			}
			if let data = data, let body = String(data: data, encoding: .utf8) {
				responseString += [body]
			} else {
				responseString += ["unknow response body"]
			}
			completion?(responseString.joined(separator: "\n"))
		}
		}.resume()
}

/// <#Description#>
///
/// - Parameters:
///   - project: should be url encoded string
///   - branch: should be url encoded string
///   - commit: <#commit description#>
///   - completion: <#completion description#>
private func createAppCenterBuild(project: String, branch: String, commit: String, completion: ((String) -> Void)?) {
	var urlRequest = URLRequest(url: URL(
		string: "https://api.appcenter.ms/v0.1/apps/shaneqi/\(project)/branches/\(branch)/builds")!)
	urlRequest.httpMethod = "POST"
	urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
	urlRequest.addValue(appCenterApiToken, forHTTPHeaderField: "X-API-Token")
	urlRequest.httpBody = """
	{
		"sourceVersion": "\(commit)",
		"debug": false
	}
	""".data(using: .utf8)
	let session = URLSession(configuration: URLSessionConfiguration.default)
	session.dataTask(with: urlRequest) { data, response, _ in
		let code = (response as? HTTPURLResponse)?.statusCode
		var responseString = [String]()
		if let code = code {
			responseString += ["\(code)"]
		} else {
			responseString += ["unknown status code"]
		}
		if let data = data, let body = String(data: data, encoding: .utf8) {
			responseString += [body]
		} else {
			responseString += ["unknow response body"]
		}
		completion?(responseString.joined(separator: "\n"))
		}.resume()
}
