package ;

import zui.Canvas;

class Main {

	public static var prefs:TPrefs = null;
	public static var cwd = ""; // Canvas path
	static var inst:Elements;

	public static function main() {

		var w = 1600;
		var h = 900;
		if (w > kha.Display.primary.width) w = kha.Display.primary.width;
		if (h > kha.Display.primary.height - 30) h = kha.Display.primary.height - 30;
		kha.System.start({ title : "Armory2D", width : w, height : h }, initialized);
	}
	
	static function initialized(window:kha.Window) {

		prefs = { path: "", scaleFactor: 1.0 };

		#if kha_krom
		
		var c = Krom.getArgCount();
		// ./krom . . canvas_path scale_factor
		if (c > 4) prefs.path = Krom.getArg(3);
		if (c > 5) prefs.scaleFactor = Std.parseFloat(Krom.getArg(4));

		var ar = prefs.path.split("/");
		ar.pop();
		cwd = ar.join("/");

		var path = kha.System.systemId == "Windows" ? StringTools.replace(prefs.path, "/", "\\") : prefs.path;
		kha.Assets.loadBlobFromPath(path, function(cblob:kha.Blob) {
			var raw:TCanvas = haxe.Json.parse(cblob.toString());
			inst = new Elements(raw);
		});
		
		#else

		var raw:TCanvas = { name: "untitled", x: 0, y: 0, width: 1280, height: 720, elements: [], assets: [] };
		inst = new Elements(raw);

		#end		
	}
}

typedef TPrefs = {
	var path:String;
	var scaleFactor:Float;
	@:optional var window_vsync:Bool;
}
