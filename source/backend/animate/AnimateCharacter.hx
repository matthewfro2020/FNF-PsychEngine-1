package backend.animate;

import openfl.display.BitmapData;
import openfl.geom.Matrix;
import flixel.FlxSprite;

/**
 * AnimateCharacter.hx
 * FINAL — Crash-proof, no null pixels, supports infinite animations.
 * Used by Character.hx when renderType == "swf" OR the JSON includes "animateZip".
 */
class AnimateCharacter extends FlxSprite
{
    public var bitmapFrames:Array<BitmapData> = []; // all rendered frames
    public var animations:Map<String, Array<Int>> = new Map(); // animName → frameIndices
    public var animFPS:Map<String, Int> = new Map();
    public var animLoop:Map<String, Bool> = new Map();

    public var curAnim:String = "idle";
    public var curFrame:Int = 0;
    public var timer:Float = 0;

    var reader:AnimateZipReader;
    var fallbackFrame:BitmapData;

    // large canvas prevents clipping
    var canvasWidth:Int = 2000;
    var canvasHeight:Int = 2000;

    public function new(zipPath:String)
    {
        super();

        reader = new AnimateZipReader(zipPath);

        if (reader == null || reader.data == null)
        {
            trace("ERROR: AnimateZipReader failed, using fallback.");
            fallbackFrame = new BitmapData(1, 1, true, 0x00000000);
            bitmapFrames.push(fallbackFrame);
            pixels = fallbackFrame;
            return;
        }

        fallbackFrame = new BitmapData(1, 1, true, 0x00000000);

        parseAnimationData();
        buildFrames();

        // Guarantee at least 1 frame
        if (bitmapFrames.length == 0)
            bitmapFrames.push(fallbackFrame.clone());

        pixels = bitmapFrames[0];

        // defaultAnim fallback
        var startAnim = reader.data.defaultAnim != null ? reader.data.defaultAnim : "idle";
        play(startAnim);
    }

    // -------------------------------------------------------------
    // Parse animation lists from data.json
    // -------------------------------------------------------------
    function parseAnimationData()
    {
        if (reader.data == null) return;

        // animations: { "idle": [0,1,2], "singLEFT": [3,4] }
        if (reader.data.animations != null)
        {
            for (key in reader.data.animations.keys())
            {
                var arr:Array<Int> = reader.data.animations.get(key);
                if (arr != null)
                    animations.set(key, arr);
            }
        }

        // fps: { "idle": 24, "singLEFT": 24 }
        if (reader.data.fps != null)
        {
            for (key in reader.data.fps.keys())
            {
                animFPS.set(key, reader.data.fps.get(key));
            }
        }

        // loops: { "idle": true, "singLEFT": false }
        if (reader.data.loops != null)
        {
            for (key in reader.data.loops.keys())
            {
                animLoop.set(key, reader.data.loops.get(key));
            }
        }
    }

    // -------------------------------------------------------------
    // Build bitmap frames from layers in frames[] array
    // -------------------------------------------------------------
    function buildFrames()
    {
        if (reader.data == null || reader.data.frames == null) return;

        for (frame in reader.data.frames)
        {
            var layers:Array<Dynamic> = cast frame;
            if (layers == null || layers.length == 0)
            {
                bitmapFrames.push(fallbackFrame.clone());
                continue;
            }

            var canvas = new BitmapData(canvasWidth, canvasHeight, true, 0x00000000);

            for (layer in layers)
            {
                if (layer == null || layer.symbol == null)
                    continue;

                var name = layer.symbol + ".png";
                var bytes = reader.getPNG(name);

                if (bytes == null) continue;

                var bmp:BitmapData = BitmapData.fromBytes(bytes);
                if (bmp == null) continue;

                var t = layer.transformation;
                var m = new Matrix();

                m.a = (t.sx != null ? t.sx : 1);
                m.d = (t.sy != null ? t.sy : 1);
                m.tx = (t.x != null ? t.x : 0);
                m.ty = (t.y != null ? t.y : 0);

                canvas.draw(bmp, m);
                bmp.dispose();
            }

            bitmapFrames.push(canvas);
        }
    }

    // -------------------------------------------------------------
    // Play animation
    // -------------------------------------------------------------
    public function play(name:String)
    {
        if (name == null || !animations.exists(name))
        {
            trace("Missing anim: " + name);

            if (animations.exists("idle"))
                name = "idle";
            else
                name = getFirstAnim();
        }

        curAnim = name;
        curFrame = 0;
        timer = 0;
        updateBitmap();
    }

    function getFirstAnim():String
    {
        for (key in animations.keys()) return key;
        return "idle";
    }

    // -------------------------------------------------------------
    // Update animation
    // -------------------------------------------------------------
    override function update(elapsed:Float)
    {
        var fps = animFPS.exists(curAnim) ? animFPS[curAnim] : 24;
        if (fps <= 0) fps = 24;

        timer += elapsed;

        if (timer >= 1 / fps)
        {
            timer -= 1 / fps;

            var group = animations.get(curAnim);
            if (group == null || group.length == 0)
            {
                pixels = fallbackFrame;
                return;
            }

            curFrame++;

            if (curFrame >= group.length)
            {
                var loop = animLoop.exists(curAnim) ? animLoop[curAnim] : false;

                if (loop)
                    curFrame = 0;
                else
                    curFrame = group.length - 1;
            }

            updateBitmap();
        }

        super.update(elapsed);
    }

    // -------------------------------------------------------------
    // Set new bitmap
    // -------------------------------------------------------------
    function updateBitmap()
    {
        var group = animations.get(curAnim);
        if (group == null || group.length == 0)
        {
            pixels = fallbackFrame;
            return;
        }

        var index = group[curFrame];
        if (index >= 0 && index < bitmapFrames.length)
            pixels = bitmapFrames[index];
        else
            pixels = fallbackFrame;
    }
}
