package hxvlc.flixel;

#if flixel
import flixel.math.FlxMath;
import flixel.util.FlxAxes;
import flixel.FlxG;
import haxe.io.Bytes;
import haxe.io.Path;
import hxvlc.externs.Types;
import hxvlc.util.macros.Define;
import hxvlc.util.Location;
import hxvlc.openfl.Video;
import openfl.utils.Assets;
import sys.FileSystem;

using StringTools;

/**
 * This class extends Video to display video files in HaxeFlixel.
 *
 * ```haxe
 * var video:FlxVideo = new FlxVideo();
 * video.onEndReached.add(function():Void
 * {
 * 	video.dispose();
 *
 * 	FlxG.removeChild(video);
 * });
 * FlxG.addChildBelowMouse(video);
 *
 * if (video.load('assets/videos/video.mp4'))
 * 	FlxTimer.wait(0.001, () -> video.play());
 * ```
 */
@:nullSafety
class FlxVideo extends Video
{
	/**
	 * Whether the video should automatically pause when focus is lost.
	 *
	 * WARNING: Must be set before loading a video.
	 */
	public var autoPause:Bool = FlxG.autoPause;

	/**
	 * Determines the automatic resizing behavior for the video.
	 *
	 * WARNING: Must be set before loading a video if you want to set it to `NONE`.
	 */
	public var autoResizeMode:FlxAxes = FlxAxes.XY;

	#if FLX_SOUND_SYSTEM
	/**
	 * Whether Flixel should automatically adjust the volume according to the Flixel sound system's current volume.
	 */
	public var autoVolumeHandle:Bool = true;
	#end

	/**
	 * Initializes a FlxVideo object.
	 *
	 * @param smoothing Whether or not the video is smoothed when scaled.
	 */
	public function new(smoothing:Bool = true):Void
	{
		super(smoothing);

		onOpening.add(function():Void
		{
			role = LibVLC_Role_Game;

			#if FLX_SOUND_SYSTEM
			if (autoVolumeHandle)
			{
				#if (flixel >= "5.9.0")
				FlxG.sound.onVolumeChange.add(onVolumeChange);
				#else
				volume = Math.floor(FlxMath.bound(getCalculatedVolume(), 0, 1) * Define.getFloat('HXVLC_FLIXEL_VOLUME_MULTIPLIER', 100));
				#end
			}
			#end
		});
	}

	#if FLX_SOUND_SYSTEM
	/**
	 * Calculates and returns the current volume based on Flixel's sound settings by default.
	 *
	 * The volume is automatically clamped between `0` and `1` by the calling code. If the sound is muted, the volume is `0`.
	 *
	 * @return The calculated volume.
	 */
	public dynamic function getCalculatedVolume():Float
	{
		return (FlxG.sound.muted ? 0 : 1) * FlxG.sound.volume;
	}
	#end

	/**
	 * Loads a video.
	 *
	 * @param location The local filesystem path, the media location URL, the ID of an open file descriptor, or the bitstream input.
	 * @param options Additional options to add to the LibVLC Media.
	 * @return `true` if the video loaded successfully, `false` otherwise.
	 */
	public override function load(location:Location, ?options:Array<String>):Bool
	{
		if (autoPause)
		{
			if (!FlxG.signals.focusGained.has(resume))
				FlxG.signals.focusGained.add(resume);

			if (!FlxG.signals.focusLost.has(pause))
				FlxG.signals.focusLost.add(pause);
		}

		if (location != null && !(location is Int) && !(location is Bytes) && (location is String))
		{
			final location:String = cast(location, String);

			if (!location.contains('://'))
			{
				final absolutePath:String = FileSystem.absolutePath(location);

				if (FileSystem.exists(absolutePath))
					return super.load(absolutePath, options);
				else if (Assets.exists(location))
				{
					final assetPath:String = Assets.getPath(location);

					if (assetPath != null)
					{
						if (FileSystem.exists(assetPath) && Path.isAbsolute(assetPath))
							return super.load(assetPath, options);
						else if (!Path.isAbsolute(assetPath))
						{
							try
							{
								final assetBytes:Bytes = Assets.getBytes(location);

								if (assetBytes != null)
									return super.load(assetBytes, options);
							}
							catch (e:Dynamic)
							{
								FlxG.log.error('Error loading asset bytes from location "$location": $e');

								return false;
							}
						}
					}

					return false;
				}
				else
				{
					FlxG.log.warn('Unable to find the video file at location "$location".');

					return false;
				}
			}
		}

		return super.load(location, options);
	}

	public override function dispose():Void
	{
		if (FlxG.signals.focusGained.has(resume))
			FlxG.signals.focusGained.remove(resume);

		if (FlxG.signals.focusLost.has(pause))
			FlxG.signals.focusLost.remove(pause);

		#if (FLX_SOUND_SYSTEM && flixel >= "5.9.0")
		FlxG.sound.onVolumeChange.remove(onVolumeChange);
		#end

		super.dispose();
	}

	@:noCompletion
	private override function update(deltaTime:Int):Void
	{
		if ((autoResizeMode.x || autoResizeMode.y) && bitmapData != null)
		{
			width = autoResizeMode.x ? FlxG.scaleMode.gameSize.x : bitmapData.width;
			height = autoResizeMode.y ? FlxG.scaleMode.gameSize.y : bitmapData.height;
		}

		#if (FLX_SOUND_SYSTEM && flixel < "5.9.0")
		if (autoVolumeHandle)
			volume = Math.floor(FlxMath.bound(getCalculatedVolume(), 0, 1) * Define.getFloat('HXVLC_FLIXEL_VOLUME_MULTIPLIER', 100));
		#end

		super.update(deltaTime);
	}

	#if (FLX_SOUND_SYSTEM && flixel >= "5.9.0")
	@:noCompletion
	private function onVolumeChange(volume:Float):Void
	{
		this.volume = Math.floor(FlxMath.bound(getCalculatedVolume(), 0, 1) * Define.getFloat('HXVLC_FLIXEL_VOLUME_MULTIPLIER', 100));
	}
	#end
}
#end
