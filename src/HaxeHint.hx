import python.Lib;
import python.KwArgs;
import python.lib.xml.etree.ElementTree;

import sublime.Edit;
import sublime.Region;
import sublime.View;
import sublime.plugin.TextCommand;

using StringTools;

private typedef Args = {input:String};
private typedef ArgDef = {name:String, type:String};

class HaxeHint extends TextCommand<Args> {

    override function run(edit:Edit, ?args:KwArgs<Args>) {
        var args = args.typed();
        var input = args.input;
        if (input == ',') input += ' ';
        view.run_command("insert", Lib.anonAsDict({characters: input}));
        if (input == ')') return hideHint(view);

        var pos = view.sel()[0].a + 1;
        var result = HaxeComplete.instance.getHaxeBuild(view, '(', pos, Argument);

        var xml = try {
            ElementTree.XML(result);
        } catch (_:Dynamic) {
            return;
        }

        trace("Found hint: " + xml.text);
        displayHint(view, edit, parseHint(view.substr(new Region(0, pos)), xml.text, pos));
    }

    private function parseHint(src:String, hint:String, ?pos:Int = 0):String {
        // content : String -> ?flags : Null<Int> -> ?location : Null<Int> -> ?max_width : Null<Int> -> ?max_height : Null<Int> -> ?on_navigate : Null<Void -> Void> -> ?on_hide : Null<Void -> Void> -> Void

        // Get arguments definition
        var args:Array<ArgDef> = extractArgs(hint);
        var ret:ArgDef = args.pop();

        // Get function name
        // TODO: get current arg position
        var currentArg = 0;
        var fxName:String = extractFxName(src);
        if (fxName == null) return null;

        // TODO: hint markup
        return [
            'Function $fxName', 
            Lambda.mapi(args, function (i, arg) {
                var ret = '';
                if (i == currentArg) ret += ' > ';
                ret += 'Argument #$i: ${arg.name} of type ${arg.type}';
                return ret;
            }).join('\n'), 
            'Return type: ${ret.type}'
        ].join('\n');
    }

    // TODO: fix + extract current arg position
    private function extractFxName(src:String):String {
        var nParens = 0;
        
        var lastCParen = -1;
        var lastOParen = -1;

        while (true) {
            lastCParen = src.lastIndexOf(")");
            lastOParen = src.lastIndexOf("(");

            if (lastCParen != -1 && lastCParen > lastOParen) {
                src = src.substring(0, lastCParen);
                lastCParen = src.lastIndexOf(")");
                nParens++;
                
                if (lastCParen == -1) {
                    for (i in 0...nParens) {
                        src = src.substring(0, lastOParen);
                        lastOParen = src.lastIndexOf("(");
                    }

                    break;
                }
            } else {
                break;
            }
                
        }
        
        var fxArgsReg = ~/\(([^,]+,)*$/;
        var fxArgsSrc = src.substr(lastOParen, src.length);
        trace(fxArgsSrc);
        // TODO

        var fxNameReg = ~/([a-zA-Z0-9<>_]+)\($/;
        var fxNameSrc = src.substr(0, lastOParen + 1).replace("\n", " ");
        if (fxNameReg.match(fxNameSrc)) {
            return fxNameReg.matched(1).trim();
        }
            
        return "Unknown function";
    }

    private function extractArgs(hint:String):Array<ArgDef> {
        var pos:Int = 0;
        var args:Array<ArgDef> = [];

        while (pos != -1) {
            var nextPos:Int = findArgumentEnd(hint, pos);
            
            if (nextPos == -1) {
                var sub = hint.substr(pos);
                var argDef = getArgDefinition(sub);
                trace("Return type: " + argDef.type);
                args.push(argDef);
                break;

            } else {
                var sub = hint.substr(pos, nextPos - pos);
                var argDef = getArgDefinition(sub);
                trace("Arg name: " + argDef.name);
                trace("Arg type: " + argDef.type);
                args.push(argDef);
                pos = nextPos + 1;
            }
        }
            
        return args;
    }
    
    private function findArgumentEnd(hint:String, start:Int = 0):Int {
        var nextArrow:Int = hint.indexOf("->", start);
        var nextOChevron:Int = hint.indexOf("<", start);
        
        if (nextArrow == -1) {
            // End of hint
            return -1;
        } else {
            if (nextOChevron == -1 || nextArrow < nextOChevron) {
                return nextArrow;
            } else {
                start = nextOChevron + 1;
                nextOChevron = hint.indexOf("<", start);
                var nextCChevron = hint.indexOf(">", start);
                
                if (nextOChevron == -1 || nextCChevron < nextOChevron) {
                    return findArgumentEnd(hint, nextCChevron + 1);
                } else {
                    return findArgumentEnd(hint, nextOChevron + 1);
                }
                
            }
        }
        return 0;
    }
    
    private function getArgDefinition(argStr:String):{name:String, type:String} {
        if (argStr.startsWith(">")) argStr = argStr.substring(1);
        var subArg = argStr.split(":");

        if (subArg.length > 1) {
            return {
                name: subArg[0].trim(),
                type: subArg[1].trim()
            }
        } else {
            return {
                name: null,
                type: argStr.trim()
            }
        }
    }

    private function hideHint(view:View):Void {
        var window = view.window();
        window.run_command("hide_panel", Lib.anonAsDict({"panel": "output.exec"}));
    }

    private function displayHint(view:View, edit:Edit, hint:String):Void {
        if (hint == null) return hideHint(view);

        var window = view.window();
        var outputPanel:View = untyped window.find_output_panel("exec");

        outputPanel.erase(edit,  new Region(0, outputPanel.size()));
        outputPanel.run_command("append", Lib.anonAsDict({"characters": hint}));

        window.run_command("show_panel", Lib.anonAsDict({"panel": "output.exec"}));
    }

}
