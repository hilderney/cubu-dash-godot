class_name SaveFactory
extends RefCounted


static func make_default() -> SavePort:
	return FileSaveAdapter.new()
