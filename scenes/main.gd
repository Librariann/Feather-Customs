extends Node2D

@onready var bird_type_label: Label = $CanvasLayer/HBoxContainer/PassportPanel/VBoxContainer/BirdTypeLabel
@onready var destination_label: Label = $CanvasLayer/HBoxContainer/PassportPanel/VBoxContainer/DestinationLabel
@onready var stamp_label: Label = $CanvasLayer/HBoxContainer/PassportPanel/VBoxContainer/StampLabel
@onready var baggage_label: Label = $CanvasLayer/HBoxContainer/PassportPanel/VBoxContainer/BaggageLabel
@onready var score_label: Label = $CanvasLayer/HBoxContainer/ScoreLabel
@onready var result_label: Label = $CanvasLayer/HBoxContainer/ResultLabel

var current_bird: Dictionary = {}
var score := 0

var bird_master_data: Array = []

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

	current_bird = generate_bird()
	display_bird(current_bird)


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


func generate_passport(bird_info: Dictionary) -> Dictionary:
	return {
		"passport_id": "FC-" + str(randi_range(1000, 9999)) + "-" + str(randi_range(1000, 9999)),
		"bird_id": bird_info["id"],
		"bird_name": bird_info["name_ko"],
		"destination": destinations.pick_random(),
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
	if baggage.has("물고기"):
		return "confiscate"
	if passport["is_valid"] == false:
		return "hold"
	return "approve"

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
	current_bird = generate_bird()
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
