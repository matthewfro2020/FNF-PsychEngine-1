package backend.animate;

import sys.io.File;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.zip.Reader;
import haxe.zip.Entry;
import haxe.Json;

class AnimateZipReader
{
    public var library:Dynamic;
    public var data:Dynamic;
    public var symbols:Map<String, Bytes> = new Map();

    public function new(path:String)
    {
        // Read all bytes of zip file
        var bytes:Bytes = File.getBytes(path);

        // Convert to Input (required by Reader.readZip)
        var input:BytesInput = new BytesInput(bytes);

        // Read ZIP entries as Array<Entry>
        var entries:Array<Entry> = Reader.readZip(input);

        // Iterate normally (NO dynamic errors)
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

    public function getPNG(symbolName:String):Bytes
    {
        return symbols.get(symbolName);
    }
}
