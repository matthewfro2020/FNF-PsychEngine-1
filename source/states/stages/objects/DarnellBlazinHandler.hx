package states.stages.objects;

import objects.Note;
import objects.Character;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;

class DarnellBlazinHandler
{
	public function new() {}

	// Prevent repeated uppercuts in a row
	var uppercutCooldown:Float = 0.0;

	// Prevent repeating animations every frame
	var lastPlayedAnim:String = "";

	inline function safePlay(anim:String, force:Bool = true)
	{
		if (dad == null) return;
		if (lastPlayedAnim == anim) return; // avoid animation spam
		if (!dad.animation.exists(anim)) return;

		dad.playAnim(anim, force);
		lastPlayedAnim = anim;
	}

	// ===========================================================
	// NOTE HIT LOGIC
	// ===========================================================
	var cantUppercut:Bool = false;

	public function noteHit(note:Note)
	{
		// Reset duplicate animation block
		lastPlayedAnim = "";

		// Reduce cooldown
		if (uppercutCooldown > 0)
			uppercutCooldown -= FlxG.elapsed;

		// SPECIAL CASE: If Pico hit badly at low health, Darnell tries an uppercut
		if (wasNoteHitPoorly(note.rating) && isPlayerLowHealth() && FlxG.random.bool(30) && uppercutCooldown <= 0)
		{
			playUppercutPrepAnim();
			uppercutCooldown = 0.8; // prevents spam
			return;
		}

		if (cantUppercut)
		{
			playPunchHighAnim();
			return;
		}

		switch (note.noteType)
		{
			case "weekend-1-punchlow": playHitLowAnim();
			case "weekend-1-punchlowblocked": playBlockAnim();
			case "weekend-1-punchlowdodged": playDodgeAnim();
			case "weekend-1-punchlowspin": playSpinAnim();

			case "weekend-1-punchhigh": playHitHighAnim();
			case "weekend-1-punchhighblocked": playBlockAnim();
			case "weekend-1-punchhighdodged": playDodgeAnim();
			case "weekend-1-punchhighspin": playSpinAnim();

			case "weekend-1-blockhigh": playPunchHighAnim();
			case "weekend-1-blocklow": playPunchLowAnim();
			case "weekend-1-blockspin": playPunchHighAnim();

			case "weekend-1-dodgehigh": playPunchHighAnim();
			case "weekend-1-dodgelow": playPunchLowAnim();
			case "weekend-1-dodgespin": playPunchHighAnim();

			case "weekend-1-hithigh": playPunchHighAnim();
			case "weekend-1-hitlow": playPunchLowAnim();
			case "weekend-1-hitspin": playPunchHighAnim();

			case "weekend-1-picouppercutprep": {}
			case "weekend-1-picouppercut": playUppercutHitAnim();

			case "weekend-1-darnelluppercutprep": playUppercutPrepAnim();
			case "weekend-1-darnelluppercut": playUppercutAnim();

			case "weekend-1-idle": playIdleAnim();
			case "weekend-1-fakeout": playCringeAnim();
			case "weekend-1-taunt": playPissedConditionalAnim();
			case "weekend-1-tauntforce": playPissedAnim();
			case "weekend-1-reversefakeout": playFakeoutAnim();
		}

		cantUppercut = false;
	}

	// ===========================================================
	// NOTE MISS LOGIC
	// ===========================================================
	public function noteMiss(note:Note)
	{
		lastPlayedAnim = "";

		// If Darnell prepped uppercut and Pico missed → FINISH HIM
		if (dad.getAnimationName() == "uppercutPrep")
		{
			playUppercutAnim();
			return;
		}

		if (willMissBeLethal())
		{
			playPunchLowAnim();
			return;
		}

		if (cantUppercut)
		{
			playPunchHighAnim();
			return;
		}

		switch (note.noteType)
		{
			case "weekend-1-punchlow", "weekend-1-punchlowblocked",
				 "weekend-1-punchlowdodged", "weekend-1-punchlowspin":
				playPunchLowAnim();

			case "weekend-1-punchhigh", "weekend-1-punchhighblocked",
				 "weekend-1-punchhighdodged", "weekend-1-punchhighspin":
				playPunchHighAnim();

			case "weekend-1-blockhigh": playPunchHighAnim();
			case "weekend-1-blocklow": playPunchLowAnim();
			case "weekend-1-blockspin": playPunchHighAnim();

			case "weekend-1-dodgehigh": playPunchHighAnim();
			case "weekend-1-dodgelow": playPunchLowAnim();
			case "weekend-1-dodgespin": playPunchHighAnim();

			case "weekend-1-hithigh": playPunchHighAnim();
			case "weekend-1-hitlow": playPunchLowAnim();
			case "weekend-1-hitspin": playPunchHighAnim();

			case "weekend-1-picouppercutprep":
				playHitHighAnim();
				cantUppercut = true;

			case "weekend-1-picouppercut":
				playDodgeAnim();

			case "weekend-1-darnelluppercutprep":
				playUppercutPrepAnim();

			case "weekend-1-darnelluppercut":
				playUppercutAnim();

			case "weekend-1-idle": playIdleAnim();
			case "weekend-1-fakeout": playCringeAnim();
			case "weekend-1-taunt": playPissedConditionalAnim();
			case "weekend-1-tauntforce": playPissedAnim();
			case "weekend-1-reversefakeout": playFakeoutAnim();
		}

		cantUppercut = false;
	}

	// ===========================================================
	// MISS-PRESS LOGIC
	// ===========================================================
	public function noteMissPress(direction:Int)
	{
		lastPlayedAnim = "";

		if (willMissBeLethal())
		{
			playPunchLowAnim();
			return;
		}

		// Pico wildly swings punches; Darnell alternates dodge/block
		if (FlxG.random.bool(50))
			playDodgeAnim();
		else
			playBlockAnim();
	}

	// ===========================================================
	// ANIMATION WRAPPERS (stabilized)
	// ===========================================================
	var alternate:Bool = false;
	function doAlternate():String
	{
		alternate = !alternate;
		return alternate ? "1" : "2";
	}

	function playBlockAnim() safePlay("block");
	function playCringeAnim() safePlay("cringe");
	function playDodgeAnim() safePlay("dodge");
	function playIdleAnim() safePlay("idle");
	function playFakeoutAnim() safePlay("fakeout");

	function playPissedConditionalAnim()
	{
		if (dad.getAnimationName() == "cringe")
			playPissedAnim();
		else
			playIdleAnim();
	}

	function playPissedAnim() safePlay("pissed");

	function playUppercutPrepAnim()
	{
		safePlay("uppercutPrep");
		uppercutCooldown = 0.8;
	}

	function playUppercutAnim() safePlay("uppercut");

	function playUppercutHitAnim() safePlay("uppercutHit");

	function playHitHighAnim() safePlay("hitHigh");
	function playHitLowAnim() safePlay("hitLow");

	function playPunchHighAnim()
		safePlay("punchHigh" + doAlternate());

	function playPunchLowAnim()
		safePlay("punchLow" + doAlternate());

	function playSpinAnim() safePlay("hitSpin");

	// ===========================================================
	// UTILITY / CONDITIONS
	// ===========================================================
	function willMissBeLethal()
	{
		return PlayState.instance.health <= 0 && !PlayState.instance.practiceMode;
	}

	function wasNoteHitPoorly(rating:String)
	{
		return rating == "bad" || rating == "shit";
	}

	function isPlayerLowHealth()
	{
		// FNF health max = 2.0
		return PlayState.instance.health <= 0.6; // more consistent threshold
	}

	// ===========================================================
	// Z-ORDER MANAGEMENT
	// ===========================================================
	function moveToBack()
	{
		if (dadGroup.z > boyfriendGroup.z)
			dadGroup.z = boyfriendGroup.z - 1;
	}

	function moveToFront()
	{
		if (dadGroup.z < boyfriendGroup.z)
			dadGroup.z = boyfriendGroup.z + 1;
	}

	// ===========================================================
	// GETTERS
	// ===========================================================
	var boyfriend(get, never):Character;
	var dad(get, never):Character;
	var boyfriendGroup(get, never):FlxSpriteGroup;
	var dadGroup(get, never):FlxSpriteGroup;

	function get_boyfriend() return PlayState.instance.boyfriend;
	function get_dad() return PlayState.instance.dad;
	function get_boyfriendGroup() return PlayState.instance.boyfriendGroup;
	function get_dadGroup() return PlayState.instance.dadGroup;
}
