package mdpopups;

import python.Dict;

import sublime.View;

@:pythonImport("mdpopups")
extern class MdPopups {
	// See: https://facelessuser.github.io/sublime-markdown-popups/usage/#api-usage

	static function show_popup(
		view:View,
		content:String,
		?md:Bool,
		?css:String,
		?flags:Int,
		?location:Int,
		?max_width:Int,
		?max_height:Int,
		?on_navigate:Void->Void,
		?on_hide:Void->Void,
		?wrapper_class:String,
		?template_vars:Dict<String, Dynamic>,
		?nl2br:Bool
	):Void;

    static function hide_popup(view:View):Void;
}