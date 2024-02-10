//
//  AudioComposer.swift
//  SwiftScheduleAVBuffer
//
//  Created by Dan Waltin on 2024-02-07.
//

import Foundation
import AVFoundation

class AudioComposer {
	func concatenateAudioFiles(urls: [URL],
							   format: AVAudioFormat,
							   to destinationURL: URL,
							   filename: String,
							   fileExtension: String) async throws {
		let outputURL = destinationURL
			.appendingPathComponent(filename)
			.appendingPathExtension(fileExtension)
		let outputFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)
		
		try await combineAudioFiles(audioFileURL1: urls[0], audioFileURL2: urls[1], outputFileURL: outputURL)
		
		return
		let options: [String: Any] = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
		
		let (engine,player) = Player.withNoChange(format: format)
		
		let maxFrames: AVAudioFrameCount = 4096
		try engine.enableManualRenderingMode(.offline,
											 format: format,
											 maximumFrameCount: maxFrames)
		
		try engine.start()
		player.play()
		
		var length: AVAudioFramePosition = 0
		for url in urls {
			let source = try AVAudioFile(forReading: url)
			
			player.scheduleFile(source, at: nil, completionHandler: nil)
			
			length += source.length
		}
		try render(engine: engine, to: outputFile, maxFrames: length)
		
		player.stop()
		engine.stop()
	}
	
	func render(engine: AVAudioEngine,
				to outputFile: AVAudioFile,
				maxFrames: AVAudioFramePosition) throws {
		
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
	
	func combineAudioFiles(audioFileURL1: URL, audioFileURL2: URL, outputFileURL: URL) async throws {
		let composition = AVMutableComposition()
		
		let options: [String: Any] = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
						
		// Load audio files
		let asset1 = AVURLAsset(url: audioFileURL1, options: options)
		let asset2 = AVURLAsset(url: audioFileURL2, options: options)
		
		// Add audio tracks from the audio files to the composition
		guard let track1 = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
			  let track2 = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
			return
		}

		let duration1 = try await asset1.load(.duration)
		let duration2 = try await asset2.load(.duration)
		
		print("duration1: \(duration1)")
		print("duration2: \(duration2)")
		let assetTrack1 = try await asset1.loadTracks(withMediaType: .audio)[0]
		let assetTrack2 = try await asset2.loadTracks(withMediaType: .audio)[0]
		
		do {
			try track1.insertTimeRange(CMTimeRange(start: .zero, duration: duration1), of: assetTrack1, at: .zero)
			try track2.insertTimeRange(CMTimeRange(start: .zero, duration: duration2), of: assetTrack2, at: track1.timeRange.duration)
		} catch {
			print(error)
			return
		}

		// Export the composition
		guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
			return
		}
		
		exporter.outputFileType = AVFileType.m4a
		exporter.outputURL = outputFileURL
		let duration = try await exporter.estimatedMaximumDuration

		print("output duration: \(duration)")
		await withCheckedContinuation { continuation in
			
			exporter.exportAsynchronously {
				switch exporter.status {
				case .completed:
					print("export completed")
				case .failed:
					print("export failed, status: \(exporter.status.rawValue)")
					print("export failed, error: \(String(describing: exporter.error))")
				case .cancelled:
					print("export cancelled")
				default:
					print("export default case: \(exporter.status)")
				}
				continuation.resume()
			}
		}
	}
}

