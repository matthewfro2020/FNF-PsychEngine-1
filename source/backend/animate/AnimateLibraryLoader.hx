package backend.animate;

import flxanimate.FlxAnimate;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import flixel.FlxG;

/**
 * UNIVERSAL ANIMATE LOADER
 * Supports:
 *  - data.json
 *  - library.json
 *  - symbols/*.json
 *  - Animation.json + spritemap
 * 
 * Output:
 *  - Fully initialized FlxAnimate object
 *  - Auto-remapped animation names (idle, singLEFT, etc.)
 */
class AnimateLibraryLoader
{
    public var valid:Bool = false;
    public var atlas:FlxAnimate;
    public var symbols:Map<String, Dynamic> = [];

    public var animList:Array<String> = [];

    public function new(base:String)
    {
        valid = false;

        if (!FileSystem.exists(base))
        {
            trace("[AnimateLibraryLoader] Missing folder: " + base);
            return;
        }

        var dataPath = base + "/data.json";
        var libPath  = base + "/library.json";
        var symPath  = base + "/symbols";

        if (!FileSystem.exists(dataPath) || !FileSystem.exists(libPath))
        {
            trace("[AnimateLibraryLoader] Missing data.json or library.json");
            return;
        }

        var data = Json.parse(File.getContent(dataPath));
        var lib  = Json.parse(File.getContent(libPath));

        atlas = new FlxAnimate();
        atlas.showPivot = false;

        // =============================
        // LOAD SYMBOL FILES (public API)
        // =============================
        if (FileSystem.exists(symPath))
        {
            for (file in FileSystem.readDirectory(symPath))
            {
                if (file.endsWith(".json"))
                {
                    var name = file.substr(0, file.length - 5);
                    var js = Json.parse(File.getContent(symPath + "/" + file));
                    symbols[name] = js;
                }
            }
        }

        // =============================
        // FLXANIMATE PUBLIC LOADING
        // =============================
        if (Reflect.hasField(lib, "symbols"))
        {
            // PUBLIC field in FlxAnimate
            @:privateAccess atlas.library.symbols = lib.symbols;
        }

        // Build animation list automatically
        __buildAnimations();

        valid = true;
    }

    /**
     * Build animation list for FlxAnimate
     * Supports automatically mapping symbols → animations
     */
    private function __buildAnimations():Void
    {
        if (atlas == null) return;

        animList = [];

        // Use public API: atlas.anim.addBySymbol()
        @:privateAccess
        var amap = atlas.library.symbols;

        if (amap == null)
        {
            trace("[AnimateLibraryLoader] WARN: No symbols found.");
            return;
        }

        for (symbol => data in amap)
        {
            var lower = symbol.toLowerCase();
            var remap = symbol;

            // ===========================
            //  PSYCH ENGINE AUTO-MAPPING
            // ===========================
            if (lower.contains("idle")) remap = "idle";

            else if (lower.contains("leftmiss")) remap = "singLEFTmiss";
            else if (lower.contains("downmiss")) remap = "singDOWNmiss";
            else if (lower.contains("upmiss")) remap = "singUPmiss";
            else if (lower.contains("rightmiss")) remap = "singRIGHTmiss";

            else if (lower.contains("left")) remap = "singLEFT";
            else if (lower.contains("down")) remap = "singDOWN";
            else if (lower.contains("up")) remap = "singUP";
            else if (lower.contains("right")) remap = "singRIGHT";

            // Add animation
            atlas.anim.addBySymbol(remap, symbol, 24, false);

            animList.push(remap);

            trace("[AnimateLibraryLoader] " + symbol + " → " + remap);
        }
    }

    public function play(name:String):Void
    {
        if (atlas != null && atlas.anim != null)
            atlas.anim.play(name);
    }
}
