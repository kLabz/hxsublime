import python.Lib;
import python.Bytes;
import python.Syntax;
import python.lib.Codecs;
import python.lib.xml.etree.ElementTree;

import sublime.Edit;
import sublime.Region;
import sublime.Sublime;
import sublime.View;
import sublime.plugin.TextCommand;

import util.BuildHelper;
import util.Utils;

using StringTools;

class HaxeFindUsage extends TextCommand<Dynamic> {
    override function run(edit:Edit, ?_):Void {
        var fileName = view.file_name();
        if (fileName == null) return;

        var sel = view.sel()[0];
        var word = view.word(sel);
        var content = view.substr(new Region(0, word.b));
        var offset = Codecs.encode(content, "utf-8").length;
        var result = BuildHelper.build(view, '$fileName@$offset@usage');

        var xml = try {
            ElementTree.XML(result);
        } catch(_:Dynamic) {
            // trace("No position info:\n" + result);
            return;
        }

        var pos = xml.findall("pos");
        if (pos == null || pos.length == 0) return;

        var positions = pos.map(function (el) return el.text);
        
        var positionsItems = positions.map(function (pos) {
            var re = ~/^(.*):(\d+: (lines|characters) \d+-\d+)$/;
            if (!re.match(pos)) return [pos];
            return [re.matched(1), 'Line ${re.matched(2)}'];
        });

        positionsItems.unshift([
            'Found ${positions.length} usages',
            'Select this item to go back'
        ]);

        var pos = view.rowcol(sel.begin());
        var callback = gotoPosition.bind(
            {path: fileName, line: pos[0] + 1, start: pos[1]},
            positions
        );

        var window = view.window();
        window.show_quick_panel(positionsItems, callback, 0, 0, callback);
    }

    function gotoPosition(initialPos:PositionInfos, positions:Array<String>, index:Int):Void {
        if (index < 1) return Utils.displayPosition(initialPos);

        var posInfos = Utils.extractPosition(positions[--index]);
        Utils.displayPosition(posInfos);
    }
}