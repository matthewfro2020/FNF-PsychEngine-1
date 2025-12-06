package animate;

import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.geom.Matrix;
import sys.FileSystem;
import openfl.display.PNGDecoder;
import flixel.FlxSprite;
import haxe.Json;

class AnimateCharacter extends FlxSprite
{
    public var frames:Array<BitmapData> = [];
    public var frameIndex:Int = 0;
    public var frameTime:Float = 0;
    public var frameRate:Int = 24;

    var reader:AnimateZipReader;

    public function new(zipPath:String)
    {
        super();

        reader = new AnimateZipReader(zipPath);

        loadFrames();
        if (frames.length > 0)
            this.pixels = frames[0];
    }

    function loadFrames()
    {
        for (frame in reader.data.frames)
        {
            var canvas = new BitmapData(2000, 2000, true, 0x00000000);
            var spr = new Sprite();

            for (layer in frame)
            {
                var symbol = layer.symbol + ".png";
                var t = layer.transformation;

                var pngBytes = reader.getSymbolPNG(symbol);
                if (pngBytes == null) continue;

                var bmp = BitmapData.fromBytes(pngBytes);

                var mat = new Matrix();
                mat.translate(t.x, t.y);
                mat.scale(t.sx, t.sy);
                mat.c = t.kx;
                mat.d = t.ky;

                spr.graphics.beginBitmapFill(bmp, mat, false);
                spr.graphics.drawRect(t.x, t.y, bmp.width, bmp.height);
                spr.graphics.endFill();
            }

            canvas.draw(spr);
            frames.push(canvas);
        }
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        frameTime += elapsed;
        if (frameTime >= 1 / frameRate)
        {
            frameTime = 0;
            frameIndex = (frameIndex + 1) % frames.length;

            this.pixels = frames[frameIndex];
            this.dirty = true;
        }
    }
}
