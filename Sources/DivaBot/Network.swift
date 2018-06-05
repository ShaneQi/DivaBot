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
