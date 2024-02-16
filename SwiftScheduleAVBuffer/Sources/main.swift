// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import AVFoundation

guard let bjekkerSourceFileURL = Bundle.module.url(forResource: "bjekker", withExtension: "m4a") else {
	print("could not load bjekker source file")
	exit(1)
}

guard let rhythmSourceFileURL = Bundle.module.url(forResource: "Rhythm", withExtension: "caf") else {
	print("could not load rhythm source file")
	exit(1)
}

let destinationURL = try getDestinationURL()
let exporter = Exporter()

let exports: [(name: String, plyerFunc: (AVAudioFormat) -> (AVAudioEngine, AVAudioPlayerNode))] = [
	("bjekker-unchanged", Player.withNoChange),
	//("bjekker-rateChanged", Player.withRateChange)
]

do {
	for export in exports {
		let urls = try await exporter.exportToSegments(sourceFileURL: bjekkerSourceFileURL,
													   toDestinationURL: destinationURL,
													   destinationFilename: export.name,
													   destinationFileExtension: "m4a",
													   playerFunc: export.plyerFunc)
		try await exporter.combine(sourceUrls: urls,
								   outputFileURL: destinationURL.appending(path: export.name).appendingPathExtension("m4a"))
	}
} catch {
	print("Failed to export: \(error.localizedDescription)")
}

print("Goodbye")
	
// MARK: - Helpers

private func getDestinationURL() throws -> URL {
	let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	let destinationURL = documentsURL.appendingPathComponent("AudioExport")

	try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
	
	return destinationURL
}

