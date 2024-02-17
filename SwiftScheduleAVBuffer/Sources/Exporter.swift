//
//  Exporter.swift
//
//
//  Created by Dan Waltin on 2024-02-11.
//

import Foundation
import AVFoundation

struct VolumeMarker {
	let time:TimeInterval
	let volume: Float
}

struct VolumeSegment {
	let start: VolumeMarker
	let end: VolumeMarker
}

class Exporter {

	
	func export(sourceFileURL: URL,
				toDestinationURL destinationURL: URL,
				volumeSegments: [VolumeSegment]) async throws {

		let asset = AVAsset(url: sourceFileURL)
		
		guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
			print("Could not create export session")
			return
		}

		session.outputURL = destinationURL
		session.outputFileType = .m4a
		
		let audioMix = AVMutableAudioMix()
		guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
			print("Could not load audio track")
			return
		}
		
		let mixInputParameters = AVMutableAudioMixInputParameters(track: audioTrack)
		
		let timeZero = CMTime.zero
		for volume in volumeSegments {
			let volumeStartTime = CMTime(seconds: volume.start.time, preferredTimescale: timeZero.timescale)
			let volumeEndTime = CMTime(seconds: volume.end.time, preferredTimescale: timeZero.timescale)
			
			mixInputParameters.setVolumeRamp(
				fromStartVolume: volume.start.volume,
				toEndVolume: volume.end.volume,
				timeRange: CMTimeRange(start: volumeStartTime, end: volumeEndTime))
		}

		
		audioMix.inputParameters = [mixInputParameters]
		
		session.audioMix = audioMix
		
		//await session.export()
		
		let playerItem = AVPlayerItem(asset: asset)
		playerItem.audioMix = audioMix
		
		let player = AVPlayer()
		player.play()
	}

	func exportToSegments(sourceFileURL: URL,
						  toDestinationURL destinationURL: URL,
						  destinationFilename: String,
						  destinationFileExtension: String,
						  segmentLength: Double,
						  numberOfSegments: Int,
						  playerFunc: (AVAudioFormat) -> (AVAudioEngine, AVAudioPlayerNode)) async throws -> [URL]{

		let sourceFile = try AVAudioFile(forReading: sourceFileURL)
		let format = sourceFile.processingFormat


		var segmentURLs = [URL]()

		let startSecond: TimeInterval = 0

		
		for i in 0..<numberOfSegments {
			let (engine,player) = playerFunc(format)

			let maxFrames: AVAudioFrameCount = 128
			try engine.enableManualRenderingMode(.offline,
												 format: format,
												 maximumFrameCount: maxFrames)

			try engine.start()
			player.play()
			let outputURL = destinationURL.appendingPathComponent(destinationFilename + "_\(i)").appendingPathExtension(destinationFileExtension)
			segmentURLs.append(outputURL)
			
			let outputFile = try AVAudioFile(forWriting: outputURL, settings: sourceFile.processingFormat.settings)

			let fromSeconds = startSecond + TimeInterval(Double(i) * segmentLength)
			let toSeconds = fromSeconds + TimeInterval(segmentLength)
			
			let sourceBuffer = try sourceFile.audioBuffer(fromSeconds: fromSeconds, toSeconds: toSeconds)
			player.scheduleBuffer(sourceBuffer, at: nil, completionHandler: nil)
			
			try render(engine: engine,
					   to: outputFile,
					   secondsToRender: toSeconds - fromSeconds,
					   sampleRate: sourceFile.fileFormat.sampleRate)
			player.stop()
			engine.stop()
		}
		
		return segmentURLs
	}

	func concatenate(sourceUrls: [URL], outputFileURL: URL) async throws {
		guard let first = sourceUrls.first else {
			print("no files to concatenate")
			return
		}

		let format = try format(atUrl: first)
		let (engine,player) = Player.withNoChange(format: format)

		let maxFrames: AVAudioFrameCount = 4096
		try engine.enableManualRenderingMode(.offline,
											 format: format,
											 maximumFrameCount: maxFrames)

		try engine.start()
		player.play()

		let outputFile = try AVAudioFile(forWriting: outputFileURL, settings: format.settings)
		for url in sourceUrls {
			let sourceFile = try AVAudioFile(forReading: url)
			player.scheduleFile(sourceFile, at: nil, completionHandler: nil)
			
			let maxFrames = engine.manualRenderingSampleTime + AVAudioFramePosition(sourceFile.length)
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
		player.stop()
		engine.stop()
	}

	private func format(atUrl url: URL) throws -> AVAudioFormat {
		let audioFile = try AVAudioFile(forReading: url)
		return audioFile.processingFormat
	}
	func combine(sourceUrls: [URL], outputFileURL: URL, segmentLength: Double) async throws {
		let composition = AVMutableComposition()
		
		let options: [String: Any] = [:]
			
		var startTime: CMTime = .zero
		for (index, url) in sourceUrls.enumerated() {
			let asset = AVURLAsset(url: url, options: options)
			guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
				print("Failed to add track at index \(index)")
				return
			}

			
			let duration = CMTime(seconds: segmentLength, preferredTimescale: startTime.timescale)
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
			print("failed to create session")
			return
		}
		
		session.outputFileType = AVFileType.m4a
		session.outputURL = outputFileURL

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
