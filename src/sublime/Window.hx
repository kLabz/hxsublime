package sublime;

import haxe.extern.EitherType;

extern class Window {
    function folders():Array<String>;

    function open_file(file_name:String, ?flags:Int):View;

    function create_output_panel(name:String):View;

    function show_quick_panel(
    	items:Array<EitherType<String, Array<String>>>,
    	onDone:Int->Void,
    	?flags:Int = 0,
    	?selectedIndex:Int = 0,
    	?onHighlighted:Int->Void
    ):Void;

    function run_command(cmd:String, ?args:Dynamic):Void;
}