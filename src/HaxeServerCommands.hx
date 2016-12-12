import python.Lib;
import python.KwArgs;

import sublime.Edit;
import sublime.plugin.TextCommand;

private typedef Args = {action: ServerAction};

@:enum abstract ServerAction(String) from String to String {
    var Start = "start";
    var Stop = "stop";
    var Restart = "restart";
}

class HaxeServerCommands extends TextCommand<Args> {

    override function run(edit:Edit, ?args:KwArgs<Args>) {
        var args = args.typed();
        var server = HaxeServer.instance;

        switch (args.action) {
            case Start:
            server.start(HaxeServer.PORT);

            case Stop:
            server.stop();
            
            case Restart:
            server.stop();
            server.start(HaxeServer.PORT);
        }
    }

}