package backend.animate;

import sys.io.File;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.zip.Reader;
import haxe.zip.Entry;
import haxe.ds.List;
import haxe.Json;

class AnimateZipReader
{
    public var library:Dynamic;
    public var data:Dynamic;
    public var symbols:Map<String, Bytes> = new Map();

    public function new(path:String)
    {
        // Read entire ZIP file into bytes
        var bytes:Bytes = File.getBytes(path);

        // Convert bytes → Input (required by Reader)
        var input:BytesInput = new BytesInput(bytes);

        // Psych Engine returns: List<Entry>
        var entries:List<Entry> = Reader.readZip(input);

        // Iterate properly
        for (entry in entries)
        {
            var name:String = entry.fileName;

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
