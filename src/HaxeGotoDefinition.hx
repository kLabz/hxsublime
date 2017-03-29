import python.Bytes;
import python.Syntax;
import python.lib.Codecs;
import python.lib.xml.etree.ElementTree;

import sublime.Edit;
import sublime.Region;
import sublime.Sublime;
import sublime.View;
import sublime.plugin.TextCommand;

using StringTools;

class HaxeGotoDefinition extends TextCommand<Dynamic> {
    override function run(edit:Edit, ?_):Void {
        var fileName = view.file_name();
        if (fileName == null)
            return null;

        var word = view.word(view.sel()[0]);
        var content = view.substr(new Region(0, word.b));
        var offset = Codecs.encode(content, "utf-8").length;
        var result = BuildHelper.build(view, '$fileName@$offset@position');

        var xml = try {
            ElementTree.XML(result);
        } catch (_:Dynamic) {
            trace("No position info:\n" + result);
            return;
        }

        var pos = xml.find("pos");
        if (pos == null) return;

        var posInfos = Utils.extractPosition(pos.text);
        Utils.displayPosition(posInfos);
    }
}