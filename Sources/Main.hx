package ;

import zui.Canvas;

class Main {

	public static var prefs:Dynamic = null;
	public static var cwd = ""; // Canvas path
	static var inst:Elements;

	public static function main() {

		var w = 1280;
		var h = 690;
		if (w > kha.Display.width(0)) w = kha.Display.width(0);
		if (h > kha.Display.height(0)) h = kha.Display.height(0);
		kha.System.init({ title : "ArmorUI", width : w, height : h, resizable: true, maximizable: true }, initialized);
	}
	
	static function initialized() {

		// Debug
		// prefs = { scaleFactor: 2.0 };
		// var raw:TCanvas = { name: "debug", x: 0, y: 0, width: 960, height: 540, elements: [], assets: [] };
		// inst = new Elements(raw);
		// return;

		kha.LoaderImpl.loadBlobFromDescription({ files: ["prefs.json"] }, function(blob:kha.Blob) {
			prefs = haxe.Json.parse(blob.toString());

			var ar = prefs.path.split("/");
			ar.pop();
			cwd = ar.join("/");

			var path = kha.System.systemId == "Windows" ? StringTools.replace(prefs.path, "/", "\\") : prefs.path;
			kha.LoaderImpl.loadBlobFromDescription({ files: [path] }, function(cblob:kha.Blob) {
				var raw:TCanvas = haxe.Json.parse(cblob.toString());
				inst = new Elements(raw);
			});
		});
	}
}
