extends GutTest

const SerializationScript = preload("res://shared/network/serialization.gd")


func test_encode_message_has_required_fields() -> void:
	var json_str := SerializationScript.encode_message("test_type", {"key": "value"})
	var parsed := JSON.parse_string(json_str)

	assert_not_null(parsed, "Should parse as valid JSON")
	assert_has(parsed, "type", "Should have type field")
	assert_has(parsed, "data", "Should have data field")
	assert_has(parsed, "timestamp", "Should have timestamp field")
	assert_eq(parsed["type"], "test_type", "Type should match")
	assert_eq(parsed["data"]["key"], "value", "Data should match")

func test_decode_message_valid_json() -> void:
	var json_str := '{"type": "test", "data": {"foo": "bar"}, "timestamp": 123}'
	var result := SerializationScript.decode_message(json_str)

	assert_not_null(result, "Should decode valid JSON")
	assert_eq(result["type"], "test", "Type should match")
	assert_eq(result["data"]["foo"], "bar", "Data should match")

func test_decode_message_invalid_json() -> void:
	var result := SerializationScript.decode_message("not valid json {{{")
	assert_null(result, "Should return null for invalid JSON")

func test_decode_message_missing_type() -> void:
	var json_str := '{"data": {"foo": "bar"}}'
	var result := SerializationScript.decode_message(json_str)
	assert_null(result, "Should return null when type is missing")

func test_decode_message_missing_data() -> void:
	var json_str := '{"type": "test"}'
	var result := SerializationScript.decode_message(json_str)
	assert_null(result, "Should return null when data is missing")

func test_encode_connect_request() -> void:
	var json_str := SerializationScript.encode_connect_request("TestPlayer")
	var parsed := SerializationScript.decode_message(json_str)

	assert_not_null(parsed, "Should decode successfully")
	assert_eq(parsed["type"], MessageTypes.CONNECT_REQUEST, "Type should be connect_request")
	assert_eq(parsed["data"]["player_name"], "TestPlayer", "Player name should match")

func test_encode_player_input() -> void:
	var direction := Vector2(0.5, -0.5)
	var aim := 1.57
	var json_str := SerializationScript.encode_player_input(42, direction, aim, ["jump"])
	var parsed := SerializationScript.decode_message(json_str)

	assert_not_null(parsed, "Should decode successfully")
	assert_eq(parsed["type"], MessageTypes.PLAYER_INPUT, "Type should be player_input")
	assert_eq(parsed["data"]["sequence"], 42, "Sequence should match")
	assert_eq(parsed["data"]["move_direction"]["x"], 0.5, "Move X should match")
	assert_eq(parsed["data"]["move_direction"]["y"], -0.5, "Move Y should match")
	assert_eq(parsed["data"]["aim_angle"], 1.57, "Aim angle should match")
	assert_eq(parsed["data"]["actions"], ["jump"], "Actions should match")

func test_encode_ping() -> void:
	var json_str := SerializationScript.encode_ping()
	var parsed := SerializationScript.decode_message(json_str)

	assert_not_null(parsed, "Should decode successfully")
	assert_eq(parsed["type"], MessageTypes.PING, "Type should be ping")
	assert_has(parsed["data"], "client_time", "Should have client_time")

func test_encode_connect_response_success() -> void:
	var json_str := SerializationScript.encode_connect_response(true, "player-123", 1000)
	var parsed := SerializationScript.decode_message(json_str)

	assert_not_null(parsed, "Should decode successfully")
	assert_eq(parsed["type"], MessageTypes.CONNECT_RESPONSE, "Type should be connect_response")
	assert_true(parsed["data"]["success"], "Success should be true")
	assert_eq(parsed["data"]["player_id"], "player-123", "Player ID should match")
	assert_eq(parsed["data"]["server_tick"], 1000, "Server tick should match")
	assert_eq(parsed["data"]["tick_rate"], GameConstants.TICK_RATE, "Tick rate should match")

func test_encode_connect_response_failure() -> void:
	var json_str := SerializationScript.encode_connect_response(false, "", 0, "Server full")
	var parsed := SerializationScript.decode_message(json_str)

	assert_not_null(parsed, "Should decode successfully")
	assert_false(parsed["data"]["success"], "Success should be false")
	assert_eq(parsed["data"]["error"], "Server full", "Error message should match")

func test_encode_game_state() -> void:
	var players := {}
	var player := PlayerState.new("p1", "Alice")
	player.position = Vector2(100, 200)
	player.velocity = Vector2(10, 20)
	player.aim_angle = 0.5
	players["p1"] = player

	var json_str := SerializationScript.encode_game_state(500, players)
	var parsed := SerializationScript.decode_message(json_str)

	assert_not_null(parsed, "Should decode successfully")
	assert_eq(parsed["type"], MessageTypes.GAME_STATE, "Type should be game_state")
	assert_eq(parsed["data"]["tick"], 500, "Tick should match")
	assert_has(parsed["data"]["players"], "p1", "Should have player p1")

	var p1_data = parsed["data"]["players"]["p1"]
	assert_eq(p1_data["name"], "Alice", "Player name should match")
	assert_eq(p1_data["position"]["x"], 100.0, "Position X should match")
	assert_eq(p1_data["position"]["y"], 200.0, "Position Y should match")

func test_encode_state_delta() -> void:
	var players := {}
	var player := PlayerState.new("p1", "Bob")
	player.position = Vector2(150, 250)
	players["p1"] = player

	var json_str := SerializationScript.encode_state_delta(501, 42, players)
	var parsed := SerializationScript.decode_message(json_str)

	assert_not_null(parsed, "Should decode successfully")
	assert_eq(parsed["type"], MessageTypes.STATE_DELTA, "Type should be state_delta")
	assert_eq(parsed["data"]["tick"], 501, "Tick should match")
	assert_eq(parsed["data"]["last_processed_input"], 42, "Last processed input should match")

func test_encode_player_joined() -> void:
	var player := PlayerState.new("p2", "Charlie")
	player.position = Vector2(50, 50)

	var json_str := SerializationScript.encode_player_joined(player)
	var parsed := SerializationScript.decode_message(json_str)

	assert_not_null(parsed, "Should decode successfully")
	assert_eq(parsed["type"], MessageTypes.PLAYER_JOINED, "Type should be player_joined")
	assert_eq(parsed["data"]["id"], "p2", "Player ID should match")
	assert_eq(parsed["data"]["name"], "Charlie", "Player name should match")

func test_encode_player_left() -> void:
	var json_str := SerializationScript.encode_player_left("p2")
	var parsed := SerializationScript.decode_message(json_str)

	assert_not_null(parsed, "Should decode successfully")
	assert_eq(parsed["type"], MessageTypes.PLAYER_LEFT, "Type should be player_left")
	assert_eq(parsed["data"]["player_id"], "p2", "Player ID should match")

func test_encode_pong() -> void:
	var json_str := SerializationScript.encode_pong(12345)
	var parsed := SerializationScript.decode_message(json_str)

	assert_not_null(parsed, "Should decode successfully")
	assert_eq(parsed["type"], MessageTypes.PONG, "Type should be pong")
	assert_eq(parsed["data"]["client_time"], 12345, "Client time should match")
	assert_has(parsed["data"], "server_time", "Should have server_time")

func test_encode_error() -> void:
	var json_str := SerializationScript.encode_error("Something went wrong")
	var parsed: Variant = SerializationScript.decode_message(json_str)

	assert_not_null(parsed, "Should decode successfully")
	assert_eq(parsed["type"], MessageTypes.ERROR, "Type should be error")
	assert_eq(parsed["data"]["message"], "Something went wrong", "Error message should match")

func test_parse_player_input() -> void:
	var data := {
		"sequence": 99,
		"move_direction": {"x": 0.7, "y": -0.3},
		"aim_angle": 2.5,
		"actions": ["fire", "boost"]
	}

	var result := SerializationScript.parse_player_input(data)

	assert_eq(result["sequence"], 99, "Sequence should match")
	assert_eq(result["move_direction"], Vector2(0.7, -0.3), "Move direction should match")
	assert_eq(result["aim_angle"], 2.5, "Aim angle should match")
	assert_eq(result["actions"], ["fire", "boost"], "Actions should match")

func test_parse_player_input_defaults() -> void:
	var result := SerializationScript.parse_player_input({})

	assert_eq(result["sequence"], 0, "Sequence should default to 0")
	assert_eq(result["move_direction"], Vector2.ZERO, "Move direction should default to zero")
	assert_eq(result["aim_angle"], 0.0, "Aim angle should default to 0")
	assert_eq(result["actions"], [], "Actions should default to empty array")
