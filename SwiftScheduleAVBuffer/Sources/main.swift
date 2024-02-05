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

let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

do {
	try await export(sourceFileURL: bjekkerSourceFileURL,
					 toDestinationURL: documentsURL,
					 destinationFilename: "bjekker-unchanged.m4a",
					 playerFunc: playerWithNoChange)

	try await export(sourceFileURL: bjekkerSourceFileURL,
					 toDestinationURL: documentsURL,
					 destinationFilename: "bjekker-rateChanged.m4a",
					 playerFunc: playerWithRateChange)
	
	try await export(sourceFileURL: bjekkerSourceFileURL,
					 toDestinationURL: documentsURL,
					 destinationFilename: "bjekker-withReverb.m4a",
					 playerFunc: playerWithReverb)
	
	try await export(sourceFileURL: rhythmSourceFileURL,
					 toDestinationURL: documentsURL,
					 destinationFilename: "rhythm-unchanged.caf",
					 playerFunc: playerWithNoChange)

	try await export(sourceFileURL: rhythmSourceFileURL,
					 toDestinationURL: documentsURL,
					 destinationFilename: "rhythm-rateChanged.caf",
					 playerFunc: playerWithRateChange)
	
	try await export(sourceFileURL: rhythmSourceFileURL,
					 toDestinationURL: documentsURL,
					 destinationFilename: "rhythm-withReverb.caf",
					 playerFunc: playerWithReverb)
} catch {
	print("Failed to export: \(error.localizedDescription)")
}

print("Goodbye")
	
// MARK: - Helpers

func playerWithNoChange(format: AVAudioFormat) -> (engine: AVAudioEngine, player: AVAudioPlayerNode) {
	let engine = AVAudioEngine()
	let player = AVAudioPlayerNode()

	engine.attach(player)

	engine.connect(player, to: engine.mainMixerNode, format: format)

	return (engine, player)
}

func playerWithReverb(format: AVAudioFormat) -> (engine: AVAudioEngine, player: AVAudioPlayerNode) {
	let engine = AVAudioEngine()
	let player = AVAudioPlayerNode()
	let reverb = AVAudioUnitReverb()

	engine.attach(player)
	engine.attach(reverb)

	reverb.loadFactoryPreset(.mediumHall)
	reverb.wetDryMix = 50

	engine.connect(player, to: reverb, format: format)
	engine.connect(reverb, to: engine.mainMixerNode, format: format)

	return (engine, player)
}

func playerWithRateChange(format: AVAudioFormat) -> (engine: AVAudioEngine, player: AVAudioPlayerNode) {
	let engine = AVAudioEngine()
	let player = AVAudioPlayerNode()
	let rate = AVAudioUnitTimePitch()

	engine.attach(player)
	engine.attach(rate)

	rate.rate = 1

	engine.connect(player, to: rate, format: format)
	engine.connect(rate, to: engine.mainMixerNode, format: format)

	return (engine, player)
}

func export(sourceFileURL: URL,
			toDestinationURL destinationURL: URL,
			destinationFilename: String,
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
	let numberOfSegmentsToRender = 3
	let startSecond: TimeInterval = 0

	let outputURL = destinationURL.appendingPathComponent(destinationFilename)
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
