package util;

import python.Bytes;
import python.Syntax;
import python.lib.Codecs;
import python.lib.Os;
import python.lib.os.Path;

import sublime.Region;
import sublime.Sublime;
import sublime.View;

typedef PositionInfos = {
    path:String,
    line:Int,
    start:Int
}

class Utils {
    /**
        Convert normalized path returned by Haxe to the OS path.
    **/
    public static function convertPath(path:String):String {
        if (Sys.systemName() == "Windows") {
            var r = Path.split(path), dir = r._1, file = r._2;
            for (f in Os.listdir(dir)) {
                if (f.toLowerCase() == file)
                    return Path.join(dir, f);
            }
        }
        return path;
    }

    public static function extractPosition(text:String):PositionInfos {
        var re = ~/^(.*):(\d+): (lines|characters) (\d+)-\d+$/;
        if (!re.match(text)) {
            // trace("Invalid position info: " + text);
            return null;
        }

        var path = Utils.convertPath(re.matched(1));
        var line = Std.parseInt(re.matched(2));
        var mode = re.matched(3);
        var start = (mode == "lines") ? 0 : Std.parseInt(re.matched(4));

        return {
            path: path,
            line: line,
            start: start
        }
    }

    public static function displayPosition(posInfos:PositionInfos):Void {
        if (posInfos == null) return;

        var window = Sublime.active_window();
        var view = window.open_file(posInfos.path);
        gotoPosition(view, posInfos.line, posInfos.start);
    }


    public static function gotoPosition(view:View, line:Int, start:Int):Void {
        if (view.is_loading()) {
            Sublime.set_timeout(gotoPosition.bind(view, line, start), 10);
            return;
        }

        var point = view.text_point(line - 1, 0);

        if (start > 0) {
            var lineString = view.substr(view.full_line(point));
            var src:Bytes = Syntax.arrayAccess(Codecs.encode(lineString, "utf-8"), 0, start);
            var col = Codecs.decode(src, "utf-8").length;
            point = view.text_point(line - 1, col);
        }

        view.sel().clear();
        view.sel().add(new Region(point));
        Sublime.set_timeout(view.show_at_center.bind(point), 10);
    }
}