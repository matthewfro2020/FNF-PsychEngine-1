package backend.animate;

import flxanimate.FlxAnimate;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import haxe.zip.Reader;
import haxe.zip.Entry;
import sys.io.FileInput;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Bytes;
import openfl.utils.Assets;
import openfl.display.BitmapData;

/**
 * AnimateZipReader
 * ----------------
 * Loads a complete Adobe Animate ZIP package:
 *
 *   • Animation.json
 *   • spritemap1.json + spritemap1.png
 *   • library.json (optional)
 *   • data.json (optional)
 *   • symbols/*.json
 *
 * Produces:
 *   • A fully-initialized FlxAnimate instance
 *   • Auto-mapped animation names (idle, singLEFT, etc)
 */
class AnimateZipReader
{
    public var valid:Bool = false;
    public var atlas:FlxAnimate;

    public var animationJson:Dynamic = null;
    public var libraryJson:Dynamic = null;
    public var dataJson:Dynamic = null;
    public var symbols:Map<String, Dynamic> = [];

    public function new(zipPath:String)
    {
        valid = false;

        if (!FileSystem.exists(zipPath))
        {
            trace("[AnimateZip] Missing file: " + zipPath);
            return;
        }

        var entries:List<Entry> = null;

        try
        {
            var fin:FileInput = File.read(zipPath);
            var reader = new Reader(fin);
            entries = reader.read();
            fin.close();
        }
        catch (e:Dynamic)
        {
            trace("[AnimateZip] ERROR: " + e);
            return;
        }

        atlas = new FlxAnimate();
        atlas.showPivot = false;

        // -----------------------------------------------------------
        // Extract all JSON & PNG data from ZIP
        // -----------------------------------------------------------
        var pngBytes:Bytes = null;
        var spritemapJson:Dynamic = null;

        for (entry in entries)
        {
            var name = entry.fileName;

            // --- Animation.json ---
            if (name.endsWith("Animation.json"))
                animationJson = Json.parse(getEntryText(entry));

            // --- library.json ---
            else if (name.endsWith("library.json"))
                libraryJson = Json.parse(getEntryText(entry));

            // --- data.json ---
            else if (name.endsWith("data.json"))
                dataJson = Json.parse(getEntryText(entry));

            // --- spritemap JSON ---
            else if (name.endsWith("spritemap1.json"))
                spritemapJson = Json.parse(getEntryText(entry));

            // --- spritemap PNG ---
            else if (name.endsWith("spritemap1.png"))
                pngBytes = getEntryBytes(entry);

            // --- symbols/*.json ---
            else if (name.contains("symbols/") && name.endsWith(".json"))
            {
                var symName = name.split("/").pop().substr(0, name.length - 5);
                symbols[symName] = Json.parse(getEntryText(entry));
            }
        }

        if (animationJson == null || spritemapJson == null || pngBytes == null)
        {
            trace("[AnimateZip] Missing required Animation JSON or sprite atlas");
            return;
        }

        // -----------------------------------------------------------
        // Create BitmapData from PNG bytes
        // -----------------------------------------------------------
        var bmp:BitmapData = BitmapData.fromBytes(pngBytes);

        // -----------------------------------------------------------
        // Create FlxAtlasFrames
        // -----------------------------------------------------------
        atlas.frames = FlxAtlasFrames.fromTexturePackerJson(bmp, spritemapJson);

        // -----------------------------------------------------------
        // Build animation list
        // -----------------------------------------------------------
        __addAnimations();

        valid = true;
    }

    // ============================================================
    // Extract text from ZIP entry
    // ============================================================
    private function getEntryText(e:Entry):String
    {
        return e.data.toString();
    }

    private function getEntryBytes(e:Entry):Bytes
    {
        return e.data;
    }

    // ============================================================
    // Build animations from Animation.json
    // ============================================================
    private function __addAnimations():Void
    {
        if (animationJson == null || !Reflect.hasField(animationJson, "ANIMATION"))
            return;

        var anims:Dynamic = animationJson.ANIMATION;

        for (key in Reflect.fields(anims))
        {
            var frames:Array<Int> = anims[key];
            var nameLower = key.toLowerCase();
            var remap = __remapName(nameLower);

            atlas.anim.add(remap, frames, 24, false);

            trace("[AnimateZip] " + key + " → " + remap);
        }
    }

    // ============================================================
    // Auto-remapping zip-symbols → Psych Engine animation names
    // ============================================================
    private function __remapName(raw:String):String
    {
        if (raw.contains("idle")) return "idle";
        if (raw.contains("leftmiss")) return "singLEFTmiss";
        if (raw.contains("downmiss")) return "singDOWNmiss";
        if (raw.contains("upmiss")) return "singUPmiss";
        if (raw.contains("rightmiss")) return "singRIGHTmiss";

        if (raw.contains("left")) return "singLEFT";
        if (raw.contains("down")) return "singDOWN";
        if (raw.contains("up")) return "singUP";
        if (raw.contains("right")) return "singRIGHT";

        return raw;
    }

    // Public simple interface
    public inline function play(name:String)
    {
        atlas.anim.play(name);
    }

    public inline function hasAnimation(name:String):Bool
    {
        return atlas.anim.exists(name);
    }

    public inline function isFinished():Bool
    {
        return atlas.anim.finished;
    }

    public inline function getCurrentAnimation():String
    {
        return atlas.anim.curAnim != null ? atlas.anim.curAnim.name : "";
    }

    public inline function finishAnimation():Void
    {
        atlas.anim.finish();
    }
}
