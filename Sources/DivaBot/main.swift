//
//  main.swift
//  DivaBot
//
//  Created by Shane Qi on 6/5/18.
//

import ZEGBot
import Arguments
import Foundation

ZEGBot(token: tgBotToken).run { result, bot in
	switch result {
	case .success(let update):
		switch update {
		case .message(_, let message):
			guard let text = message.text else { break }
			var arguments = Arguements(string: text)
			guard let command = arguments.next() else { break }
			switch command.lowercased() {
			case "/ttg":
				var results = [(url: String, result: String)]()
				let group = DispatchGroup()
				for (index, argument) in arguments.enumerated() {
					group.enter()
					DispatchQueue.global(qos: .userInitiated).async {
						results.append((argument, ""))
						guard let url = URL(string: argument) else {
							results[index].result = "❌ Invalid url."
							group.leave()
							return
						}
						guard let torrentIdString = url.pathComponents.last,
							let torrentId = Int(torrentIdString) else {
								results[index].result = "❌ No torrent id found."
								group.leave()
								return
						}
						addTorrent(with: "https://totheglory.im/dl/\(torrentId)/\(ttgTorrentToken)") { result in
							switch result {
							case .success(.addedTorrent(let name)):
								results[index].result = ("✅ " + name)
							case .success(.duplicatedTorrent(let name)):
								results[index].result = "⚠️ \(name)"
							case .success(.failure(let message)):
								results[index].result = "❌ " + message
							case .failure(let error):
								results[index].result = "❌ " + error.localizedDescription
							}
							group.leave()
						}
					}
				}
				group.wait()
				if results.isEmpty {
					bot.send(message: "Please give at least one TTG torrent page url.", to: message)
				} else {
					bot.send(message: results.map({ $0.url + "\n" + $0.result }).joined(separator: "\n\n"), to: message)
				}
			default:
				break
			}
		default:
			break
		}
	case .failure(let error):
		dump(error)
	}
}
