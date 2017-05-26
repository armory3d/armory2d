package;
import kha.Framebuffer;
import kha.Assets;

import zui.*;
import zui.Canvas;

@:access(zui.Zui)
class Elements {
	var ui: Zui;
	var cui: Zui;
	var initialized = false;

	var bg:kha.Image = null;

	var canvas:TCanvas;

	function onDrop(file:String) {
		kha.LoaderImpl.loadImageFromDescription({ files: [file] }, function(image:kha.Image) {
			var s = file.split("/");
			var name = s[s.length - 1];
			var asset:TAsset = { name: name, file: file, image: image };
			canvas.assets.push(asset);
		});
	}

	public function new(canvas:TCanvas) {

		this.canvas = canvas;

		var _onDrop = onDrop;
		untyped __js__("
		document.ondragover = document.ondrop = (ev) => {
			ev.preventDefault()
		}
		document.body.ondrop = (ev) => {
			_onDrop(ev.dataTransfer.files[0].path);
			ev.preventDefault()
		}
		");

		Assets.loadEverything(loadingFinished);
	}

	function loadingFinished() {
		initialized = true;
		var t = Reflect.copy(Themes.dark);
		t.FILL_WINDOW_BG = true;
		ui = new Zui({font: Assets.fonts.DroidSans, theme: t});
		cui = new Zui({font: Assets.fonts.DroidSans, autoNotifyInput: false});
	}

	function makeElem(type:ElementType) {
		var name = "";
		var height = 100;
		if (type == ElementType.Text) {
			name = "Text";
			height = 48;
		}
		else if (type == ElementType.Button) {
			name = "Button";
		}
		else if (type == ElementType.Image) {
			name = "Image";
		}
		var elem:TElement = {
			id: 0,
			type: type,
			name: name,
			event: "",
			x: 0,
			y: 0,
			width: 150,
			height: height,
			text: name,
			asset: "",
			color: 0xffffff,
			anchor: 0,
			children: []
		};
		return elem;
	}

	var selectedElem = -1;
	var handlewin = Id.handle();
	var handleradio = Id.handle();
	public function render(framebuffer: Framebuffer): Void {
		if (!initialized) return;

		if (bg == null) {
			var w = kha.System.windowWidth();
			var h = kha.System.windowHeight();
			bg = kha.Image.createRenderTarget(w, h);
			bg.g2.begin(true, 0xff141414);
			for (i in 0...Std.int(h / 40) + 1) {
				bg.g2.color = 0xff303030;
				bg.g2.drawLine(0, i * 40, w, i * 40);
				bg.g2.color = 0xff202020;
				bg.g2.drawLine(0, i * 40 + 20, w, i * 40 + 20);
			}
			for (i in 0...Std.int(w / 40) + 1) {
				bg.g2.color = 0xff303030;
				bg.g2.drawLine(i * 40, 0, i * 40, h);
				bg.g2.color = 0xff202020;
				bg.g2.drawLine(i * 40 + 20, 0, i * 40 + 20, h);
			}

			bg.g2.color = 0xffffffff;
			canvas.x = kha.System.windowWidth() - canvas.width - 20;
			canvas.y = 40;
			bg.g2.drawRect(canvas.x, canvas.y, canvas.width, canvas.height, 1.0);

			bg.g2.end();
		}

		var g = framebuffer.g2;

		g.begin();

		g.drawImage(bg, 0, 0);

		g.font = kha.Assets.fonts.DroidSans;
		g.fontSize = 40;
		var title = canvas.name + ", " + canvas.width + "x" + canvas.height;
		var titlew = g.font.width(40, title);
		var titleh = g.font.height(40);
		g.color = 0xffffffff;
		g.drawString(title, kha.System.windowWidth() - titlew - 30, kha.System.windowHeight() - titleh - 10);
		
		Canvas.draw(cui, canvas, g);

		// Outline selected elem
		if (selectedElem >= 0 && selectedElem < canvas.elements.length) {
			var elem = canvas.elements[selectedElem];
			g.color = 0xffffffff;
			g.drawRect(canvas.x + elem.x, canvas.y + elem.y, elem.width, elem.height, 1);
		}

		g.end();

		ui.begin(g);
		// window() returns true if redraw is needed - windows are cached into textures
		if (ui.window(handlewin, 0, 0, 240, 640, false)) {

			if (ui.panel(Id.handle({selected: true}), "CANVAS")) {
				// ui.row([1/3, 1/3, 1/3]);
				// if (ui.button("New")) {
				// 	untyped __js__("const {dialog} = require('electron').remote");
				// 	untyped __js__("dialog.showMessageBox({type: 'question', buttons: ['Yes', 'No'], title: 'Confirm', message: 'Create new canvas?'})");
				// }

				// if (ui.button("Open")) {
				// 	untyped __js__("const {dialog} = require('electron').remote");
				// 	untyped __js__("console.log(dialog.showOpenDialog({properties: ['openFile', 'openDirectory', 'multiSelections']}))");
				// }

				if (ui.button("Save")) {
					// untyped __js__("const {dialog} = require('electron').remote");
					// untyped __js__("console.log(dialog.showSaveDialog({properties: ['saveFile', 'saveDirectory']}))");

					untyped __js__("var fs = require('fs')");
					untyped __js__("fs.writeFileSync({0}, {1})", Main.prefs.path, haxe.Json.stringify(canvas));
				}
				canvas.name = ui.textInput(Id.handle({text: canvas.name}), "Name", Right);
				// ui.row([1/2, 1/2]);
				// var strw = ui.textInput(Id.handle({text: canvas.width + ""}), "Width", Right);
				// var strh = ui.textInput(Id.handle({text: canvas.height + ""}), "Height", Right);
				// canvas.width = Std.parseInt(strw);
				// canvas.height = Std.parseInt(strh);
			}

			ui.separator();

			if (ui.panel(Id.handle({selected: true}), "TREE")) {
				ui.row([1/3, 1/3, 1/3]);
				if (ui.button("Text")) {
					var elem = makeElem(ElementType.Text);
					canvas.elements.push(elem);
					handleradio.position = canvas.elements.length - 1;
				}
				if (ui.button("Image")) {
					var elem = makeElem(ElementType.Image);
					canvas.elements.push(elem);
					handleradio.position = canvas.elements.length - 1;
				}
				if (ui.button("Button")) {
					var elem = makeElem(ElementType.Button);
					canvas.elements.push(elem);
					handleradio.position = canvas.elements.length - 1;
				}

				var i = 0;
				for (elem in canvas.elements) {
					if (ui.radio(handleradio, i++, elem.name)) selectedElem = i - 1;
				}

				if (canvas.elements.length > 0) {
					if (ui.button("Remove")) {
						canvas.elements.splice(selectedElem, 1);
						if (selectedElem <= canvas.elements.length) {
							selectedElem--;
							handleradio.position = selectedElem;
						}
					}
				}
			}

			ui.separator();

			if (ui.panel(Id.handle({selected: true}), "PROPERTIES")) {
				var i = selectedElem;
				if (i >= 0) {
					var elem = canvas.elements[i];
					ui.row([1/2, 1/2]);
					elem.name = ui.textInput(Id.handle().nest(i, {text: elem.name}), "Name", Right);
					elem.text = ui.textInput(Id.handle().nest(i, {text: elem.text}), "Text", Right);
					ui.row([1/2, 1/2]);
					elem.event = ui.textInput(Id.handle().nest(i, {text: elem.event}), "Event", Right);
					elem.asset = ui.textInput(Id.handle().nest(i, {text: elem.asset}), "Asset", Right);
					ui.row([1/2, 1/2]);
					var handlex = Id.handle().nest(i, {text: elem.x + ""});
					var handley = Id.handle().nest(i, {text: elem.y + ""});
					// if (drag) {
						handlex.text = elem.x + "";
						handley.text = elem.y + "";
					// }
					var strx = ui.textInput(handlex, "X", Right);
					var stry = ui.textInput(handley, "Y", Right);
					elem.x = Std.parseFloat(strx);
					elem.y = Std.parseFloat(stry);
					ui.row([1/2, 1/2]);
					var strw = ui.textInput(Id.handle().nest(i, {text: elem.width + ""}), "Width", Right);
					var strh = ui.textInput(Id.handle().nest(i, {text: elem.height + ""}), "Height", Right);
					elem.width = Std.int(Std.parseFloat(strw));
					elem.height = Std.int(Std.parseFloat(strh));
					ui.row([1/2, 1/2]);
					var strcol = ui.textInput(Id.handle().nest(i, {text: "#ffffff"}), "Color", Right);
					var stranch = ui.textInput(Id.handle().nest(i, {text: elem.anchor + ""}), "Anchor", Right);
					elem.color = kha.Color.fromString(strcol);
					elem.anchor = Std.int(Std.parseFloat(stranch));
				}
			}

			ui.separator();

			if (ui.panel(Id.handle({selected: true}), "ASSETS")) {
				if (canvas.assets.length > 0) {
					for (i in 0...canvas.assets.length) {
						var asset = canvas.assets[i];
						ui.image(asset.image);
						asset.name = ui.textInput(Id.handle().nest(i, {text: asset.name}), "Name", Right);
					}
				}
				else {
					ui.text("Drag & drop assets here");
				}
			}
		}
		ui.end();
	}

	var drag = false;
	public function update() {
		if (!initialized) return;

		// Drag selected elem
		if (selectedElem >= 0 && selectedElem < canvas.elements.length) {
			var elem = canvas.elements[selectedElem];

			if (ui.inputStarted &&
				ui.inputX > canvas.x + elem.x && ui.inputX < canvas.x + elem.x + elem.width &&
				ui.inputY > canvas.y + elem.y && ui.inputY < canvas.y + elem.y + elem.height) {
				drag = true;
			}
			if (ui.inputReleased && drag) {
				drag = false;
			}

			if (drag) {
				handlewin.redraws = 2;
				elem.x += ui.inputDX;
				elem.y += ui.inputDY;
			}
		}
	}
}
