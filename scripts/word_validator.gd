extends Node
## Loads the bundled word lists once at startup and exposes fast validity checks.
## Accepts either English or Filipino/Tagalog words as valid.

const WORDLIST_PATHS: Array[String] = [
	"res://data/wordlists/en.txt",
	"res://data/wordlists/fil.txt",
]

var _words: Dictionary = {}

func _ready() -> void:
	for path in WORDLIST_PATHS:
		_load_wordlist(path)

func _load_wordlist(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("WordValidator: could not open %s" % path)
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges().to_lower()
		if line.length() >= 3:
			_words[line] = true
	file.close()

func is_valid_word(word: String) -> bool:
	return _words.has(word.to_lower())

func word_count() -> int:
	return _words.size()
