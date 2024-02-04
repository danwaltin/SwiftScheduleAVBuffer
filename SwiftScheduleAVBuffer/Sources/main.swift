// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import AVFoundation

guard let sourceFileURL = Bundle.module.url(forResource: "Rhythm", withExtension: "caf") else {
	print("could not load source file")
	exit(1)
}

let sourceFile: AVAudioFile
let format: AVAudioFormat
do {
	sourceFile = try AVAudioFile(forReading: sourceFileURL)
	format = sourceFile.processingFormat
} catch {
	fatalError("Unable to load the source audio file: \(error.localizedDescription).")
}

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
player.scheduleFile(sourceFile, at: nil)

do {
	// The maximum number of frames the engine renders in any single render call.
	let maxFrames: AVAudioFrameCount = 4096
	try engine.enableManualRenderingMode(.offline, format: format,
										 maximumFrameCount: maxFrames)
} catch {
	fatalError("Enabling manual rendering mode failed: \(error).")
}

do {
	try engine.start()
	player.play()
} catch {
	fatalError("Unable to start audio engine: \(error).")
}

// The output buffer to which the engine renders the processed data.
let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
							  frameCapacity: engine.manualRenderingMaximumFrameCount)!


let outputFile: AVAudioFile
do {
	let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	let outputURL = documentsURL.appendingPathComponent("Rhythm-processed.caf")
	print("\(outputURL)")
	outputFile = try AVAudioFile(forWriting: outputURL, settings: sourceFile.fileFormat.settings)
} catch {
	fatalError("Unable to open output audio file: \(error).")
}

while engine.manualRenderingSampleTime < sourceFile.length {
	do {
		let frameCount = sourceFile.length - engine.manualRenderingSampleTime
		let framesToRender = min(AVAudioFrameCount(frameCount), buffer.frameCapacity)
		
		let status = try engine.renderOffline(framesToRender, to: buffer)
		
		switch status {
			
		case .success:
			try outputFile.write(from: buffer)

		default:
			print("status: \(status)")
		}
	} catch {
		fatalError("The manual rendering failed: \(error).")
	}
}


// Stop the player node and engine.
player.stop()
engine.stop()

print("Goodbye")
	
