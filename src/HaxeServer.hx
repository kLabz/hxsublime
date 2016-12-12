import python.lib.subprocess.Popen;
import sys.net.Socket;
import sys.net.Host;

using StringTools;

class HaxeServer {
    public static inline var PORT:Int = 6000;

    public static var instance(get, null):HaxeServer;
    public static function get_instance():HaxeServer {
        if (instance == null) {
            instance = new HaxeServer();
            instance.start(PORT);
        }

        return instance;
    }

    var proc:Popen;
    var port:Int;

    private function new() {}

    public function start(port:Int):Void {
        if (proc != null)
            stop();
        this.port = port;
        proc = new Popen(["haxe", "-v", "--wait", Std.string(port)]);
    }

    public function stop():Void {
        if (proc != null) {
            proc.terminate();
            proc = null;
        }
    }

    public function runCommand(args:Array<String>):String {
        var sock = new Socket();
        sock.connect(new Host("127.0.0.1"), port);
        for (arg in args) {
            sock.output.writeString(arg);
            sock.output.writeByte('\n'.code);
        }
        sock.output.writeInt8(0);
        sock.waitForRead();
        var buf = new StringBuf();
        for (line in sock.read().split("\n")) {
            switch (line.fastCodeAt(0)) {
                case 0x01: // TODO: print
                case 0x02: // TODO: show error
                default:
                    buf.add(line);
                    buf.addChar('\n'.code);
            }
        }
        sock.close();
        return buf.toString();
    }
}

