class_name AIProfile
extends Resource

## Behavioral knobs for AIController (see graphify/Architecture - Systems.md).
## All 0..1. Fleshed out for real decision-making in M4.

@export var display_name: String = ""
@export_range(0.0, 1.0) var aggression: float = 0.5
@export_range(0.0, 1.0) var bluff: float = 0.2
@export_range(0.0, 1.0) var tightness: float = 0.5
@export_range(0.0, 1.0) var risk: float = 0.5


static func rock() -> AIProfile:
	var p := AIProfile.new()
	p.display_name = "Rock"
	p.aggression = 0.15
	p.bluff = 0.05
	p.tightness = 0.85
	p.risk = 0.2
	return p


static func maniac() -> AIProfile:
	var p := AIProfile.new()
	p.display_name = "Maniac"
	p.aggression = 0.9
	p.bluff = 0.5
	p.tightness = 0.15
	p.risk = 0.85
	return p


static func calling_station() -> AIProfile:
	var p := AIProfile.new()
	p.display_name = "Calling Station"
	p.aggression = 0.1
	p.bluff = 0.05
	p.tightness = 0.05
	p.risk = 0.3
	return p


static func shark() -> AIProfile:
	var p := AIProfile.new()
	p.display_name = "Shark"
	p.aggression = 0.55
	p.bluff = 0.25
	p.tightness = 0.5
	p.risk = 0.5
	return p


static func presets() -> Array[AIProfile]:
	var result: Array[AIProfile] = [rock(), maniac(), calling_station(), shark()]
	return result
