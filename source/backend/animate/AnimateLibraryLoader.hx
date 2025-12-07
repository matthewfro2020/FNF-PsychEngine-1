package backend.animate;

import flxanimate.FlxAnimate;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/**
 * FULL FOLDER-ANIMATE LOADER
 * Loads:
 *  • data.json
 *  • library.json
 *  • symbols/*.json
 *  • spriteMap (if present)
 *
 * Produces:
 *  • Fully-initialized FlxAnimate
 *  • Auto-generated Psych animation list (idle, singLEFT, etc)
 */
class AnimateLibraryLoader
{
    public var valid:Bool = false;

    public var atlas:FlxAnimate;
    public var symbols:Map<String, Dynamic> = [];
    public var animNames:Array<String> = [];

    public function new(base:String)
    {
        valid = false;

        if (!FileSystem.exists(base))
        {
            trace("[AnimateLibraryLoader] Missing " + base);
            return;
        }

        var dataPath = base + "/data.json";
        var libPath  = base + "/library.json";
        var symPath  = base + "/symbols";

        if (!FileSystem.exists(dataPath) || !FileSystem.exists(libPath))
        {
            trace("[AnimateLibraryLoader] Missing required JSON files");
            return;
        }

        var data = Json.parse(File.getContent(dataPath));
        var lib  = Json.parse(File.getContent(libPath));

        atlas = new FlxAnimate();
        atlas.showPivot = false;

        // -------------------------------------------------
        // Load symbol JSONs from /symbols folder
        // -------------------------------------------------
        if (FileSystem.exists(symPath))
        {
            for (file in FileSystem.readDirectory(symPath))
            {
                if (file.endsWith(".json"))
                {
                    var symName = file.substr(0, file.length - 5);
                    var content = Json.parse(File.getContent(symPath + "/" + file));
                    symbols[symName] = content;
                }
            }
        }

        // -------------------------------------------------
        // Attach symbols to flxanimate (public API)
        // -------------------------------------------------
        @:privateAccess
        if (Reflect.hasField(lib, "symbols"))
            atlas.library.symbols = lib.symbols;
        else
            atlas.library.symbols = symbols;

        // -------------------------------------------------
        // BUILD ANIMATION MAP
        // -------------------------------------------------
        __buildAnimationList();

        valid = true;
    }

    // ==========================================================
    // Build Psych-compatible animation list automatically
    // ==========================================================
    private function __buildAnimationList():Void
    {
        if (atlas == null) return;

        animNames = [];

        @:privateAccess var amap = atlas.library.symbols;
        if (amap == null)
        {
            trace("[AnimateLibraryLoader] No symbols found in atlas");
            return;
        }

        for (symbol => data in amap)
        {
            var lower = symbol.toLowerCase();
            var remap = symbol;

            // Psych-style auto-detection
            if (lower.contains("idle")) remap = "idle";

            else if (lower.contains("leftmiss")) remap = "singLEFTmiss";
            else if (lower.contains("downmiss")) remap = "singDOWNmiss";
            else if (lower.contains("upmiss")) remap = "singUPmiss";
            else if (lower.contains("rightmiss")) remap = "singRIGHTmiss";

            else if (lower.contains("left")) remap = "singLEFT";
            else if (lower.contains("down")) remap = "singDOWN";
            else if (lower.contains("up")) remap = "singUP";
            else if (lower.contains("right")) remap = "singRIGHT";

            atlas.anim.addBySymbol(remap, symbol, 24, false);

            animNames.push(remap);

            trace("[AnimateLibrary] " + symbol + " → " + remap);
        }
    }

    // Utility
    public function play(name:String):Void
    {
        if (atlas != null && atlas.anim != null)
            atlas.anim.play(name);
    }
}
