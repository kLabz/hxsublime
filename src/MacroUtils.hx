import haxe.macro.Compiler;
import haxe.io.Path;
import sys.io.File;

class MacroUtils {

    static function copy(inFile:String):Void {
        var src = File.getContent(inFile);
        File.saveContent(Compiler.getDefine("DEPLOY_DIR") + "/" + Path.withoutDirectory(inFile), src);
    }

}
