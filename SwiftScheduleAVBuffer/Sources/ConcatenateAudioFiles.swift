//
//  ConcatenateAudioFiles.swift
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

		let options: [String: Any] = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
				
	}
	
}
