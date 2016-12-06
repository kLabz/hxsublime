import python.lib.Builtins;

class HaxeLogInit {
    static function __init__() {
        haxe.Log.trace = function(o, ?i) {
            var args = [o];
            if (i != null && i.customParams != null)
                args = args.concat(i.customParams);
            Builtins.print(args.join(" "));
        }
    }
}
