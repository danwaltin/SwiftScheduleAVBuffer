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

guard let bjekker_0_URL = Bundle.module.url(forResource: "bjekker-unchanged_0", withExtension: "m4a") else {
	print("could not load bjekker 0 source file")
	exit(1)
}

guard let bjekker_1_URL = Bundle.module.url(forResource: "bjekker-unchanged_1", withExtension: "m4a") else {
	print("could not load bjekker 1 source file")
	exit(1)
}

let destinationURL = try getDestinationURL()
let outputURL = destinationURL.appendingPathComponent("bjekker-combined").appendingPathExtension("m4a")

let composer = AudioComposer()

do {
//	try await composer.combineAudioFiles(audioFileURL1: bjekker_0_URL, audioFileURL2: bjekker_1_URL, outputFileURL: outputURL)
		try await export(sourceFileURL: bjekkerSourceFileURL,
						 toDestinationURL: destinationURL,
						 destinationFilename: "bjekker-unchanged",
						 destinationFileExtension: "m4a",
						 playerFunc: Player.withNoChange)
	
		try await export(sourceFileURL: bjekkerSourceFileURL,
						 toDestinationURL: destinationURL,
						 destinationFilename: "bjekker-rateChanged",
						 destinationFileExtension: "m4a",
						 playerFunc: Player.withRateChange)
	
//	let exporter = Exporter()
//	let exportedURL = try await exporter.exportWithManualRendering(sourceTrackURL: bjekkerSourceFileURL)
//	print(exportedURL)
//	let splitURLs = try await exporter.splitWithExportSession(trackToSplitURL: exportedURL)
//	print(splitURLs)
//	let outputURL = destinationURL.appendingPathComponent("bjekker-rateChanged").appendingPathExtension("m4a")
//	try await exporter.combineWithExportSession(trackUrlsToCombine: splitURLs, destinationPathURL: outputURL)
	
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

func export(sourceFileURL: URL,
			toDestinationURL destinationURL: URL,
			destinationFilename: String,
			destinationFileExtension: String,
			playerFunc: (AVAudioFormat) -> (AVAudioEngine, AVAudioPlayerNode)) async throws {

	let sourceFile = try AVAudioFile(forReading: sourceFileURL)
	let format = sourceFile.processingFormat

	let (engine,player) = playerFunc(format)


	// The maximum number of frames the engine renders in any single render call.
	let maxFrames: AVAudioFrameCount = 4096
	try engine.enableManualRenderingMode(.offline, 
										 format: format,
										 maximumFrameCount: maxFrames)

	try engine.start()
	player.play()

	let renderLength = 5
	let numberOfSegmentsToRender = 2
	let startSecond: TimeInterval = 0

	var segmentURLs = [URL]()
	
	for i in 0..<numberOfSegmentsToRender {
		let outputURL = destinationURL.appendingPathComponent(destinationFilename + "_\(i)").appendingPathExtension(destinationFileExtension)
		segmentURLs.append(outputURL)
		var outputFile:AVAudioFile? = try AVAudioFile(forWriting: outputURL, settings: sourceFile.processingFormat.settings)

		let fromSeconds = startSecond + TimeInterval(i * renderLength)
		let toSeconds = fromSeconds + TimeInterval(renderLength)
		
		let sourceBuffer = try sourceFile.audioBuffer(fromSeconds: fromSeconds, toSeconds: toSeconds)
		player.scheduleBuffer(sourceBuffer, at: nil, completionHandler: nil)
		

		try render(engine: engine,
				   to: outputFile!,
				   secondsToRender: toSeconds - fromSeconds,
				   sampleRate: sourceFile.fileFormat.sampleRate)
		outputFile = nil
	}
	player.stop()
	engine.stop()
	
	try await AudioComposer().concatenateAudioFiles(
		urls: segmentURLs,
		format: format,
		to: destinationURL,
		filename: destinationFilename,
		fileExtension: destinationFileExtension)
}


func render(engine: AVAudioEngine,
			to outputFile: AVAudioFile,
			secondsToRender: TimeInterval,
			sampleRate: Double) throws {

	let totalFramesToRender = secondsToRender * sampleRate

	let maxFrames = engine.manualRenderingSampleTime + AVAudioFramePosition(totalFramesToRender)
	while engine.manualRenderingSampleTime < maxFrames  {
		let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
									  frameCapacity: engine.manualRenderingMaximumFrameCount)!

		let frameCount = maxFrames - engine.manualRenderingSampleTime
		let framesToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)
		
		let status = try engine.renderOffline(framesToRender, to: buffer)
		
		switch status {
			
		case .success:
				try outputFile.write(from: buffer)
			
		default:
			print("status: \(status)")
		}
	}
}

