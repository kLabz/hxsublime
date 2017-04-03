import python.NativeStringTools;
import python.Tuple;
import python.lib.xml.etree.ElementTree;

import sublime.Region;
import sublime.Sublime;
import sublime.View;
import sublime.plugin.EventListener;

import util.BuildHelper;
import util.SignatureHelper;

using StringTools;

@:enum abstract FieldCompletionKind(String) {
    var Var = "var";
    var Method = "method";
    var Type = "type";
    var Package = "package";
}

typedef CompletionContext = {
    prev:String,
    completionType: CompletionType
}

class HaxeComplete extends EventListener {
    override function on_query_completions(view:View, prefix:String, locations:Array<Int>):Tuple2<Array<Tuple2<String,String>>, Int> {
        var pos = locations[0];
        var result = getHaxeBuild(view, prefix, pos);

        var xml = try {
            ElementTree.XML(result);
        } catch (_:Dynamic) {
            return null;
        }

        var result:Array<Tuple2<String,String>> = [];
        var completionContext = getCompletionType(view, prefix, pos);

        switch (completionContext.completionType) {
            case Toplevel:
                for (e in xml.findall("i")) {
                    var name = e.text;
                    var kind = e.attrib.get("k", "");
                    var hint = switch (kind) {
                        case "local" | "member" | "static" | "enum" | "global":
                            SignatureHelper.prepareSignature(e.attrib.get("t", null));
                        default:
                            "";
                    }
                    result.push(Tuple2.make('$name$hint\t$kind', e.text));
                }

            case Field:
                for (e in xml.findall("i")) {
                    var name = e.attrib.get("n", "?");
                    var kind:FieldCompletionKind = cast e.attrib.get("k", "");
                    var hint = switch (kind) {
                        case Var | Method: SignatureHelper.prepareSignature(e.find("t").text);
                        case Type: "\ttype";
                        case Package: "\tpackage";
                    }
                    result.push(Tuple2.make('$name$hint', name));
                }

            case Argument:
                // TODO (?): return all matches for wanted type
                return Tuple2.make([], 0); //, Sublime.INHIBIT_WORD_COMPLETIONS);
        }

        return Tuple2.make(result, Sublime.INHIBIT_WORD_COMPLETIONS);
    }

    function getHaxeBuild(view:View, prefix:String, pos:Int):String {
        var scopeName = view.scope_name(pos);
        if (scopeName.indexOf("source.haxe") != 0) {
            return null;
        }

        var scopes = scopeName.split(" ");
        for (scope in scopes) {
            if (scope.startsWith("comment")) return null;
        }

        var fileName = view.file_name();
        if (fileName == null) return null;

        var offset = pos - prefix.length;
        var src = view.substr(new Region(0, view.size()));

        var b = NativeStringTools.encode(src.substr(0, offset), "utf-8");
        var bytePos = b.length;

        var context = getCompletionType(view, prefix, pos);
        var mode = if (context.completionType.match(Toplevel)) "@toplevel" else "";
        if (context.prev == "(") bytePos++;

        return BuildHelper.build(view, '$fileName@$bytePos$mode');
    }

    function getCompletionType(view:View, prefix:String, pos:Int):CompletionContext {
        var offset = pos - prefix.length;
        var src = view.substr(new Region(0, view.size()));
        var prev = src.charAt(offset - 1);

        var type = switch (prev) {
            case ".": Field;
            case "(": Toplevel; //Argument;
            case ",": Toplevel; //Argument;
            default: Toplevel;
        };

        return {
            prev: prev,
            completionType: type
        };
    }

}
