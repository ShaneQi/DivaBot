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
				guard let urlString = arguments.next() else {
					bot.send(message: "Please give a TTG torrent page url.", to: message)
					break
				}
				guard let url = URL(string: urlString) else {
						bot.send(message: "Please give a valid TTG torrent page url.", to: message)
						break
				}
				guard let torrentIdString = url.pathComponents.last,
					let torrentId = Int(torrentIdString) else {
						bot.send(message: "Failed to parse torrent ID from torrent page URL.", to: message)
						break
				}
				print("https://totheglory.im/dl/\(torrentId)/\(ttgTorrentToken)")
			default:
				break
			}
		default:
			break
		}
	case .failure(let error):
		print(error)
	}
}
