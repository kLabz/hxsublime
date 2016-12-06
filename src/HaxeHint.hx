import python.Lib;
import python.KwArgs;

import sublime.Edit;
import sublime.plugin.TextCommand;

private typedef Args = {input:String};

class HaxeHint extends TextCommand<Args> {
    override function run(edit:Edit, ?args:KwArgs<Args>) {
        var args = args.typed();
        view.run_command("insert", Lib.anonAsDict({characters: args.input}));

        trace("Showing hint " + args);
    }
}
