package animate;

import haxe.io.Bytes;
import haxe.zip.Reader;
import haxe.Json;
import sys.io.File;

class AnimateZipReader
{
    public var library:Dynamic;
    public var data:Dynamic;
    public var symbols:Map<String, Bytes> = new Map();

    public function new(zipPath:String)
    {
        var bytes = File.getBytes(zipPath);

        var entries = Reader.readZip(bytes);
        for (entry in entries)
        {
            var name = entry.fileName;

            if (name == "library.json")
            {
                library = Json.parse(entry.data.toString());
            }
            else if (name == "data.json")
            {
                data = Json.parse(entry.data.toString());
            }
            else if (name.startsWith("symbols/") && name.endsWith(".png"))
            {
                var key = name.substr("symbols/".length);
                symbols.set(key, entry.data);
            }
        }
    }

    public function getSymbolPNG(name:String):Bytes
    {
        return symbols.get(name);
    }
}
