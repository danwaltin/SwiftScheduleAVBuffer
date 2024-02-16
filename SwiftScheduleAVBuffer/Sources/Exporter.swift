//
//  Exporter.swift
//
//
//  Created by Dan Waltin on 2024-02-11.
//

import Foundation
import AVFoundation

class Exporter {

	func exportWithManualRendering(sourceTrackURL: URL) async throws -> URL {
		let sourceFile = try AVAudioFile(forReading: sourceTrackURL)
		let format = sourceFile.processingFormat
		let (engine,player) = Player.withNoChange(format: format)

		let outputURL = try getTempWorkingDirectory()
			.appendingPathComponent(sourceTrackURL.lastPathComponent)
		let outputFile = try AVAudioFile(forWriting: outputURL, settings: sourceFile.fileFormat.settings)
		
		let maxFrames: AVAudioFrameCount = 4096
		try engine.enableManualRenderingMode(.offline,
											 format: format,
											 maximumFrameCount: maxFrames)

		
		let segmentLength: TimeInterval = 5
		let numberOfSegments = 2
		let startTime: TimeInterval = 0
		
		try engine.start()
		player.play()

		for segmentIndex in 0..<numberOfSegments {
			let fromSeconds = startTime + Double(segmentIndex) * segmentLength
			let toSeconds = fromSeconds + segmentLength
			
			let buffer = try sourceFile.audioBuffer(fromSeconds: fromSeconds, toSeconds: toSeconds)
			
			player.scheduleBuffer(buffer, at: nil, completionHandler: nil)
			
			try render(engine: engine, to: outputFile, secondsToRender: segmentLength, sampleRate: sourceFile.processingFormat.sampleRate)
		}

		player.stop()
		engine.stop()
		
		return outputURL
	}
	
	func splitWithExportSession(trackToSplitURL: URL) async throws -> [URL] {
		return [trackToSplitURL]
	}
	
	func combineWithExportSession(trackUrlsToCombine: [URL],
								  destinationPathURL: URL) async throws {
		
	}
	
	// MARK: -
	private func getTempWorkingDirectory() throws -> URL {
		let temp = tempWorkingDirectory
		try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)

		return temp
	}
	
	private lazy var tempWorkingDirectory: URL = {
		FileManager
			.default
			.temporaryDirectory
			.appendingPathComponent("AudioExporter")
			.appendingPathComponent(UUID().uuidString)
	}()
	
	private func render(engine: AVAudioEngine,
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

}
