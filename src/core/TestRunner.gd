class_name TestRunner
extends Node

## TestRunner: Точка запуску та оркестрації всіх юніт-тестів гри Saecula.
## Перенесено з Main.gd для чистоти архітектури (Stage 2).

const GameTestSuiteScript = preload("res://src/tests/GameTestSuite.gd")


static func run_all_tests(caller: Node) -> void:
	var suite: Node = GameTestSuiteScript.new(caller)
	if caller != null:
		caller.add_child(suite)
	suite.run_all_tests(caller)
	if is_instance_valid(suite):
		suite.queue_free()
