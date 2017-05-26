package;

import kha.Scheduler;
import kha.System;
import zui.Canvas;

class Main {

	public static var prefs:Dynamic = null;

	public static function main() {
		System.init({ title : "ArmorUI", width : 1240, height : 640 }, initialized);
	}
	
	private static function initialized(): Void {

		kha.LoaderImpl.loadBlobFromDescription({ files: ["prefs.json"] }, function(blob:kha.Blob) {
			prefs = haxe.Json.parse(blob.toString());

			kha.LoaderImpl.loadBlobFromDescription({ files: [prefs.path] }, function(cblob:kha.Blob) {
				var raw:TCanvas = haxe.Json.parse(cblob.toString());
				var inst = new Elements(raw);
				System.notifyOnRender(inst.render);
				Scheduler.addTimeTask(inst.update, 0, 1 / 60);
			});
		});
	}
}
