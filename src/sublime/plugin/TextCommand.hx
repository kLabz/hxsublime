package sublime.plugin;

import python.KwArgs;

import sublime.Edit;
import sublime.View;

@:pythonImport("sublime_plugin", "TextCommand")
extern class TextCommand<T:{}> {
    var view(default,null):View;
    function run(edit:Edit, ?args:KwArgs<T>):Void;
    function is_enabled():Bool;
    function is_visible():Bool;
    function description():Null<String>;
}
