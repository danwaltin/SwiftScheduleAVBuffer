//
//  Exporter.swift
//
//
//  Created by Dan Waltin on 2024-02-11.
//

import Foundation
import AVFoundation

class Exporter {

	func exportToSegments(sourceFileURL: URL,
						  toDestinationURL destinationURL: URL,
						  destinationFilename: String,
						  destinationFileExtension: String,
						  playerFunc: (AVAudioFormat) -> (AVAudioEngine, AVAudioPlayerNode)) async throws -> [URL]{

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
		
		return segmentURLs
	}

	func combine(sourceUrls: [URL], outputFileURL: URL) async throws {
		let composition = AVMutableComposition()
		
		let options: [String: Any] = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
			
		var startTime: CMTime = .zero
		for (index, url) in sourceUrls.enumerated() {
			let asset = AVURLAsset(url: url, options: options)
			guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
				print("Failed to add track at index \(index)")
				return
			}

			let duration = try await asset.load(.duration)
			let assetTrack = try await asset.loadTracks(withMediaType: .audio)[0]

			do {
				try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: assetTrack, at: startTime)
			} catch {
				print("Failed to insert time range at index \(index), error: \(error)")
				return
			}
			startTime = .init(seconds: startTime.seconds + duration.seconds, preferredTimescale: startTime.timescale)
		}

		guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
			return
		}
		
		session.outputFileType = AVFileType.m4a
		session.outputURL = outputFileURL
		let duration = try await session.estimatedMaximumDuration

		await session.export()
	}
	
	
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
