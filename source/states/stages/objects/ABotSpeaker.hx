package states.stages.objects;

import flixel.FlxSprite;
import flixel.FlxSpriteGroup;
import flixel.FlxSound;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.FlxG;

import backend.ClientPrefs;
import backend.Paths;

import flxanimate.FlxAnimate;

class ABotSpeaker extends FlxSpriteGroup
{
	// ===================================================
	// CONSTANTS
	// ===================================================

	final VIZ_MAX = 7;
	final VIZ_POS_X:Array<Float> = [0, 59, 56, 66, 54, 52, 51];
	final VIZ_POS_Y:Array<Float> = [0, -8, -3.5, -0.4, 0.5, 4.7, 7];

	public var bg:FlxSprite;
	public var vizSprites:Array<FlxSprite> = [];
	public var eyeBg:FlxSprite;
	public var eyes:FlxAnimate;
	public var speaker:FlxAnimate;

	// smooth amplitude
	var smoothAmp:Float = 0;

	// Sound input
	public var snd(default, set):FlxSound;
	function set_snd(value:FlxSound)
	{
		snd = value;
		return snd;
	}

	// ===================================================
	// CONSTRUCTOR
	// ===================================================

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);

		var aa = ClientPrefs.data.antialiasing;

		// ---------------------------------------------------
		// BACKPLATE
		// ---------------------------------------------------
		bg = new FlxSprite(90, 20).loadGraphic(Paths.image("abot/stereoBG"));
		bg.antialiasing = aa;
		add(bg);

		// ---------------------------------------------------
		// VISUALIZER BARS (7)
		// ---------------------------------------------------
		var vizAtlas = Paths.getSparrowAtlas("abot/aBotViz");
		var posX:Float = 0;
		var posY:Float = 0;

		for (i in 1...VIZ_MAX + 1)
		{
			posX += VIZ_POS_X[i - 1];
			posY += VIZ_POS_Y[i - 1];

			var bar = new FlxSprite(posX + 140, posY + 74);
			bar.frames = vizAtlas;

			bar.animation.addByPrefix("VIZ", 'viz$i', 0, false);
			bar.animation.play("VIZ");
			bar.animation.curAnim.finish(); // freeze to frame 0

			bar.antialiasing = aa;
			bar.updateHitbox();
			bar.centerOffsets();

			vizSprites.push(bar);
			add(bar);
		}

		// ---------------------------------------------------
		// EYE BACKGROUND
		// ---------------------------------------------------
		eyeBg = new FlxSprite(-30, 215).makeGraphic(1, 1, FlxColor.WHITE);
		eyeBg.scale.set(160, 60);
		eyeBg.updateHitbox();
		add(eyeBg);

		// ---------------------------------------------------
		// EYES
		// ---------------------------------------------------
		eyes = new FlxAnimate(-10, 230);
		Paths.loadAnimateAtlas(eyes, "abot/systemEyes");

		eyes.anim.addBySymbolIndices("lookleft", "a bot eyes lookin",
			[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17], 24, false);

		eyes.anim.addBySymbolIndices("lookright", "a bot eyes lookin",
			[18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35], 24, false);

		eyes.anim.play("lookright");
		eyes.anim.curFrame = eyes.anim.getFrameCount("lookright") - 1;

		add(eyes);

		// ---------------------------------------------------
		// SPEAKER (BOUNCES ON BEAT)
		// ---------------------------------------------------
		speaker = new FlxAnimate(-65, -10);
		Paths.loadAnimateAtlas(speaker, "abot/abotSystem");

		speaker.anim.addBySymbol("anim", "Abot System", 24, false);
		speaker.anim.play("anim");
		speaker.anim.curFrame = speaker.anim.getFrameCount("anim") - 1;

		speaker.antialiasing = aa;
		add(speaker);
	}

	// ===================================================
	// UPDATE — VOLUME-BASED VISUALIZER
	// ===================================================

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (snd == null || snd._channel == null)
			return;

		// ---------------------------------------------------
		// Read amplitude safely
		// ---------------------------------------------------
		@:privateAccess
		var amp:Float = snd._channel.__audioSource.get_currentLevel(); // 0 → 1

		amp = FlxMath.bound(amp, 0, 1);

		// smoothing (nice motion instead of jitter)
		smoothAmp = FlxMath.lerp(smoothAmp, amp, 0.2);

		// ---------------------------------------------------
		// Update each bar
		// ---------------------------------------------------
		for (i in 0...vizSprites.length)
		{
			var bar = vizSprites[i];

			// each bar has its own threshold
			var threshold = i * 0.1;

			// 0 → quiet, 5 → loud
			var frame = 5 - Std.int(FlxMath.bound((smoothAmp - threshold) * 6, 0, 5));

			bar.animation.curAnim.curFrame = frame;
		}
	}

	// ===================================================
	// BEAT REACTION
	// ===================================================

	public function beatHit():Void
	{
		speaker.anim.play("anim", true);
	}

	// ===================================================
	// EYE DIRECTION
	// ===================================================

	var lookingRight:Bool = true;

	public function lookLeft():Void
	{
		if (lookingRight)
			eyes.anim.play("lookleft", true);
		lookingRight = false;
	}

	public function lookRight():Void
	{
		if (!lookingRight)
			eyes.anim.play("lookright", true);
		lookingRight = true;
	}
}
