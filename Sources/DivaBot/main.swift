//
//  main.swift
//  DivaBot
//
//  Created by Shane Qi on 6/5/18.
//

import ZEGBot
import Arguments
import Foundation

do {
	try ZEGBot(token: tgBotToken).run { updates, bot in
		for update in updates {
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
					do {
						if results.isEmpty {
							try bot.send(message: "⚠️ Please give at least one TTG torrent page url.", to: message)
						} else {
							try bot.send(message: results.sorted(by: { $0.key < $1.key }).map({ $0.value.url + "\n" + $0.value.result }).joined(separator: "\n\n"), to: message)
						}
					} catch {
						dump(error)
					}
				case "/blog":
					switch arguments.next()?.lowercased() {
					case "refresh"?:
						refreshBlog()
					default:
						do {
							try bot.send(message: "⚠️ Please give arguments.", to: message)
						} catch {
							dump(error)
						}
					}
				case "/appcenter":
					guard let project = arguments.next(),
						  let branch = arguments.next(),
						  let commit = arguments.next(),
						  let config = arguments.next() else {
						do {
							try bot.send(
								message: "⚠️ Invalid arguments (e.g. `/appcenter project branch commit config`).",
								to: message,
								parseMode: .markdown)
						} catch {
							dump(error)
						}
						break
					}
					let configFilePath = "AppCenterBuildConfigs/\(project.lowercased())-\(config.lowercased()).json"
					guard let configData = FileManager.default.contents(atPath: configFilePath) else {
						do {
							try bot.send(message: "⚠️ Failed to find config file `\(configFilePath)`.", to: message, parseMode: .markdown)
						} catch {
							dump(error)
						}
						break
					}
					createAppCenterBuild(project: project, branch: branch, commit: commit, config: configData) { responseString in
						do {
							try bot.send(message: responseString, to: message)
						} catch {
							dump(error)
						}
					}
				case "/appcenterupdate":
					guard let project = arguments.next(),
						  let fromBranch = arguments.next(),
						  let toConfig = arguments.next() else {
						do {
							try bot.send(
								message: """
								⚠️ Invalid arguments (e.g. `/appcenterupdate eastwatch fromBranchDevelop toConfigStaging xcode-version ...`).
								available config keys:
								```
								certificate-filename
								certificate-file-id
								provisioning-profile-filename
								provisioning-profile-file-id
								xcode-version
								extension-provisioning-profile-filename
								extension-provisioning-profile-file-id
								extension-target-bundle-id
								```
								""",
								to: message,
								parseMode: .markdown)
						} catch {
							dump(error)
						}
						break
					}
					var keys = [String]()
					var key = arguments.next()
					while key != nil {
						keys.append(key!)
						key = arguments.next()
					}
					guard !keys.isEmpty else {
						do {
							try bot.send(
								message: "⚠️ No app center build config keys to handle.",
								to: message,
								parseMode: .markdown)
						} catch {
							dump(error)
						}
						break
					}
					replaceAppCenterBuild(
						project: project, fromBranch: fromBranch, toConfig: toConfig, keys: keys) { responseString in
						do {
							try bot.send(message: responseString, to: message)
						} catch {
							dump(error)
						}
					}
				default:
					break
				}
			default:
				break
			}
		}
		
	}
}catch {
	dump(error)
}
