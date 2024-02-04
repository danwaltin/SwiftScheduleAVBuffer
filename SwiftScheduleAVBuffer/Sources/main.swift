// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import AVFoundation

guard let sourceFileURL = Bundle.module.url(forResource: "Rhythm", withExtension: "caf") else {
	print("could not load source file")
	exit(1)
}

do {
	try export(sourceFileURL: sourceFileURL)
} catch {
	print("Failed to export: \(error.localizedDescription)")
}

print("Goodbye")
	
// MARK: - Helpers

func export(sourceFileURL: URL) throws {
	let sourceFile = try AVAudioFile(forReading: sourceFileURL)
	let format = sourceFile.processingFormat

	let engine = AVAudioEngine()
	let player = AVAudioPlayerNode()
	let reverb = AVAudioUnitReverb()


	engine.attach(player)
	engine.attach(reverb)


	// Set the desired reverb parameters.
	reverb.loadFactoryPreset(.mediumHall)
	reverb.wetDryMix = 50


	// Connect the nodes.
	engine.connect(player, to: reverb, format: format)
	engine.connect(reverb, to: engine.mainMixerNode, format: format)


	// Schedule the source file.

	var maxFramePositionToRender: AVAudioFramePosition = 0

	//maxFramePositionToRender = sourceFile.length
	//player.scheduleFile(sourceFile, at: nil, completionCallbackType: .dataRendered)

	do {
		let buffer = try sourceFile.audioBuffer(fromSeconds: 2, toSeconds: 10)
		maxFramePositionToRender = AVAudioFramePosition(buffer.frameLength)
		
		player.scheduleBuffer(buffer, completionCallbackType: .dataConsumed)
	} catch {
		fatalError("failed to get buffer: \(error).")
	}

	// The maximum number of frames the engine renders in any single render call.
	let maxFrames: AVAudioFrameCount = 4096
	try engine.enableManualRenderingMode(.offline, format: format,
										 maximumFrameCount: maxFrames)

	try engine.start()
	player.play()

	// The output buffer to which the engine renders the processed data.
	let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
								  frameCapacity: engine.manualRenderingMaximumFrameCount)!


	let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	let outputURL = documentsURL.appendingPathComponent("Rhythm-processed.caf")
	print("\(outputURL)")
	let outputFile = try AVAudioFile(forWriting: outputURL, settings: sourceFile.fileFormat.settings)

	while engine.manualRenderingSampleTime < maxFramePositionToRender {
		let frameCount = maxFramePositionToRender - engine.manualRenderingSampleTime
		let framesToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)
		
		let status = try engine.renderOffline(framesToRender, to: buffer)
		
		switch status {
			
		case .success:
			try outputFile.write(from: buffer)

		default:
			print("status: \(status)")
		}
	}

	player.stop()
	engine.stop()
}

enum AudioFileBufferError: Error {
	case couldNotCreateAudioBuffer(url: URL)
}

extension AVAudioFile {
	func audioBuffer(fromSeconds: TimeInterval, toSeconds: TimeInterval) throws -> AVAudioPCMBuffer {
		let sampleRate = processingFormat.sampleRate
		let start = AVAudioFramePosition(fromSeconds * sampleRate)
		let end = AVAudioFramePosition(toSeconds * sampleRate)

		let frameCount = AVAudioFrameCount(end - start)
		self.framePosition = start

		return try audioBuffer(frameCount: frameCount)
	}

	private func audioBuffer(frameCount: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
		let format = self.processingFormat

		guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
			throw AudioFileBufferError.couldNotCreateAudioBuffer(url: url)
		}

		try self.read(into: buffer, frameCount: frameCount)

		return buffer
	}
}
