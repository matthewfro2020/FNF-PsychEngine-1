package states.stages.objects;

import objects.Note;
import objects.Character;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;

class PicoBlazinHandler
{
	public function new() {}

	// Prevent repeated animation spam
	var lastPlayedAnim:String = "";

	// Track whether Pico cannot uppercut this turn
	var cantUppercut:Bool = false;

	// --------------------------------------------------------------
	// SAFE PLAY ANIMATION
	// --------------------------------------------------------------
	inline function safePlay(anim:String, force:Bool = true)
	{
		if (boyfriend == null) return;
		if (lastPlayedAnim == anim) return; // avoid spam
		if (!boyfriend.animation.exists(anim)) return;

		boyfriend.playAnim(anim, force);
		lastPlayedAnim = anim;
	}

	// --------------------------------------------------------------
	// NOTE HIT
	// --------------------------------------------------------------
	public function noteHit(note:Note)
	{
		lastPlayedAnim = "";

		// SPECIAL CASE: If Pico hits badly while low health and Darnell is uppercutting
		if (wasNoteHitPoorly(note.rating) && isPlayerLowHealth() && isDarnellPreppingUppercut())
		{
			playPunchHighAnim();
			return;
		}

		// Pico cannot uppercut this turn
		if (cantUppercut)
		{
			playBlockAnim();
			cantUppercut = false;
			return;
		}

		switch (note.noteType)
		{
			case "weekend-1-punchlow",
				 "weekend-1-punchlowblocked",
				 "weekend-1-punchlowdodged",
				 "weekend-1-punchlowspin":
				playPunchLowAnim();

			case "weekend-1-punchhigh",
				 "weekend-1-punchhighblocked",
				 "weekend-1-punchhighdodged",
				 "weekend-1-punchhighspin":
				playPunchHighAnim();

			case "weekend-1-blockhigh",
				 "weekend-1-blocklow",
				 "weekend-1-blockspin":
				playBlockAnim();

			case "weekend-1-dodgehigh",
				 "weekend-1-dodgelow",
				 "weekend-1-dodgespin":
				playDodgeAnim();

			// Pico ALWAYS gets punched
			case "weekend-1-hithigh": playHitHighAnim();
			case "weekend-1-hitlow": playHitLowAnim();
			case "weekend-1-hitspin": playHitSpinAnim();

			// Pico's uppercut
			case "weekend-1-picouppercutprep":
				playUppercutPrepAnim();

			case "weekend-1-picouppercut":
				playUppercutAnim(true);

			// Darnell uppercut
			case "weekend-1-darnelluppercutprep":
				playIdleAnim();

			case "weekend-1-darnelluppercut":
				playUppercutHitAnim();

			case "weekend-1-idle":
				playIdleAnim();

			case "weekend-1-fakeout":
				playFakeoutAnim();

			case "weekend-1-taunt":
				playTauntConditionalAnim();

			case "weekend-1-tauntforce":
				playTauntAnim();

			case "weekend-1-reversefakeout":
				playIdleAnim();
		}
	}

	// --------------------------------------------------------------
	// NOTE MISS
	// --------------------------------------------------------------
	public function noteMiss(note:Note)
	{
		lastPlayedAnim = "";

		// If Darnell is in uppercut, Pico gets hit no matter what
		if (isDarnellInUppercut())
		{
			playUppercutHitAnim();
			return;
		}

		// Lethal miss (health at 0)
		if (willMissBeLethal())
		{
			playHitLowAnim();
			return;
		}

		if (cantUppercut)
		{
			playHitHighAnim();
			return;
		}

		switch (note.noteType)
		{
			// Pico fails to punch → gets hit
			case "weekend-1-punchlow",
				 "weekend-1-punchlowblocked",
				 "weekend-1-punchlowdodged",
				 "weekend-1-punchlowspin":
				playHitLowAnim();

			// high punch fails
			case "weekend-1-punchhigh",
				 "weekend-1-punchhighblocked",
				 "weekend-1-punchhighdodged",
				 "weekend-1-punchhighspin":
				playHitHighAnim();

			// fail block
			case "weekend-1-blockhigh": playHitHighAnim();
			case "weekend-1-blocklow": playHitLowAnim();
			case "weekend-1-blockspin": playHitSpinAnim();

			// fail dodge
			case "weekend-1-dodgehigh": playHitHighAnim();
			case "weekend-1-dodgelow": playHitLowAnim();
			case "weekend-1-dodgespin": playHitSpinAnim();

			// Darnell hit types
			case "weekend-1-hithigh": playHitHighAnim();
			case "weekend-1-hitlow": playHitLowAnim();
			case "weekend-1-hitspin": playHitSpinAnim();

			// Pico tried uppercut prep but missed
			case "weekend-1-picouppercutprep":
				playPunchHighAnim();
				cantUppercut = true;

			case "weekend-1-picouppercut":
				playUppercutAnim(false);

			case "weekend-1-darnelluppercutprep":
				playIdleAnim();

			case "weekend-1-darnelluppercut":
				playUppercutHitAnim();

			case "weekend-1-idle":
				playIdleAnim();

			case "weekend-1-fakeout":
				playHitHighAnim();

			case "weekend-1-taunt":
				playTauntConditionalAnim();

			case "weekend-1-tauntforce":
				playTauntAnim();

			case "weekend-1-reversefakeout":
				playIdleAnim();
		}
	}

	// --------------------------------------------------------------
	// MISS PRESS
	// --------------------------------------------------------------
	public function noteMissPress(direction:Int)
	{
		if (willMissBeLethal())
			playHitLowAnim();
		else
			playPunchHighAnim(); // Pico flails wildly
	}

	// --------------------------------------------------------------
	// ANIMATION HELPERS (with Z ordering)
	// --------------------------------------------------------------
	var alternate:Bool = false;
	function doAlternate():String
	{
		alternate = !alternate;
		return alternate ? "1" : "2";
	}

	function moveToBack()
	{
		if (boyfriendGroup.z > dadGroup.z)
			boyfriendGroup.z = dadGroup.z - 1;
	}

	function moveToFront()
	{
		if (boyfriendGroup.z < dadGroup.z)
			boyfriendGroup.z = dadGroup.z + 1;
	}

	function playBlockAnim() safePlay("block");
	function playCringeAnim() safePlay("cringe");
	function playDodgeAnim() safePlay("dodge");
	function playIdleAnim() safePlay("idle", false);
	function playFakeoutAnim() safePlay("fakeout");

	function playUppercutPrepAnim()
	{
		safePlay("uppercutPrep");
		moveToFront();
	}

	function playUppercutAnim(hit:Bool)
	{
		safePlay("uppercut");
		if (hit) FlxG.camera.shake(0.005, 0.25);
		moveToFront();
	}

	function playUppercutHitAnim()
	{
		safePlay("uppercutHit");
		FlxG.camera.shake(0.005, 0.25);
		moveToBack();
	}

	function playHitHighAnim()
	{
		safePlay("hitHigh");
		FlxG.camera.shake(0.0025, 0.15);
		moveToBack();
	}

	function playHitLowAnim()
	{
		safePlay("hitLow");
		FlxG.camera.shake(0.0025, 0.15);
		moveToBack();
	}

	function playHitSpinAnim()
	{
		safePlay("hitSpin");
		FlxG.camera.shake(0.0025, 0.15);
		moveToBack();
	}

	function playPunchHighAnim()
	{
		safePlay("punchHigh" + doAlternate());
		moveToFront();
	}

	function playPunchLowAnim()
	{
		safePlay("punchLow" + doAlternate());
		moveToFront();
	}

	function playTauntConditionalAnim()
	{
		if (boyfriend.getAnimationName() == "fakeout")
			playTauntAnim();
		else
			playIdleAnim();
	}

	function playTauntAnim()
	{
		safePlay("taunt");
		moveToBack();
	}

	// --------------------------------------------------------------
	// CONDITIONS
	// --------------------------------------------------------------
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
		return PlayState.instance.health <= 0.6; // more correct threshold
	}

	function isDarnellPreppingUppercut()
	{
		return dad.getAnimationName() == "uppercutPrep";
	}

	function isDarnellInUppercut()
	{
		var anim = dad.getAnimationName();
		return anim == "uppercut" || anim == "uppercut-hold";
	}

	// --------------------------------------------------------------
	// GETTERS
	// --------------------------------------------------------------
	var boyfriend(get, never):Character;
	var dad(get, never):Character;
	var boyfriendGroup(get, never):FlxSpriteGroup;
	var dadGroup(get, never):FlxSpriteGroup;

	function get_boyfriend() return PlayState.instance.boyfriend;
	function get_dad() return PlayState.instance.dad;
	function get_boyfriendGroup() return PlayState.instance.boyfriendGroup;
	function get_dadGroup() return PlayState.instance.dadGroup;
}
