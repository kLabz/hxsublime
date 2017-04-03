import haxe.xml.Fast;
import python.Lib;
import python.KwArgs;
import python.NativeStringTools;

import sublime.Edit;
import sublime.Region;
import sublime.View;
import sublime.plugin.TextCommand;

using StringTools;

private typedef Args = {input:String};
private typedef ArgDef = {name:String, type:String};

private typedef FunctionInfos = {
    name:String,
    attrIndex:Int
}

private typedef Hint = {
    text:String,
    currLine:Int
}

class HaxeHint extends TextCommand<Args> {

    override function run(edit:Edit, ?args:KwArgs<Args>) {
        var fileName = view.file_name();
        var selPos = view.sel()[0].a + 1;
        var tmpSrc = view.substr(new Region(0, selPos));
        var pos = findOpenParen(tmpSrc) + 1;
        if (pos <= 0) return hideHint(view);

        var b = NativeStringTools.encode(view.substr(new Region(0, pos)), "utf-8");
        var bytePos = b.length;

        var result = BuildHelper.build(view, '$fileName@$bytePos');
        var xml = try {
            new Fast(Xml.parse(result));
        } catch (_:Dynamic) {
            return hideHint(view);
        }

        /*var typesResult = BuildHelper.build(view, '$fileName@${++bytePos}@toplevel');
        var typesXml = try {
            new Fast(Xml.parse(typesResult));
        } catch (_:Dynamic) {
            return hideHint(view);
        }*/

        displayHint(view, edit, parseHint(tmpSrc, /*typesXml.nodes.i, */xml.node.type, selPos));
    }

    function parseHint(src:String, /*typesXml:List<Fast>, */hint:Fast, ?pos:Int = 0):Hint {
        var markup = [];
        var currLine = 0;

        var doc:String = hint.has.d ? hint.att.d : null;
        if (doc != null) {
            var docArr = doc.split("\n");
            docArr = docArr.slice(1, -1).map(function(a) return " * " + a.trim());
            docArr.unshift('/**');
            docArr.push('*/');

            markup = markup.concat(docArr);
        }

        // Get arguments definition
        var args:Array<ArgDef> = extractArgs(hint.innerHTML.htmlUnescape());
        var ret:ArgDef = args.pop();

        // Get function name
        var fxInfos:FunctionInfos = extractFxInfos(src);
        if (fxInfos == null) return null;

        markup.push('function ${fxInfos.name}(');
        Lambda.mapi(args, function (i, arg) {
            var isCurrent = (i == fxInfos.attrIndex);

            var ret = isCurrent ? '  > ' : '    ';
            ret += '${arg.name}:${arg.type}';

            if (isCurrent) {
                currLine = markup.length;
            //     TODO: extract doc from typesXml
            }

            markup.push(ret);
            return ret;
        });
        markup.push('):${ret.type}');

        return {
            text: markup.join('\n'),
            currLine: currLine
        };
    }

    function findOpenParen(str:String, ?closePos:Int = null):Int {
        if (str.length == 0) return -1;
        if (closePos == null) closePos = str.length - 1;
        var openPos = closePos;
        var counter = 1;

        while (counter > 0) {
            if (openPos <= 0) return -1;

            var c = str.charAt(--openPos);
            if (c == '(') counter--;
            else if (c == ')') counter++;
        }

        return openPos;
    }

    function extractFxInfos(src:String):FunctionInfos {
        var lastOParen = findOpenParen(src);

        var re = ~/(\([^\(\)]*\))/;
        var fxArgsSrc = src.substr(lastOParen + 1, src.length);
        while (re.match(fxArgsSrc)) fxArgsSrc = re.replace(fxArgsSrc, "");
        var attrIndex = fxArgsSrc.split(",").length - 1;

        var fxNameReg = ~/([a-zA-Z0-9<>_]+)\($/;
        var fxNameSrc = src.substr(0, lastOParen + 1).replace("\n", " ");
        if (fxNameReg.match(fxNameSrc)) {
            return {
                name: fxNameReg.matched(1).trim(),
                attrIndex: attrIndex
            };
        }

        return null;
    }

    function extractArgs(hint:String):Array<ArgDef> {
        var pos:Int = 0;
        var args:Array<ArgDef> = [];

        while (pos != -1) {
            var nextPos:Int = findArgumentEnd(hint, pos);

            if (nextPos == -1) {
                var sub = hint.substr(pos);
                var argDef = getArgDefinition(sub);
                args.push(argDef);
                break;

            } else {
                var sub = hint.substr(pos, nextPos - pos);
                var argDef = getArgDefinition(sub);
                if (argDef.name != null) args.push(argDef);
                pos = nextPos + 1;
            }
        }

        return args;
    }
    
    function findArgumentEnd(hint:String, start:Int = 0):Int {
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
    
    function getArgDefinition(argStr:String):{name:String, type:String} {
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

    function hideHint(view:View):Void {
        var window = view.window();
        window.run_command("hide_panel", Lib.anonAsDict({"panel": "output.exec"}));
    }

    function displayHint(view:View, edit:Edit, hint:Hint):Void {
        if (hint == null) return hideHint(view);

        var window = view.window();
        var outputPanel:View = untyped window.find_output_panel("exec");

        if (outputPanel == null) {
            outputPanel = window.create_output_panel("exec");
        }

        outputPanel.set_read_only(false);
        outputPanel.run_command("set_file_type", Lib.anonAsDict({
            "syntax": "Packages/HxSublime/HaxeHint.tmLanguage"
        }));

        // Replace panel content
        outputPanel.erase(edit,  new Region(0, outputPanel.size()));
        outputPanel.run_command("append", Lib.anonAsDict({"characters": hint.text}));
        outputPanel.set_read_only(true);

        window.run_command("show_panel", Lib.anonAsDict({"panel": "output.exec"}));

        // Scroll into view
        Utils.gotoPosition(outputPanel, hint.currLine, 0);
    }

}
