//
//  AVAudioFile+buffer.swift
//  
//
//  Created by Dan Waltin on 2024-02-11.
//

import Foundation
import AVFoundation

enum AudioFileBufferError: Error {
	case couldNotCreateAudioBuffer(url: URL)
}

extension AVAudioFile {
	func audioBuffer(fromSeconds: TimeInterval, toSeconds: TimeInterval) throws -> AVAudioPCMBuffer {
		let sampleRate = processingFormat.sampleRate
		let start = AVAudioFramePosition(fromSeconds * sampleRate)
		let end = AVAudioFramePosition(toSeconds * sampleRate)

		print("audioBuffer from: \(start) to: \(end)")
		let frameCount = AVAudioFrameCount(end - start)
		self.framePosition = start

		guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCount) else {
			throw AudioFileBufferError.couldNotCreateAudioBuffer(url: url)
		}

		try self.read(into: buffer, frameCount: frameCount)

		print("buffer frameLength: \(buffer.frameLength), frameCapacity: \(buffer.frameCapacity)")
		return buffer
	}
}
