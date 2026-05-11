extends Node2D

@onready var bird_type_label: Label = $CanvasLayer/HBoxContainer/PassportPanel/VBoxContainer/BirdTypeLabel
@onready var destination_label: Label = $CanvasLayer/HBoxContainer/PassportPanel/VBoxContainer/DestinationLabel
@onready var stamp_label: Label = $CanvasLayer/HBoxContainer/PassportPanel/VBoxContainer/StampLabel
@onready var baggage_label: Label = $CanvasLayer/HBoxContainer/PassportPanel/VBoxContainer/BaggageLabel
@onready var score_label: Label = $CanvasLayer/HBoxContainer/PassportPanel/VBoxContainer/ScoreLabel
@onready var result_label: Label = $CanvasLayer/HBoxContainer/PassportPanel/VBoxContainer/ResultLabel

var inspected_count := 0
var wave_size := 6
var destination_history: Array = []
var current_wind_rule: Dictionary = {}
var current_bird: Dictionary = {}
var score := 0
var banned_item := "물고기"
var bird_master_data: Array = []
var bird_queue: Array = []
var queue_size := 6


var destinations := [
	"북쪽 하늘",
	"남쪽 하늘",
	"동쪽 항로",
	"서쪽 항로"
]

var baggage_items := [
	"물고기",
	"나뭇가지",
	"씨앗",
	"조개껍데기",
	"편지봉투"
]

var stamp_types := [
	"원형"
]

func _ready():
	randomize()
	bird_master_data = load_birds()

	score = 0
	score_label.text = "점수: 0"
	result_label.text = "판정 대기"

	generate_bird_queue()
	current_bird = get_next_bird_from_queue()
	display_bird(current_bird)

func generate_bird_queue() -> void:
	bird_queue.clear()

	for i in range(queue_size):
		bird_queue.append(generate_bird())

	print("===== 대기열 생성 =====")
	print("대기열 수: ", bird_queue.size())

func get_next_bird_from_queue() -> Dictionary:
	if bird_queue.is_empty():
		generate_bird_queue()

	return bird_queue.pop_front()

func load_birds() -> Array:
	var file := FileAccess.open("res://data/birds.json", FileAccess.READ)

	if file == null:
		push_error("birds.json 파일을 읽을 수 없음")
		return []

	var text := file.get_as_text()
	var data = JSON.parse_string(text)

	if data == null:
		push_error("birds.json 파싱 실패")
		return []

	return data["birds"]


func generate_bird() -> Dictionary:
	#철새의 JSON 리스트가 비어있으면 생성하지않고 에러반환
	if bird_master_data.is_empty():
		push_error("철새 마스터 데이터가 비어 있음")
		return {}
	
	var bird_info: Dictionary = bird_master_data.pick_random()

	return {
		"bird": bird_info,
		"passport": generate_passport(bird_info),
		"stamp": generate_stamp(),
		"baggage": generate_baggage(bird_info)
	}
	
func pick_weighted_destination(priority_destination: String) -> String:
	var weighted_destinations := []

	for destination in destinations:
		weighted_destinations.append(destination)

	for i in range(3):
		weighted_destinations.append(priority_destination)

	return weighted_destinations.pick_random()

func pick_destination_by_wind() -> String:

	if current_wind_rule.is_empty():
		return destinations.pick_random()
	var rule_id: String = current_wind_rule.get("id", "")
	if rule_id == "north_wind":
		return pick_weighted_destination("북쪽 하늘")
	if rule_id == "south_wind":
		return pick_weighted_destination("남쪽 하늘")
	return destinations.pick_random()

func generate_passport(bird_info: Dictionary) -> Dictionary:
	return {
		"passport_id": "FC-" + str(randi_range(1000, 9999)) + "-" + str(randi_range(1000, 9999)),
		"bird_id": bird_info["id"],
		"bird_name": bird_info["name_ko"],
		"destination": pick_destination_by_wind(),
		"is_valid": randf() > 0.2
	}


func generate_stamp() -> Dictionary:
	return {
		"stamp_type": stamp_types.pick_random(),
		"rotation": [0, 90, 180, 270].pick_random(),
		"overlap_count": randi_range(0, 2)
	}


func generate_baggage(bird_info: Dictionary) -> Array:
	var result := []
	var count := randi_range(0, 2)

	if bird_info["trait"] == "extra_baggage":
		count += 1

	if bird_info["trait"] == "fish_carrier":
		result.append("물고기")

	for i in range(count):
		result.append(baggage_items.pick_random())

	return result
	
func display_bird(generated_bird: Dictionary) -> void:

	var bird_info: Dictionary = generated_bird["bird"]
	var passport: Dictionary = generated_bird["passport"]
	var stamp: Dictionary = generated_bird["stamp"]
	var baggage: Array = generated_bird["baggage"]
	
	bird_type_label.text = "새 종류: " + bird_info["name_ko"]
	destination_label.text = "목적지: " + passport["destination"]
	stamp_label.text = "도장: " + stamp["stamp_type"]
	baggage_label.text = "짐 태그: " + str(baggage)

func get_correct_action(bird: Dictionary) -> String:

	var passport: Dictionary = bird["passport"]
	var baggage: Array = bird["baggage"]
	
	if baggage.has(banned_item):
		return "confiscate"
		
	if passport["is_valid"] == false:
		return "hold"
		
	return "approve"
	
func record_destination(destination: String) -> void:
	destination_history.append(destination)

func get_recent_destinations() -> Array:
	var start_index = max(0, destination_history.size() - wave_size)
	return destination_history.slice(start_index, destination_history.size())

func count_destinations(destinations_to_count: Array) -> Dictionary:
	var result := {}

	for destination in destinations_to_count:
		if not result.has(destination):
			result[destination] = 0
		result[destination] += 1
	return result

func create_wind_rule_from_destinations(destinations_to_analyze: Array) -> Dictionary:
	var counts := count_destinations(destinations_to_analyze)

	var north_count: int = counts.get("북쪽 하늘", 0)
	var south_count: int = counts.get("남쪽 하늘", 0)
	var east_count: int = counts.get("동쪽 항로", 0)
	var west_count: int = counts.get("서쪽 항로", 0)

	if north_count >= 4:
		return {
			"id": "north_wind",
			"name": "북풍",
			"description": "북쪽 하늘로 향하는 철새가 급증했습니다. 다음 웨이브에서 북쪽 항로가 활성화됩니다.",
			"effect_type": "destination_bias",
			"target": "북쪽 하늘",
			"value": 30
		}

	if south_count >= 4:
		return {
			"id": "south_wind",
			"name": "남풍",
			"description": "남쪽 하늘로 향하는 철새가 급증했습니다. 다음 웨이브에서 남쪽 항로가 활성화됩니다.",
			"effect_type": "destination_bias",
			"target": "남쪽 하늘",
			"value": 30
		}

	if east_count + west_count >= 4:
		return {
			"id": "jet_stream",
			"name": "제트기류",
			"description": "동서 항로 이동량이 증가했습니다. 다음 웨이브에서 대기열 흐름이 빨라집니다.",
			"effect_type": "queue_shift",
			"target": "horizontal_routes",
			"value": 1
		}

	return {
		"id": "turbulence",
		"name": "난기류",
		"description": "목적지가 분산되어 바람길이 불안정합니다.",
		"effect_type": "unstable",
		"target": "all",
		"value": 1
	}
	

func apply_wind_rule_effect() -> void:
	if current_wind_rule.is_empty():
		return
		
	var rule_id: String = current_wind_rule.get("id", "")
	
	if rule_id == "north_wind":
		sort_queue_by_destination("북쪽 하늘")
		banned_item = "물고기"
		
	elif rule_id == "south_wind":
		sort_queue_by_destination("남쪽 하늘")
		banned_item = "물고기"
		
	elif rule_id == "jet_stream":
		shuffle_queue()
		banned_item = "물고기"
		
	elif rule_id == "turbulence":
		reverse_queue()
		banned_item = baggage_items.pick_random()
		print("난기류 발생 - 금지품 변경: ", banned_item)
		
	else:
		banned_item = "물고기"

func print_queue() -> void:
	print("===== 현재 대기열 =====")

	for i in range(bird_queue.size()):
		var bird = bird_queue[i]
		print(
			str(i + 1) + ". " +
			bird["bird"]["name_ko"] + " / " +
			bird["passport"]["destination"]
		)

func reverse_queue() -> void:
	bird_queue.reverse()
	print("대기열 역순 정렬")

func shuffle_queue() -> void:
	bird_queue.shuffle()
	print("대기열 랜덤 섞기")
	print_queue()

func sort_queue_by_destination(priority_destination: String) -> void:
	bird_queue.sort_custom(func(a, b):
		var a_destination = a["passport"]["destination"]
		var b_destination = b["passport"]["destination"]

		if a_destination == priority_destination and b_destination != priority_destination:
			return true

		if a_destination != priority_destination and b_destination == priority_destination:
			return false

		return false
	)

	print("대기열 우선순위 정렬: ", priority_destination)

func generate_wind_rule() -> void:
	var recent_destinations := get_recent_destinations()
	current_wind_rule = create_wind_rule_from_destinations(recent_destinations)

	apply_wind_rule_effect()

	print("===== 바람 규칙 생성 =====")
	print("검사 수: ", inspected_count)
	print("최근 목적지: ", recent_destinations)
	print("생성된 규칙: ", current_wind_rule)

	result_label.text = "새 바람 규칙: " + current_wind_rule["name"]

func judge_action(player_action: String) -> void:

	if current_bird.is_empty():
		return
	var correct_action := get_correct_action(current_bird)
	if player_action == correct_action:
		score += 10
		result_label.text = "정답"
	else:
		score -= 5
		result_label.text = "오답 / 정답: " + correct_action
	score_label.text = "점수: " + str(score)
	record_destination(current_bird["passport"]["destination"])
	inspected_count += 1
	if inspected_count % wave_size == 0:
		generate_wind_rule()
	current_bird = get_next_bird_from_queue()
	display_bird(current_bird)

func _on_next_bird_button_pressed():
	if bird_master_data.is_empty():
		push_error("철새 데이터가 비어 있음")
		return

	var generated_bird:= generate_bird()
	
	#철새 생성시 비어있으면 화면에 보여주지않고 종료
	if generated_bird.is_empty():
		return
		
	display_bird(generated_bird)

func _on_approve_button_pressed() -> void:
	judge_action("approve")

func _on_hold_button_pressed() -> void:
	judge_action("hold")

func _on_confiscate_button_pressed() -> void:
	judge_action("confiscate")
