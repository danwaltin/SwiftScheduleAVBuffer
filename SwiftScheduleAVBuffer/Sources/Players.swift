//
//  Players.swift
//  
//
//  Created by Dan Waltin on 2024-02-10.
//

import Foundation
import AVFoundation

struct Player {
	static func withNoChange(format: AVAudioFormat) -> (engine: AVAudioEngine, player: AVAudioPlayerNode) {
		let engine = AVAudioEngine()
		let player = AVAudioPlayerNode()
		
		engine.attach(player)
		
		engine.connect(player, to: engine.mainMixerNode, format: format)
		
		return (engine, player)
	}
	
	static func withReverb(format: AVAudioFormat) -> (engine: AVAudioEngine, player: AVAudioPlayerNode) {
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
	
	static func withRateChange(format: AVAudioFormat) -> (engine: AVAudioEngine, player: AVAudioPlayerNode) {
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
}
