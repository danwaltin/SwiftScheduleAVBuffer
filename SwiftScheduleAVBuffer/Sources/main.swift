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

let exports: [(name: String, playerFunc: (AVAudioFormat) -> (AVAudioEngine, AVAudioPlayerNode))] = [
	//("bjekker-unchanged", Player.withNoChange),
	("bjekker-rateChanged", Player.withRateChange)
]

do {
	let ext = "m4a"
	
	try await exporter.export(
		sourceFileURL: bjekkerSourceFileURL,
		toDestinationURL: destinationURL.appending(path: "bjekker-mixed").appendingPathExtension(ext),
		volumeSegments: [
			VolumeSegment(start: VolumeMarker(time: 0, volume: 0),
						  end:	 VolumeMarker(time: 20, volume: 1)),
			VolumeSegment(start: VolumeMarker(time: 20, volume: 1),
						  end:	 VolumeMarker(time: 30, volume: 0.1)),
			VolumeSegment(start: VolumeMarker(time: 30, volume: 0.1),
						  end:	 VolumeMarker(time: 50, volume: 1)),
		])
	
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

