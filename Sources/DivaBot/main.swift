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
			guard message.chat.id == tgAdminChatId else { break }
			guard let text = message.text else { break }
			var arguments = Arguements(string: text)
			guard let command = arguments.next() else { break }
			switch command.lowercased() {
			case "/ttg":
				var results = [Int: (url: String, result: String)]()
				let group = DispatchGroup()
				for (index, argument) in arguments.enumerated() {
					group.enter()
					DispatchQueue.global(qos: .userInitiated).async {
						guard let url = URL(string: argument) else {
							results[index] = (argument, "❌ Invalid url.")
							group.leave()
							return
						}
						guard let torrentIdString = url.pathComponents.last,
							let torrentId = Int(torrentIdString) else {
								results[index] = (argument, "❌ No torrent id found.")
								group.leave()
								return
						}
						addTorrent(with: "https://totheglory.im/dl/\(torrentId)/\(ttgTorrentToken)") { result in
							switch result {
							case .success(.addedTorrent(let name)):
								results[index] = (argument, ("✅ " + name))
							case .success(.duplicatedTorrent(let name)):
								results[index] = (argument, "⚠️ \(name)")
							case .success(.failure(let message)):
								results[index] = (argument, "❌ " + message)
							case .failure(let error):
								results[index] = (argument, "❌ " + error.localizedDescription)
							}
							group.leave()
						}
					}
				}
				group.wait()
				if results.isEmpty {
					bot.send(message: "⚠️ Please give at least one TTG torrent page url.", to: message)
				} else {
					bot.send(message: results.sorted(by: { $0.key < $1.key }).map({ $0.value.url + "\n" + $0.value.result }).joined(separator: "\n\n"), to: message)
				}
			case "/blog":
				switch arguments.next()?.lowercased() {
				case "refresh"?:
					refreshBlog()
				default:
					bot.send(message: "⚠️ Please give arguments.", to: message)
				}
			case "/appcenter":
				guard let project = arguments.next(),
					let branch = arguments.next(),
					let commit = arguments.next(),
					let config = arguments.next() else {
						bot.send(
							message: "⚠️ Invalid arguments (e.g. `/appcenter project branch commit config`).",
							to: message,
							parseMode: .markdown)
						break
				}
				let configFilePath = "AppCenterBuildConfigs/\(project.lowercased())-\(config.lowercased()).json"
				guard let configData = FileManager.default.contents(atPath: configFilePath) else {
					bot.send(message: "⚠️ Failed to find config file `\(configFilePath)`.", to: message, parseMode: .markdown)
					break
				}
				createAppCenterBuild(project: project, branch: branch, commit: commit, config: configData) { responseString in
					bot.send(message: responseString, to: message)
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
