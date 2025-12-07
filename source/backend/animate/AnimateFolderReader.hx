package backend.animate;

import haxe.Json;
import openfl.display.BitmapData;
import openfl.utils.Assets;
import sys.FileSystem;
import sys.io.File;

class AnimateFolderReader
{
    public var symbols:Map<String, BitmapData>;
    public var dataJson:Dynamic;
    public var libJson:Dynamic;
    public var valid:Bool = false;

    public function new(path:String)
    {
        symbols = new Map();

        if (!FileSystem.exists(path))
        {
            trace("[AnimateFolderReader] folder does not exist: " + path);
            return;
        }

        var dataPath = path + "/data.json";
        var libPath  = path + "/library.json";
        var symPath  = path + "/symbols";

        if (!FileSystem.exists(dataPath) || !FileSystem.exists(libPath) || !FileSystem.exists(symPath))
        {
            trace("[AnimateFolderReader] Missing required files: " + path);
            return;
        }

        try 
        {
            dataJson = Json.parse(File.getContent(dataPath));
            libJson  = Json.parse(File.getContent(libPath));
        }
        catch (e)
        {
            trace("[AnimateFolderReader] JSON parse error: " + e);
            return;
        }

        // Load all PNG symbol images
        for (file in FileSystem.readDirectory(symPath))
        {
            if (file.toLowerCase().endsWith(".png"))
            {
                var full = symPath + "/" + file;

                try 
                {
                    var bmp = BitmapData.fromFile(full);
                    // Normalize symbol name so AnimateAtlas can read it
                    var key = "symbols/" + file;
                    symbols.set(key, bmp);
                }
                catch (e)
                {
                    trace("[AnimateFolderReader] Failed loading symbol: " + full);
                }
            }
        }

        valid = true;
        trace("[AnimateFolderReader] Loaded Animate folder successfully: " + path);
    }

    /**
     * Converts folder contents into AnimateAtlas-compatible JSON structure.
     * Psych Engine treats this the same as a TexturePacker spritemap1 atlas.
     */
    public function toAtlas():Dynamic
    {
        if (!valid)
            return null;

        var frames = [];

        for (name => bmp in symbols)
        {
            frames.push({
                filename: name,
                frame: {
                    x: 0,
                    y: 0,
                    w: bmp.width,
                    h: bmp.height
                },
                rotated: false,
                trimmed: false,
                spriteSourceSize: {
                    x: 0,
                    y: 0,
                    w: bmp.width,
                    h: bmp.height
                },
                sourceSize: {
                    w: bmp.width,
                    h: bmp.height
                }
            });
        }

        return {
            frames: frames,
            meta: {
                app: "AnimateFolderReader",
                image: "folder",
                format: "RGBA8888",
                size: { w: 0, h: 0 },
                scale: "1"
            }
        };
    }
}
