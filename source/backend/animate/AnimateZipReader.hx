package backend.animate;

import haxe.zip.Reader;
import haxe.Json;
import haxe.io.Bytes;
import sys.io.File;
import sys.FileSystem;

class AnimateZipReader
{
    public var library:Dynamic;
    public var data:Dynamic;
    public var symbols:Map<String, Bytes> = new Map();

    public function new(path:String)
    {
        if (!FileSystem.exists(path))
            throw 'Animate ZIP not found: $path';

        var bytes = File.getBytes(path);
        var entries = Reader.readZip(bytes);

        for (entry in entries)
        {
            var name = entry.fileName;

            switch (name)
            {
                case "library.json":
                    library = Json.parse(entry.data.toString());
                case "data.json":
                    data = Json.parse(entry.data.toString());
                default:
                    if (name.startsWith("symbols/") && name.endsWith(".png"))
                    {
                        var key = name.substr("symbols/".length);
                        symbols.set(key, entry.data);
                    }
            }
        }
    }

    public function getPNG(symbol:String):Bytes
    {
        return symbols.get(symbol);
    }
}
