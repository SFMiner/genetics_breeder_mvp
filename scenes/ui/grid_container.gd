extends GridContainer

var cells : Array

func _ready():
	cells = get_children()

func clear_empties():
	for cell in cells: 
		if cell.text == "": 
			cell.visible = false
		else:
			cell.visible = true
