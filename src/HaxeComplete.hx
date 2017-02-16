import python.Bytes;
import python.NativeStringTools;
import python.Tuple;
import python.lib.Shutil;
import python.lib.os.Path;
import python.lib.xml.etree.ElementTree;
import sys.FileSystem;
import sys.io.File;

import sublime.Region;
import sublime.Sublime;
import sublime.View;
import sublime.def.Exec;
import sublime.plugin.EventListener;

import BuildHelper.Build;

using StringTools;

@:enum abstract FieldCompletionKind(String) {
    var Var = "var";
    var Method = "method";
    var Type = "type";
    var Package = "package";
}

enum CompletionType {
    Toplevel;
    Field;
    Argument;
}

class HaxeComplete extends EventListener {

    public static var instance(default,null):HaxeComplete;

    function new() {
        instance = this;
    }

    override function on_query_completions(view:View, prefix:String, locations:Array<Int>):Tuple2<Array<Tuple2<String,String>>, Int> {
        var pos = locations[0];
        // trace("Prefix: " + prefix);
        var completionType = getCompletionType(view, prefix, pos);
        var result = getHaxeBuild(view, prefix, pos); //, completionType);

        var xml = try {
            ElementTree.XML(result);
        } catch (_:Dynamic) {
            trace("No completion:\n" + result);
            return null;
        }

        var result:Array<Tuple2<String,String>> = [];

        switch (completionType) {
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
                // view.show_popup(xml.text);
                return Tuple2.make([], 0); //, Sublime.INHIBIT_WORD_COMPLETIONS);
        }

        return Tuple2.make(result, Sublime.INHIBIT_WORD_COMPLETIONS);
    }

    public function getCompletionType(view:View, prefix:String, pos:Int):CompletionType {
        var offset = pos - prefix.length;
        var src = view.substr(new Region(0, view.size()));
        var prev = src.charAt(offset - 1);
        // var cur = src.charAt(offset);

        return switch (prev) {
            case ".": Field;
            case "(": Field; //Argument;
            case ",": Field; //Argument;
            // case "(": Argument;
            // case ",": Argument;
            default: Toplevel;
        }
    }

    public function getHaxeBuild(view:View, prefix:String, pos:Int, ?completionType:CompletionType):String {
        var scopeName = view.scope_name(pos);
        if (scopeName.indexOf("source.haxe") != 0) {
            return null;
        }

        var scopes = scopeName.split(" ");
        for (scope in scopes) {
            if (scope.startsWith("string") || scope.startsWith("comment")) {
                return null;
            }
        }

        var fileName = view.file_name();
        if (fileName == null) {
            return null;
        }

        var offset = pos - prefix.length;
        var src = view.substr(new Region(0, view.size()));

        var b = NativeStringTools.encode(src.substr(0, offset), "utf-8");
        var bytePos = b.length;

        if (completionType == null) {
            completionType = getCompletionType(view, prefix, pos);
        }

        var mode = if (completionType.match(Toplevel)) "@toplevel" else "";

        var folder = null;
        for (f in view.window().folders()) {
            if (fileName.startsWith(f)) {
                folder = f;
                break;
            }
        }

        var cmd = [
            "--cwd", folder,
            "--no-output",
            "-D", "display-details",
            "--display", '$fileName@$bytePos$mode'
        ];

        var build = getBuild(folder);

        cmd.push("-" + build.target);
        cmd.push(build.output);

        for (cp in build.classPaths) {
            cmd.push("-cp");
            cmd.push(cp);
        }

        for (lib in build.libs) {
            cmd.push("-lib");
            cmd.push(lib);
        }

        if (build.main != null) {
            cmd.push("-main");
            cmd.push(build.main);
        }

        for (arg in build.args) {
            if (arg != "--no-output") {
                cmd.push(arg);
            }
        }

        // trace("Running completion " + cmd.join(" "));

        var tempFile = saveTempFile(view);
        var result = runHaxe(cmd);
        restoreTempFile(view, tempFile);
        return result;
    }

    public function getBuild(folder:String):Build {
        return BuildHelper.parse(File.getContent(Path.join(folder, "build.hxml")));
    }

    public function runHaxe(args:Array<String>):String {
        return HaxeServer.instance.runCommand(args);
    }

    public function saveTempFile(view:View):String {
        var currentFile = view.file_name();
        var tempFile = currentFile + ".tmp";
        var content = view.substr(new Region(0, view.size()));
        Shutil.copy2(currentFile, tempFile);
        File.saveContent(currentFile, content);
        return tempFile;
    }

    public function restoreTempFile(view:View, tempFile:String):Void {
        var currentFile = view.file_name();
        Shutil.copy2(tempFile, currentFile);
        FileSystem.deleteFile(tempFile);
    }
}
