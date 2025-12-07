package backend.animate;

import haxe.Json;
import openfl.display.BitmapData;
import openfl.utils.Assets;
import sys.FileSystem;
import sys.io.File;
import openfl.geom.Rectangle;
import openfl.geom.Point;

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
            trace("[AnimateFolderReader] Missing required files.");
            return;
        }

        try {
            dataJson = Json.parse(File.getContent(dataPath));
            libJson  = Json.parse(File.getContent(libPath));
        }
        catch (e)
        {
            trace("[AnimateFolderReader] JSON parse error: " + e);
            return;
        }

        // Load all PNG symbols
        for (file in FileSystem.readDirectory(symPath))
        {
            if (!file.toLowerCase().endsWith(".png")) continue;

            var full = symPath + "/" + file;
            try {
                var bmp = BitmapData.fromFile(full);
                symbols.set("symbols/" + file, bmp);
            }
            catch (e) {
                trace("[AnimateFolderReader] Failed loading symbol " + full);
            }
        }

        valid = true;
        trace("[AnimateFolderReader] Loaded Animate folder successfully: " + path);
    }

    /**
     * Converts folder contents into AnimateAtlas-compatible structure
     * so the engine can treat it *exactly like a spritemap1 atlas*
     */
    public function toAtlas():Dynamic
    {
        if (!valid) return null;

        var frames:Array<Dynamic> = [];

        var idx = 0;
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
                    x: 0, y: 0, w: bmp.width, h: bmp.height
                },
                sourceSize: {
                    w: bmp.width, h: bmp.height
                }
            });
            idx++;
        }

        return {
            frames: frames,
            meta: {
                app: "AnimateFolder",
                image: "folder", // placeholder
                format: "RGBA8888",
                size: { w: 0, h: 0 },
                scale: "1"
            }
        }
    }
};