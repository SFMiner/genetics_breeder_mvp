extends Control
class_name BreedingPanel
## BreedingPanel - UI for selecting dragon parents and initiating breeding
##
## Educational Purpose: Guides students through the breeding process,
## showing selected parents and enabling the breed action.

signal breed_requested()
signal parent_a_slot_clicked()
signal parent_b_slot_clicked()

@onready var parent_a_slot: Button = $ParentASlot
@onready var parent_b_slot: Button = $ParentBSlot
@onready var breed_button: Button = $BreedButton
@onready var instructions_label: Label = $InstructionsLabel

## Currently displayed parent IDs
var displayed_parent_a_id: int = -1
var displayed_parent_b_id: int = -1


func _ready() -> void:
	# Connect button signals
	parent_a_slot.pressed.connect(_on_parent_a_slot_pressed)
	parent_b_slot.pressed.connect(_on_parent_b_slot_pressed)
	breed_button.pressed.connect(_on_breed_button_pressed)
	
	# Initial state
	_update_display()


func _on_parent_a_slot_pressed() -> void:
	parent_a_slot_clicked.emit()


func _on_parent_b_slot_pressed() -> void:
	parent_b_slot_clicked.emit()


func _on_breed_button_pressed() -> void:
	if GeneticsState.can_breed():
		breed_requested.emit()


func set_parent_a(dragon_id: int) -> void:
	## Display a dragon in the Parent A slot
	displayed_parent_a_id = dragon_id
	_update_display()


func set_parent_b(dragon_id: int) -> void:
	## Display a dragon in the Parent B slot
	displayed_parent_b_id = dragon_id
	_update_display()


func clear_parents() -> void:
	## Clear both parent slots
	displayed_parent_a_id = -1
	displayed_parent_b_id = -1
	_update_display()


func _update_display() -> void:
	## Update all UI elements based on current state
	
	# Update Parent A slot
	if displayed_parent_a_id >= 0:
		var dragon_a: Dictionary = GeneticsState.get_dragon(displayed_parent_a_id)
		if not dragon_a.is_empty():
			var geno: String = GeneticsState.get_genotype_summary(displayed_parent_a_id)
			var name: String = dragon_a.get("name", "Dragon")
			parent_a_slot.text = "Parent A:\n%s (%s)" % [name, geno]
		else:
			parent_a_slot.text = "Parent A:\n[Click to Select]"
	else:
		parent_a_slot.text = "Parent A:\n[Click to Select]"
	
	# Update Parent B slot
	if displayed_parent_b_id >= 0:
		var dragon_b: Dictionary = GeneticsState.get_dragon(displayed_parent_b_id)
		if not dragon_b.is_empty():
			var geno: String = GeneticsState.get_genotype_summary(displayed_parent_b_id)
			var name: String = dragon_b.get("name", "Dragon")
			parent_b_slot.text = "Parent B:\n%s (%s)" % [name, geno]
		else:
			parent_b_slot.text = "Parent B:\n[Click to Select]"
	else:
		parent_b_slot.text = "Parent B:\n[Click to Select]"
	
	# Update breed button
	var can_breed: bool = (displayed_parent_a_id >= 0 and 
						   displayed_parent_b_id >= 0 and
						   displayed_parent_a_id != displayed_parent_b_id)
	breed_button.disabled = not can_breed
	
	# Update instructions
	if displayed_parent_a_id < 0:
		instructions_label.text = "Click a dragon, then click 'Parent A' to select it"
	elif displayed_parent_b_id < 0:
		instructions_label.text = "Now select a different dragon as Parent B"
	elif can_breed:
		instructions_label.text = "Ready! Click 'Breed' to create offspring"
	else:
		instructions_label.text = "Select two different dragons to breed"
