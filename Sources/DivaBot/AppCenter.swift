//
//  AppCenterConfig.swift
//  DivaBot
//
//  Created by Shane Qi on 9/29/20.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct AppCenterConfig: Codable {
	let trigger: String
	let environmentVariables: [String]
	let signed: Bool
	let testsEnabled: Bool
	let badgeIsEnabled: Bool
	struct Toolsets: Codable {
		struct Buildscripts: Codable {
		}
		let buildscripts: Buildscripts
		struct Distribution: Codable {
			let destinationType: String
			let destinations: [String]
			let isSilent: Bool
		}
		let distribution: Distribution
		struct Javascript: Codable {
			let packageJsonPath: String
			let runTests: Bool
		}
		let javascript: Javascript
		struct Xcode: Codable {
			let certificateType: String
			let certificatePassword: String
			var certificateFilename: String
			var provisioningProfileFilename: String
			var certificateFileId: String
			var provisioningProfileFileId: String
			struct AppExtensionProvisioningProfileFile: Codable {
				var fileId: String
				var fileName: String
				var targetBundleIdentifier: String
			}
			var appExtensionProvisioningProfileFiles: [AppExtensionProvisioningProfileFile]
			let projectOrWorkspacePath: String
			let scheme: String
			var xcodeVersion: String
			let podfilePath: String
		}
		var xcode: Xcode
	}
	var toolsets: Toolsets
	struct ArtifactVersioning: Codable {
		let buildNumberFormat: String
	}
	let artifactVersioning: ArtifactVersioning?
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
		} else if code == 404 {
			createAppCenterConfigAndBuild(
				project: encodedProject, branch: encodedBranch, config: config, commit: commit, completion: completion)
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

func replaceAppCenterBuild(
	project: String, fromBranch: String, toConfig: String, keys: [String], completion: ((String) -> Void)?) {
	let targetFilePath = appCenterConfigPathPrefix + "AppCenterBuildConfigs/\(project.lowercased())-\(toConfig.lowercased()).json"
	guard FileManager.default.fileExists(atPath: targetFilePath) else {
		completion?("The target file \(targetFilePath) doesn't exist.")
		return
	}
	do {
		var targetConfig = try JSONDecoder().decode(
			AppCenterConfig.self, from: Data(contentsOf: URL(fileURLWithPath: targetFilePath)))
		getAppCenterBuildConfig(project: project, branch: fromBranch) { result in
			switch result {
			case .failure(let errorMessage):
				completion?(errorMessage)
			case .success(let newConfig):
				var handledKeys = [String]()
				var unhandledKeys = [String]()
				var keyPaths: [WritableKeyPath<AppCenterConfig, String>] = []
				for key in keys {
					switch key.lowercased() {
					case "certificate-filename":
						handledKeys.append(key)
						keyPaths.append(\AppCenterConfig.toolsets.xcode.certificateFilename)
					case "certificate-file-id":
						handledKeys.append(key)
						keyPaths.append(\AppCenterConfig.toolsets.xcode.certificateFileId)
					case "provisioning-profile-filename":
						handledKeys.append(key)
						keyPaths.append(\AppCenterConfig.toolsets.xcode.provisioningProfileFilename)
					case "provisioning-profile-file-id":
						handledKeys.append(key)
						keyPaths.append(\AppCenterConfig.toolsets.xcode.provisioningProfileFileId)
					case "xcode-version":
						handledKeys.append(key)
						keyPaths.append(\AppCenterConfig.toolsets.xcode.xcodeVersion)
					case let string where string.starts(with: "extension-"):
						let extensionKeyPath: WritableKeyPath<AppCenterConfig, String>? = {
							switch string {
							case "extension-provisioning-profile-filename":
								return \AppCenterConfig.toolsets.xcode.appExtensionProvisioningProfileFiles[0].fileName
							case "extension-provisioning-profile-file-id":
								return  \AppCenterConfig.toolsets.xcode.appExtensionProvisioningProfileFiles[0].fileId
							case "extension-target-bundle-id":
								return  \AppCenterConfig.toolsets.xcode.appExtensionProvisioningProfileFiles[0].targetBundleIdentifier
							default:
								return nil
							}
						}()
						if let extensionKeyPath = extensionKeyPath {
							guard !newConfig.toolsets.xcode.appExtensionProvisioningProfileFiles.isEmpty else {
								unhandledKeys.append(key)
								break
							}
							handledKeys.append(key)
							if targetConfig.toolsets.xcode.appExtensionProvisioningProfileFiles.isEmpty {
								targetConfig.toolsets.xcode.appExtensionProvisioningProfileFiles.append(
									AppCenterConfig.Toolsets.Xcode.AppExtensionProvisioningProfileFile(
										fileId: "",
										fileName: "",
										targetBundleIdentifier: ""))
							}
							targetConfig[keyPath: extensionKeyPath] = newConfig[keyPath: extensionKeyPath]
						} else {
							unhandledKeys.append(key)
						}
					default:
						unhandledKeys.append(key)
					}
					for keyPath in keyPaths {
						targetConfig[keyPath: keyPath] = newConfig[keyPath: keyPath]
					}
				}
				do {
					let encoder = JSONEncoder()
					encoder.outputFormatting = [.prettyPrinted]
					let newData = try encoder.encode(targetConfig)
					try newData.write(to: URL(fileURLWithPath: targetFilePath))
					completion?("""
					Handled keys: \(handledKeys)
					Unhandled keys: \(unhandledKeys)
					""")
				} catch {
					completion?("Failed to replace App Center build config due to error: \(error.localizedDescription)")
				}
			}
		}
	} catch {
		completion?("Failed to decode target file due to \(error)")
	}
}

private func getAppCenterBuildConfig(
	project: String, branch: String, completion: ((Result<AppCenterConfig, String>) -> Void)?) {
	guard let encodedProject = project.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
		completion?(.failure("Failed to encode '\(project)'."))
		return
	}
	guard let encodedBranch = branch.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
		completion?(.failure("Failed to encode '\(branch)'."))
		return
	}
	var urlRequest = URLRequest(url: URL(
		string: "https://api.appcenter.ms/v0.1/apps/shaneqi/\(encodedProject)/branches/\(encodedBranch)/config")!)
	urlRequest.httpMethod = "GET"
	urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
	urlRequest.addValue(appCenterApiToken, forHTTPHeaderField: "X-API-Token")
	let session = URLSession(configuration: URLSessionConfiguration.default)
	session.dataTask(with: urlRequest) { data, response, _ in
		guard let data = data else {
			completion?(.failure("""
				Bad response, code: \((response as? HTTPURLResponse).flatMap({ "\($0.statusCode)" }) ?? "unknown")
				"""))
			return
		}
		do {
			let config = try JSONDecoder().decode(AppCenterConfig.self, from: data)
			completion?(.success(config))
		} catch {
			completion?(.failure("Failed to parse due to error: \(error)"))
		}
	}.resume()
}

/// <#Description#>
///
/// - Parameters:
///   - project: should be url encoded string
///   - branch: should be url encoded string
///   - config: <#config description#>
///   - commit: <#commit description#>
///   - completion: <#completion description#>
private func createAppCenterConfigAndBuild(
	project: String, branch: String, config: Data, commit: String, completion: ((String) -> Void)?) {
	var urlRequest = URLRequest(url: URL(
		string: "https://api.appcenter.ms/v0.1/apps/shaneqi/\(project)/branches/\(branch)/config")!)
	urlRequest.httpMethod = "POST"
	urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
	urlRequest.addValue(appCenterApiToken, forHTTPHeaderField: "X-API-Token")
	urlRequest.httpBody = config
	let session = URLSession(configuration: URLSessionConfiguration.default)
	session.dataTask(with: urlRequest) { data, response, _ in
		let code = (response as? HTTPURLResponse)?.statusCode
		var responseString = [String]()
		if code == 200 {
			createAppCenterBuild(project: project, branch: branch, commit: commit, completion: completion)
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

extension String: Swift.Error {}
