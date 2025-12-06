package backend.animate;

import openfl.display.BitmapData;
import openfl.geom.Matrix;
import flixel.FlxSprite;

class AnimateCharacter extends FlxSprite
{
    public var bitmapFrames:Array<BitmapData> = [];
    public var animations:Map<String, Array<Int>> = new Map();
    public var animFPS:Map<String, Int> = new Map();
    public var animLoop:Map<String, Bool> = new Map();

    public var curAnim:String = "idle";
    public var curFrame:Int = 0;
    public var timer:Float = 0;

    var reader:AnimateZipReader;
    var fallbackFrame:BitmapData;
    var canvasWidth:Int = 2000;
    var canvasHeight:Int = 2000;

    public function new(zipPath:String)
    {
        super();
        reader = new AnimateZipReader(zipPath);

        if (reader == null || reader.data == null)
        {
            fallbackFrame = new BitmapData(1, 1, true, 0x00000000);
            bitmapFrames.push(fallbackFrame);
            pixels = fallbackFrame;
            return;
        }

        fallbackFrame = new BitmapData(1, 1, true, 0x00000000);

        parseAnimationData();
        buildFrames();

        if (bitmapFrames.length == 0)
            bitmapFrames.push(fallbackFrame);

        pixels = bitmapFrames[0];
        play("idle");
    }

    // -------------------------------------------
    // SAFE ANIMATION DATA LOADING
    // -------------------------------------------
    function parseAnimationData()
    {
        if (reader.data == null)
            return;

        // animations
        var animMap:Map<String, Dynamic> =
            cast reader.data.animations;

        if (animMap != null)
        {
            for (key in animMap.keys())
            {
                var arr:Array<Int> = cast animMap.get(key);
                if (arr != null)
                    animations.set(key, arr);
            }
        }

        // fps
        var fpsMap:Map<String, Dynamic> =
            cast reader.data.fps;

        if (fpsMap != null)
        {
            for (key in fpsMap.keys())
            {
                animFPS.set(key, cast fpsMap.get(key));
            }
        }

        // loops
        var loopMap:Map<String, Dynamic> =
            cast reader.data.loops;

        if (loopMap != null)
        {
            for (key in loopMap.keys())
            {
                animLoop.set(key, cast loopMap.get(key));
            }
        }
    }

    // -------------------------------------------
    // SAFE FRAME BUILDING
    // -------------------------------------------
    function buildFrames()
    {
        var frameArray:Array<Dynamic> =
            cast reader.data.frames;

        if (frameArray == null)
            return;

        for (frame in frameArray)
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

                var png = reader.getPNG(layer.symbol + ".png");
                if (png == null)
                    continue;

                var bmp = BitmapData.fromBytes(png);
                if (bmp == null)
                    continue;

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

    // -------------------------------------------
    // PLAY
    // -------------------------------------------
    public function play(name:String)
    {
        if (!animations.exists(name))
            name = "idle";

        curAnim = name;
        curFrame = 0;
        timer = 0;

        updateBitmap();
    }

    // -------------------------------------------
    // UPDATE
    // -------------------------------------------
    override function update(elapsed:Float)
    {
        var fps = animFPS.exists(curAnim) ? animFPS.get(curAnim) : 24;
        if (fps <= 0) fps = 24;

        timer += elapsed;
        var frameTime = 1 / fps;

        if (timer >= frameTime)
        {
            timer -= frameTime;
            var group = animations.get(curAnim);

            if (group != null && group.length > 0)
            {
                curFrame++;

                if (curFrame >= group.length)
                {
                    if (animLoop.exists(curAnim) && animLoop.get(curAnim))
                        curFrame = 0;
                    else
                        curFrame = group.length - 1;
                }

                updateBitmap();
            }
        }

        super.update(elapsed);
    }

    function updateBitmap()
    {
        var group = animations.get(curAnim);
        if (group == null || group.length == 0)
        {
            pixels = fallbackFrame;
            return;
        }

        var idx = group[curFrame];
        pixels = (idx >= 0 && idx < bitmapFrames.length) ? bitmapFrames[idx] : fallbackFrame;
    }
}
