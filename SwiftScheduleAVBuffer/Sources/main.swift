// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import AVFoundation

guard let sourceFileURL = Bundle.module.url(forResource: "Rhythm", withExtension: "caf") else {
	print("could not load source file")
	exit(1)
}

let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let outputURL = documentsURL.appendingPathComponent("Rhythm-processed2.caf")
print("\(outputURL)")

do {
	try await export(sourceFileURL: sourceFileURL, outputURL: outputURL)
} catch {
	print("Failed to export: \(error.localizedDescription)")
}

print("Goodbye")
	
// MARK: - Helpers

func export(sourceFileURL: URL, outputURL: URL) async throws {
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

	

	// The maximum number of frames the engine renders in any single render call.
	let maxFrames: AVAudioFrameCount = 4096
	try engine.enableManualRenderingMode(.offline, 
										 format: format,
										 maximumFrameCount: maxFrames)

	try engine.start()
	player.play()

	let renderLength = 5
	let numberOfSegmentsToRender = 3
	let startSecond: TimeInterval = 0
	let outputFile = try AVAudioFile(forWriting: outputURL, settings: sourceFile.fileFormat.settings)

	for i in 0..<numberOfSegmentsToRender {
		let fromSeconds = startSecond + TimeInterval(i * renderLength)
		let toSeconds = fromSeconds + TimeInterval(renderLength)
		
		let sourceBuffer = try sourceFile.audioBuffer(fromSeconds: fromSeconds, toSeconds: toSeconds)
		player.scheduleBuffer(sourceBuffer, at: nil, completionHandler: nil)
		
		
		try render(engine: engine, 
				   to: outputFile,
				   secondsToRender: toSeconds - fromSeconds,
				   sampleRate: sourceFile.fileFormat.sampleRate)
	}
	player.stop()
	engine.stop()
}

func render(engine: AVAudioEngine,
			to outputFile: AVAudioFile,
			secondsToRender: TimeInterval,
			sampleRate: Double) throws {

	let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
								  frameCapacity: engine.manualRenderingMaximumFrameCount)!

	let totalFramesToRender = secondsToRender * sampleRate

	let maxFrames = engine.manualRenderingSampleTime + AVAudioFramePosition(totalFramesToRender)
	while engine.manualRenderingSampleTime < maxFrames  {
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

		guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCount) else {
			throw AudioFileBufferError.couldNotCreateAudioBuffer(url: url)
		}

		try self.read(into: buffer, frameCount: frameCount)

		return buffer
	}
}
