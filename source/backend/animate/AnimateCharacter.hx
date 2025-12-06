package backend.animate;

import openfl.display.BitmapData;
import openfl.geom.Matrix;
import flixel.FlxSprite;
import haxe.Json;

class AnimateCharacter extends FlxSprite
{
    /** 
        We rename frames → bitmapFrames
        to avoid conflict with FlxSprite.frames 
    **/
    public var bitmapFrames:Array<BitmapData> = [];

    public var animations:Map<String, Array<Int>> = new Map();
    public var animFPS:Map<String, Int> = new Map();
    public var animLoop:Map<String, Bool> = new Map();

    public var curAnim:String = "idle";
    public var curFrame:Int = 0;
    public var timer:Float = 0;

    var reader:AnimateZipReader;
    var fallbackFrame:BitmapData;

    public function new(zipPath:String)
    {
        super();

        reader = new AnimateZipReader(zipPath);

        fallbackFrame = new BitmapData(1, 1, true, 0x00000000);

        parseAnimationData();
        buildFrames();

        // Guarantee no null pixels EVER
        if (bitmapFrames.length == 0)
            bitmapFrames.push(fallbackFrame);

        pixels = bitmapFrames[0];

        // default animation
        play(reader.data.defaultAnim != null ? reader.data.defaultAnim : "idle");
    }

    // --------------------------------------------------------
    // LOAD ANIMATION DEFINITIONS
    // --------------------------------------------------------
    function parseAnimationData()
    {
        // animations {...}
        if (reader.data.animations != null)
        {
            var map:Map<String, Dynamic> = cast reader.data.animations;
            for (key in map.keys())
            {
                var arr:Array<Int> = cast map.get(key);
                animations.set(key, arr);
            }
        }

        // fps {...}
        if (reader.data.fps != null)
        {
            var mapFPS:Map<String, Dynamic> = cast reader.data.fps;
            for (key in mapFPS.keys())
                animFPS.set(key, cast mapFPS.get(key));
        }

        // loops {...}
        if (reader.data.loops != null)
        {
            var loopMap:Map<String, Dynamic> = cast reader.data.loops;
            for (key in loopMap.keys())
                animLoop.set(key, cast loopMap.get(key));
        }
    }

    // --------------------------------------------------------
    // BUILD BITMAP FRAMES (SAFE)
    // --------------------------------------------------------
    function buildFrames()
    {
        var framesList:Array<Dynamic> = cast reader.data.frames;

        for (frameData in framesList)
        {
            var layers:Array<Dynamic> = cast frameData;

            // Empty frame? → push blank frame to avoid crash
            if (layers == null || layers.length == 0)
            {
                bitmapFrames.push(fallbackFrame.clone());
                continue;
            }

            var canvas = new BitmapData(2000, 2000, true, 0x00000000);

            for (layer in layers)
            {
                var pngName = layer.symbol + ".png";
                var bytes = reader.getPNG(pngName);
                if (bytes == null)
                    continue;

                var bmp = BitmapData.fromBytes(bytes);

                var t = layer.transformation;
                var m = new Matrix();
                m.a = t.sx;
                m.d = t.sy;
                m.tx = t.x;
                m.ty = t.y;

                canvas.draw(bmp, m);
            }

            bitmapFrames.push(canvas);
        }
    }

    // --------------------------------------------------------
    // PLAY ANIMATION
    // --------------------------------------------------------
    public function play(name:String)
    {
        if (!animations.exists(name))
        {
            trace("Missing animation: " + name + ", falling back to idle");

            if (animations.exists("idle"))
                name = "idle";
            else
                name = animFallback();
        }

        curAnim = name;
        curFrame = 0;
        timer = 0;

        updateBitmap();
    }

    // fallback if idle doesn't exist either
    function animFallback():String
    {
        for (key in animations.keys())
            return key; // first available anim

        return "idle";
    }

    // --------------------------------------------------------
    // UPDATE ANIMATION
    // --------------------------------------------------------
    override function update(elapsed:Float)
    {
        var fps = animFPS.exists(curAnim) ? animFPS.get(curAnim) : 24;
        timer += elapsed;

        if (timer >= 1 / fps)
        {
            timer = 0;

            var group = animations.get(curAnim);
            if (group == null || group.length == 0)
            {
                // No valid frames? → show fallback frame
                pixels = fallbackFrame;
                return;
            }

            curFrame++;

            if (curFrame >= group.length)
            {
                var looping = animLoop.exists(curAnim) ? animLoop.get(curAnim) : false;
                if (looping)
                    curFrame = 0;
                else
                    curFrame = group.length - 1;
            }

            updateBitmap();
        }

        super.update(elapsed);
    }

    // --------------------------------------------------------
    // UPDATE PIXELS WITH SAFETY CHECKS
    // --------------------------------------------------------
    function updateBitmap()
    {
        if (!animations.exists(curAnim))
        {
            pixels = fallbackFrame;
            dirty = true;
            return;
        }

        var group = animations.get(curAnim);

        if (group == null || group.length == 0)
        {
            pixels = fallbackFrame;
            dirty = true;
            return;
        }

        var index = group[curFrame];

        if (index < 0 || index >= bitmapFrames.length)
        {
            pixels = bitmapFrames[0]; // safe fallback
            dirty = true;
            return;
        }

        var bmp = bitmapFrames[index];
        if (bmp == null)
            bmp = fallbackFrame;

        pixels = bmp;
        dirty = true;
    }
}
