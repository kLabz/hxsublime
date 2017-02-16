import python.Lib;
import python.KwArgs;
import python.lib.xml.etree.ElementTree;

import sublime.Edit;
import sublime.Region;
import sublime.plugin.TextCommand;

using StringTools;

private typedef Args = {input:String};
private typedef ArgDef = {name:String, type:String};

class HaxeHint extends TextCommand<Args> {

    override function run(edit:Edit, ?args:KwArgs<Args>) {
        var args = args.typed();
        view.run_command("insert", Lib.anonAsDict({characters: args.input}));
        var pos = view.sel()[0].a + 1;

        trace("Showing hint " + args);
        trace(pos);
        trace(view.sel()[0].a);

        var result = HaxeComplete.instance.getHaxeBuild(view, args.input, pos, Argument);
        trace(result);

        var xml = try {
            ElementTree.XML(result);
        } catch (_:Dynamic) {
            trace("No hint:\n" + result);
            return;
        }

        trace("Found hint: " + xml.text);
        view.show_popup(parseHint(view.substr(new Region(0, pos)), xml.text));
    }

    private function parseHint(src:String, hint:String, ?pos:Int = 0):String {
        // content : String -> ?flags : Null<Int> -> ?location : Null<Int> -> ?max_width : Null<Int> -> ?max_height : Null<Int> -> ?on_navigate : Null<Void -> Void> -> ?on_hide : Null<Void -> Void> -> Void

        // Get arguments definition
        var args:Array<ArgDef> = extractArgs(hint);
        trace(args);

        // TODO: get function name
        var fxName:String = extractFxName(src);
        trace(fxName);

        // TODO: get current arg position

        // TODO: hint markup
        return hint;
    }

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
        
        src = src.substr(0, lastOParen + 1).replace("\n", " ");
        var fxReg = ~/([a-zA-Z0-9<>\s_]+)\($/;
        
        if (fxReg.match(src)) {
            return fxReg.matched(1).trim();
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

}
