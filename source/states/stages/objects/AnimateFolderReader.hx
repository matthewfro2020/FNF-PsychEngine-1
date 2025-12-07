package states.stages.objects;

import flxanimate.FlxAnimate;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/**
 * Reader supporting:
 *  - data.json
 *  - library.json
 *  - symbols/*.json
 *
 * Fully compatible with Psych & your stripped-down FlxAnimate.
 * Does NOT attempt to call unsupported fields like library.symbols.
 */
class AnimateFolderReader
{
    public var valid:Bool = false;

    // External metadata
    public var dataJson:Dynamic;
    public var libJson:Dynamic;
    public var symbols:Map<String,Dynamic> = [];

    public function new(base:String)
    {
        valid = false;

        if (!FileSystem.exists(base))
            return;

        var dataPath = base + "/data.json";
        var libPath  = base + "/library.json";
        var symPath  = base + "/symbols";

        // Ensure folder contains everything
        if (!FileSystem.exists(dataPath) || !FileSystem.exists(libPath) || !FileSystem.exists(symPath))
            return;

        // ----------------------------
        // Read metadata
        // ----------------------------
        try {
            dataJson = Json.parse(File.getContent(dataPath));
            libJson  = Json.parse(File.getContent(libPath));
        }
        catch (e) {
            trace("[AnimateFolderReader] JSON parse error: " + e);
            return;
        }

        // ----------------------------
        // Load symbol JSON files
        // ----------------------------
        for (file in FileSystem.readDirectory(symPath))
        {
            if (file.endsWith(".json"))
            {
                var name = file.substr(0, file.length - 5);
                try {
                    var content = File.getContent(symPath + "/" + file);
                    var parsed  = Json.parse(content);
                    symbols[name] = parsed;
                }
                catch (e) {
                    trace("[AnimateFolderReader] Error loading symbol " + file + ": " + e);
                }
            }
        }

        valid = true;
        trace("[AnimateFolderReader] Loaded Animate folder OK: " + base);
    }

    /**
     * Character.hx will call this:
     *   reader.toAtlas(atlas)
     *
     * We ONLY load the anim + frame data using allowed functions.
     */
    public function toAtlas(atlas:FlxAnimate):Void
    {
        if (!valid || atlas == null) return;

        // Your engine supports:
        // atlas.loadAtlasWithAnimation(atlasJSON, animationJSON)
        // NOT "library", NOT "symbols"
        try {
            atlas.loadAtlasWithAnimation(libJson, dataJson);
        }
        catch (e) {
            trace("[AnimateFolderReader] Error applying data to atlas: " + e);
        }
    }
}
