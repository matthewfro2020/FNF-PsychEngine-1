package backend.animate;

import openfl.display.BitmapData;
import openfl.geom.Matrix;
import flixel.FlxSprite;
import flixel.FlxG;
import haxe.ds.StringMap;

/**
 * Fully standalone ZIP-based character renderer.
 * Uses AnimateZipReader to extract:
 *  - frame layers
 *  - PNGs
 *  - animation definitions
 *
 * Extremely safe: NEVER returns null pixels.
 */
class AnimateZIPChar extends FlxSprite
{
    public var frames:Array<BitmapData> = [];
    public var animMap:StringMap<Array<Int>> = new StringMap();
    public var fpsMap:StringMap<Int> = new StringMap();
    public var loopMap:StringMap<Bool> = new StringMap();

    public var curAnim:String = "idle";
    public var curFrame:Int = 0;
    public var timer:Float = 0;

    public var finished(get, never):Bool;
    public var length(get, never):Int;

    var reader:AnimateZipReader;
    var fallback:BitmapData;

    public function new(zipName:String)
    {
        super();

        fallback = new BitmapData(1, 1, true, 0x00000000);
        reader = new AnimateZipReader(zipName);

        if (reader == null || reader.data == null)
        {
            trace("ZIP ERROR: Could not load " + zipName);
            frames.push(fallback);
            pixels = fallback;
            return;
        }

        parseAnimationData();
        buildFrames();

        if (frames.length == 0)
            frames.push(fallback);

        // Default anim
        if (reader.data.defaultAnim != null)
            play(reader.data.defaultAnim);
        else
            play("idle");
    }

    //==============================================================
    //  Animation Data
    //==============================================================

    function parseAnimationData()
    {
        if (reader.data.animations != null)
        {
            var anims:Map<String, Dynamic> = cast reader.data.animations;
            for (name in anims.keys())
            {
                var arr:Array<Int> = cast anims.get(name);
                animMap.set(name, arr);
            }
        }

        if (reader.data.fps != null)
        {
            var fp:Map<String, Dynamic> = cast reader.data.fps;
            for (k in fp.keys()) fpsMap.set(k, fp.get(k));
        }

        if (reader.data.loops != null)
        {
            var lp:Map<String, Dynamic> = cast reader.data.loops;
            for (k in lp.keys()) loopMap.set(k, lp.get(k));
        }
    }

    //==============================================================
    //  Build frames
    //==============================================================

    function buildFrames()
    {
        if (reader.data.frames == null)
            return;

        var list:Array<Dynamic> = cast reader.data.frames;

        for (frame in list)
        {
            var layers:Array<Dynamic> = cast frame;

            if (layers == null || layers.length == 0)
            {
                frames.push(fallback.clone());
                continue;
            }

            var bmp = new BitmapData(2000, 2000, true, 0x00000000);

            for (layer in layers)
            {
                if (layer == null || layer.symbol == null) continue;

                var png = reader.getPNG(layer.symbol + ".png");
                if (png == null) continue;

                var img:BitmapData = null;
                try img = BitmapData.fromBytes(png) catch (e) continue;
                if (img == null) continue;

                var t = layer.transformation;
                var m = new Matrix();
                m.a = t.sx != null ? t.sx : 1;
                m.d = t.sy != null ? t.sy : 1;
                m.tx = t.x != null ? t.x : 0;
                m.ty = t.y != null ? t.y : 0;

                bmp.draw(img, m);
                img.dispose();
            }

            frames.push(bmp);
        }
    }

    //==============================================================
    //  Animation Control
    //==============================================================

    public function play(name:String, force:Bool = false)
    {
        if (!animMap.exists(name))
        {
            if (animMap.exists("idle")) name = "idle";
            else name = firstAnim();
        }

        curAnim = name;
        curFrame = 0;
        timer = 0;
        updateFrame();
    }

    function firstAnim():String
    {
        for (k in animMap.keys())
            return k;
        return "idle";
    }

    public function update(elapsed:Float)
    {
        var fps = fpsMap.exists(curAnim) ? fpsMap.get(curAnim) : 24;
        if (fps <= 0) fps = 24;

        timer += elapsed;
        var step = 1 / fps;

        if (timer >= step)
        {
            timer -= step;
            curFrame++;

            var arr = animMap.get(curAnim);
            if (curFrame >= arr.length)
            {
                var loop = loopMap.exists(curAnim) ? loopMap.get(curAnim) : false;
                curFrame = loop ? 0 : arr.length - 1;
            }

            updateFrame();
        }
    }

    function updateFrame()
    {
        var arr = animMap.get(curAnim);
        if (arr == null || arr.length == 0)
        {
            pixels = fallback;
            return;
        }

        var idx = arr[curFrame];
        if (idx < 0 || idx >= frames.length)
            pixels = fallback;
        else
            pixels = frames[idx];
    }

    //==============================================================
    //  Exposed properties
    //==============================================================

    inline function get_finished():Bool
        return curFrame == animMap.get(curAnim).length - 1 && !loopMap.get(curAnim);

    inline function get_length():Int
        return animMap.get(curAnim).length;
}
