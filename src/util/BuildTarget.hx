package util;

@:enum abstract BuildTarget(String) {
    var Js = "js";
    var Neko = "neko";
    var Cpp = "cpp";
    var Cs = "cs";
    var Java = "java";
    var Python = "python";
    var Swf = "swf";
    var As3 = "as3";
    var Xml = "xml";
    var Php = "php";
}