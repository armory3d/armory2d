package arm2d;

import kha.math.Vector2;
import kha.input.KeyCode;
using kha.graphics2.GraphicsExtension;

import zui.*;
import zui.Zui;
import zui.Canvas;
import zui.Popup;
using zui.Ext;


import arm2d.ui.UIToolBar;
import arm2d.ui.UIProperties;
import arm2d.tools.CanvasTools;
import arm2d.tools.Math;
import arm2d.Assets;
import arm2d.Path;

@:access(zui.Zui)
class Elements {
	var ui:Zui;
	public var cui:Zui;
	public var canvas:TCanvas;

	public static var defaultWindowW = 240;
	public static var windowW = defaultWindowW;
	static var uiw(get, null):Int;
	static function get_uiw():Int {
		return Std.int(windowW * Main.prefs.scaleFactor);
	}
	var toolbarw(get, null):Int;
	function get_toolbarw():Int {
		return Std.int(140 * ui.SCALE());
	}
	var handleSize(get, null):Int;
	inline function get_handleSize():Int {
		return Std.int(8 * ui.SCALE());
	}
	public static var coffX = 70.0;
	public static var coffY = 50.0;

	var dropPath = "";
	var currentOperation = "";
	var isManipulating = false;
	var transformInitInput:Vector2;
	var transformInitPos:Vector2;
	var transformInitRot:Float;
	var transformInitSize:Vector2;
	// Was the transformation editing started by dragging the mouse
	var transformStartedMouse = false;
	var drag = false;
	var dragLeft = false;
	var dragTop = false;
	var dragRight = false;
	var dragBottom = false;
	var grab = false;
	var grabX = false;
	var grabY = false;
	var rotate = false;
	public static var assetNames:Array<String> = [""];
	public static var dragAsset:TAsset = null;
	var resizeCanvas = false;
	var zoom = 1.0;

	public static var showFiles = false;
	public static var foldersOnly = false;
	public static var filesDone:String->Void = null;
	var uimodal:Zui;

	public static var gridSnapBounds:Bool = false;
	public static var gridSnapPos:Bool = true;
	public static var gridUseRelative:Bool = true;
	public static var useRotationSteps:Bool = false;
	public static var gridSize:Int = 20;
	public static var rotationSteps:Float = Math.toRadians(15);
	static var grid:kha.Image = null;
	static var timeline:kha.Image = null;

	var selectedFrame = 0;
	public static var selectedTheme:zui.Themes.TTheme = null;
	public static var selectedElem:TElement = null;
	public var hwin = Id.handle();
	var lastW = 0;
	var lastH = 0;
	var lastCanvasW = 0;
	var lastCanvasH = 0;

	public function new(canvas:TCanvas) {
		this.canvas = canvas;

		// Reimport assets
		if (canvas.assets.length > 0) {
			var assets = canvas.assets;
			canvas.assets = [];
			for (a in assets) Assets.importAsset(canvas, a.file);
		}

		Assets.importThemes();

		kha.Assets.loadEverything(loaded);
	}

	function loaded() {
		var t = Reflect.copy(Themes.dark);
		t.FILL_WINDOW_BG = true;
		ui = new Zui({scaleFactor: Main.prefs.scaleFactor, font: kha.Assets.fonts.font_default, theme: t, color_wheel: kha.Assets.images.color_wheel});
		cui = new Zui({scaleFactor: 1.0, font: kha.Assets.fonts.font_default, autoNotifyInput: true, theme: Reflect.copy(Canvas.getTheme(canvas.theme))});
		uimodal = new Zui( { font: kha.Assets.fonts.font_default, scaleFactor: Main.prefs.scaleFactor } );

		if (Canvas.getTheme(canvas.theme) == null) {
			Popup.showMessage(new Zui(ui.ops), "Error!",
				'Theme "${canvas.theme}" was not found!'
				+ '\nUsing first theme in list instead: "${Canvas.themes[0].NAME}"');
			canvas.theme = Canvas.themes[0].NAME;
		}

		kha.System.notifyOnDropFiles(function(path:String) {
			dropPath = StringTools.rtrim(path);
			dropPath = Path.toRelative(dropPath, Main.cwd);
		});

		kha.System.notifyOnFrames(onFrames);
		kha.Scheduler.addTimeTask(update, 0, 1 / 60);
	}

	function resize() {
		if (grid != null) {
			grid.unload();
			grid = null;
		}
		if (timeline != null) {
			timeline.unload();
			timeline = null;
		}
	}

	function drawGrid() {
		var doubleGridSize = gridSize * 2;
		var ww = kha.System.windowWidth();
		var wh = kha.System.windowHeight();
		var w = ww + doubleGridSize * 2;
		var h = wh + doubleGridSize * 2;
		grid = kha.Image.createRenderTarget(w, h);
		grid.g2.begin(true, 0xff242424);
		for (i in 0...Std.int(h / doubleGridSize) + 1) {
			grid.g2.color = 0xff282828;
			grid.g2.drawLine(0, i * doubleGridSize, w, i * doubleGridSize);
			grid.g2.color = 0xff323232;
			grid.g2.drawLine(0, i * doubleGridSize + gridSize, w, i * doubleGridSize + gridSize);
		}
		for (i in 0...Std.int(w / doubleGridSize) + 1) {
			grid.g2.color = 0xff282828;
			grid.g2.drawLine(i * doubleGridSize, 0, i * doubleGridSize, h);
			grid.g2.color = 0xff323232;
			grid.g2.drawLine(i * doubleGridSize + gridSize, 0, i * doubleGridSize + gridSize, h);
		}

		grid.g2.end();
	}

	function drawTimeline(timelineLabelsHeight:Int, timelineFramesHeight:Int) {
		var sc = ui.SCALE();

		var timelineHeight = timelineLabelsHeight + timelineFramesHeight;

		timeline = kha.Image.createRenderTarget(kha.System.windowWidth() - uiw - toolbarw, timelineHeight);

		var g = timeline.g2;
		g.begin(true, 0xff222222);
		g.font = kha.Assets.fonts.font_default;
		g.fontSize = Std.int(16 * sc);

		// Labels
		var frames = Std.int(timeline.width / (11 * sc));
		for (i in 0...Std.int(frames / 5) + 1) {
			var frame = i * 5;

			var frameTextWidth = kha.Assets.fonts.font_default.width(g.fontSize, frame + "");
			g.drawString(frame + "", i * 55 * sc + 5 * sc - frameTextWidth / 2, timelineLabelsHeight / 2 - g.fontSize / 2);
		}

		// Frames
		for (i in 0...frames) {
			g.color = i % 5 == 0 ? 0xff444444 : 0xff333333;
			g.fillRect(i * 11 * sc, timelineHeight - timelineFramesHeight, 10 * sc, timelineFramesHeight);
		}

		g.end();
	}

	public function onFrames(framebuffers: Array<kha.Framebuffer>): Void {
		var framebuffer = framebuffers[0];

		// Disable UI if a popup is displayed
		if (Popup.show && ui.inputRegistered) {
			ui.unregisterInput();
			cui.unregisterInput();
		} else if (!Popup.show && !ui.inputRegistered) {
			ui.registerInput();
			cui.registerInput();
		}

		// Update preview when choosing a color
		if (Popup.show) hwin.redraws = 1;

		if (dropPath != "") {
			Assets.importAsset(canvas, dropPath);
			dropPath = "";
		}

		var sc = ui.SCALE();
		var timelineLabelsHeight = Std.int(30 * sc);
		var timelineFramesHeight = Std.int(40 * sc);

		// Bake and redraw if the UI scale has changed
		if (grid == null) drawGrid();
		if (timeline == null || timeline.height != timelineLabelsHeight + timelineFramesHeight) drawTimeline(timelineLabelsHeight, timelineFramesHeight);

		var g = framebuffer.g2;
		g.begin();

		g.color = 0xffffffff;
		g.drawImage(grid, coffX % 40 - 40, coffY % 40 - 40);

		// Canvas outline
		canvas.x = coffX;
		canvas.y = coffY;
		g.drawRect(canvas.x, canvas.y, scaled(canvas.width), scaled(canvas.height), 1.0);
		// Canvas resize
		g.drawRect(canvas.x + scaled(canvas.width) - 3, canvas.y + scaled(canvas.height) - 3, 6, 6, 1);

		Canvas.screenW = canvas.width;
		Canvas.screenH = canvas.height;
		Canvas.draw(cui, canvas, g);

		// Outline selected elem
		if (selectedElem != null) {
			g.color = 0xffffffff;
			// Resize rects
			var ex = scaled(Math.absx(canvas, selectedElem));
			var ey = scaled(Math.absy(canvas, selectedElem));
			var ew = scaled(selectedElem.width);
			var eh = scaled(selectedElem.height);
			// Element center
			var cx = canvas.x + ex + ew / 2;
			var cy = canvas.y + ey + eh / 2;
			g.pushRotation(selectedElem.rotation, cx, cy);

			g.drawRect(canvas.x + ex, canvas.y + ey, ew, eh);
			g.color = 0xff000000;
			g.drawRect(canvas.x + ex + 1, canvas.y + ey + 1, ew, eh);
			g.color = 0xffffffff;

			// Rotate mouse coords in opposite direction as the element
			var rotatedInput:Vector2 = Math.rotatePoint(ui.inputX, ui.inputY, cx, cy, -selectedElem.rotation);

			// Draw corner drag handles
			for (handlePosX in 0...3) {
				// 0 = Left, 0.5 = Center, 1 = Right
				var handlePosX:Float = handlePosX / 2;

				for (handlePosY in 0...3) {
					// 0 = Top, 0.5 = Center, 1 = Bottom
					var handlePosY:Float = handlePosY / 2;

					if (handlePosX == 0.5 && handlePosY == 0.5) {
						continue;
					}

					var hX = canvas.x + ex + ew * handlePosX - handleSize / 2;
					var hY = canvas.y + ey + eh * handlePosY - handleSize / 2;

					// Check if the handle is currently dragged (not necessarily hovered!)
					var dragged = false;

					if (handlePosX == 0 && dragLeft) {
						if (handlePosY == 0 && dragTop) dragged = true;
						else if (handlePosY == 0.5 && !(dragTop || dragBottom)) dragged = true;
						else if (handlePosY == 1 && dragBottom) dragged = true;
					} else if (handlePosX == 0.5 && !(dragLeft || dragRight)) {
						if (handlePosY == 0 && dragTop) dragged = true;
						else if (handlePosY == 1 && dragBottom) dragged = true;
					} else if (handlePosX == 1 && dragRight) {
						if (handlePosY == 0 && dragTop) dragged = true;
						else if (handlePosY == 0.5 && !(dragTop || dragBottom)) dragged = true;
						else if (handlePosY == 1 && dragBottom) dragged = true;
					}
					dragged = dragged && drag;


					// Hover
					if (rotatedInput.x > hX && rotatedInput.x < hX + handleSize || dragged) {
						if (rotatedInput.y > hY && rotatedInput.y < hY + handleSize || dragged) {
							g.color = 0xff205d9c;
							g.fillRect(hX, hY, handleSize, handleSize);
							g.color = 0xffffffff;
						}
					}

					g.drawRect(hX, hY, handleSize, handleSize);
				}
			}

			// Draw rotation handle
			g.drawLine(cx, canvas.y + ey, cx, canvas.y + ey - handleSize * 2);

			var rotHandleCenter = new Vector2(cx, canvas.y + ey - handleSize * 2);
			if (rotatedInput.sub(rotHandleCenter).length <= handleSize / 2 || rotate) {
				g.color = 0xff205d9c;
				g.fillCircle(rotHandleCenter.x, rotHandleCenter.y, handleSize / 2);
				g.color = 0xffffffff;
			}
			g.drawCircle(rotHandleCenter.x, rotHandleCenter.y, handleSize / 2);

			g.popTransformation();
		}

		if (currentOperation != "") {
			g.fontSize = Std.int(14 * ui.SCALE());
			g.color = 0xffaaaaaa;
			g.drawString(currentOperation, toolbarw, kha.System.windowHeight() - timeline.height - g.fontSize);
		}

		// Timeline
		var showTimeline = true;
		if (showTimeline) {
			g.color = 0xffffffff;
			var ty = kha.System.windowHeight() - timeline.height;
			g.drawImage(timeline, toolbarw, ty);

			g.color = 0xff205d9c;
			g.fillRect(toolbarw + selectedFrame * 11 * sc, ty + timelineLabelsHeight, 10 * sc, timelineFramesHeight);

			// Show selected frame number
			g.font = kha.Assets.fonts.font_default;
			g.fontSize = Std.int(16 * sc);

			var frameIndicatorMargin = 4 * sc;
			var frameIndicatorPadding = 4 * sc;
			var frameIndicatorWidth = 30 * sc;
			var frameIndicatorHeight = timelineLabelsHeight - frameIndicatorMargin * 2;
			var frameTextWidth = kha.Assets.fonts.font_default.width(g.fontSize, "" + selectedFrame);

			// Scale the indicator if the contained text is too long
			if (frameTextWidth > frameIndicatorWidth + frameIndicatorPadding) {
				frameIndicatorWidth = frameTextWidth + frameIndicatorPadding;
			}

			g.fillRect(toolbarw + selectedFrame * 11 * sc + 5 * sc - frameIndicatorWidth / 2, ty + frameIndicatorMargin, frameIndicatorWidth, frameIndicatorHeight);
			g.color = 0xffffffff;
			g.drawString("" + selectedFrame, toolbarw + selectedFrame * 11 * sc + 5 * sc - frameTextWidth / 2, ty + timelineLabelsHeight / 2 - g.fontSize / 2);
		}

		g.end();

		ui.begin(g);

		UIToolBar.renderToolbar(ui, cui, canvas, toolbarw);

		if (ui.window(Id.handle(), toolbarw, 0, kha.System.windowWidth() - uiw - toolbarw, Std.int((ui.t.ELEMENT_H + 2) * ui.SCALE()))) {
			ui.tab(Id.handle(), canvas.name);
		}

		UIProperties.renderProperties(ui, hwin, uiw, canvas);

		ui.end();

		if (ui.changed && !ui.inputDown) {
			drawGrid();
		}

		g.begin(false);

		if (dragAsset != null) {
			var w = std.Math.min(128, Assets.getImage(dragAsset).width);
			var ratio = w / Assets.getImage(dragAsset).width;
			var h = Assets.getImage(dragAsset).height * ratio;
			g.drawScaledImage(Assets.getImage(dragAsset), ui.inputX, ui.inputY, w, h);
		}

		g.end();

		if (lastW > 0 && (lastW != kha.System.windowWidth() || lastH != kha.System.windowHeight())) {
			resize();
		}
		else if (lastCanvasW > 0 && (lastCanvasW != canvas.width || lastCanvasH != canvas.height)) {
			resize();
		}
		lastW = kha.System.windowWidth();
		lastH = kha.System.windowHeight();
		lastCanvasW = canvas.width;
		lastCanvasH = canvas.height;

		if (showFiles) renderFiles(g);
		if (Popup.show) Popup.render(g);
	}

	function acceptDrag(index:Int) {
		var elem = CanvasTools.makeElem(cui, canvas, ElementType.Image);
		elem.asset = assetNames[index + 1]; // assetNames[0] == ""
		elem.x = ui.inputX - canvas.x;
		elem.y = ui.inputY - canvas.y;
		elem.width = Assets.getImage(canvas.assets[index]).width;
		elem.height = Assets.getImage(canvas.assets[index]).height;
		selectedElem = elem;
	}

	public function update() {

		// Drag from assets panel
		if (ui.inputReleased && dragAsset != null) {
			if (ui.inputX < kha.System.windowWidth() - uiw) {
				var index = 0;
				for (i in 0...canvas.assets.length) if (canvas.assets[i] == dragAsset) { index = i; break; }
				acceptDrag(index);
			}
			dragAsset = null;
		}
		if (dragAsset != null) return;

		updateCanvas();

		// Select frame
		if (timeline != null) {
			var ty = kha.System.windowHeight() - timeline.height;
			if (ui.inputDown && ui.inputY > ty && ui.inputX < kha.System.windowWidth() - uiw && ui.inputX > toolbarw) {
				selectedFrame = Std.int((ui.inputX - toolbarw) / 11 / ui.SCALE());
			}
		}

		if (selectedElem != null) {
			var elem = selectedElem;
			var ex = scaled(Math.absx(canvas, elem));
			var ey = scaled(Math.absy(canvas, elem));
			var ew = scaled(elem.width);
			var eh = scaled(elem.height);
			var rotatedInput:Vector2 = Math.rotatePoint(ui.inputX, ui.inputY, canvas.x + ex + ew / 2, canvas.y + ey + eh / 2, -elem.rotation);

			if (ui.inputStarted && ui.inputDown) {
				// Drag selected element
				if (Math.hitbox(ui, canvas.x + ex - handleSize / 2, canvas.y + ey - handleSize / 2, ew + handleSize, eh + handleSize, selectedElem.rotation)) {
					drag = true;
					// Resize
					dragLeft = dragRight = dragTop = dragBottom = false;
					if (rotatedInput.x > canvas.x + ex + ew - handleSize) dragRight = true;
					else if (rotatedInput.x < canvas.x + ex + handleSize) dragLeft = true;
					if (rotatedInput.y > canvas.y + ey + eh - handleSize) dragBottom = true;
					else if (rotatedInput.y < canvas.y + ey + handleSize) dragTop = true;

					startElementManipulation(true);

				} else {
					var rotHandleCenter = new Vector2(canvas.x + ex + ew / 2, canvas.y + ey - handleSize * 2);
					var inputPos = rotatedInput.sub(rotHandleCenter);

					// Rotate selected element
					if (inputPos.length <= handleSize) {
						rotate = true;
						startElementManipulation(true);
					}
				}
			}

			if (isManipulating) {
				hwin.redraws = 2;

				// Confirm
				if ((transformStartedMouse && ui.inputReleased) || (!transformStartedMouse && ui.inputStarted)) {
					endElementManipulation();

				// Reset
				} else if ((ui.isKeyPressed && ui.isEscapeDown) || ui.inputStartedR) {
					endElementManipulation(true);

				} else if (drag) {
					var transformDelta = new Vector2(ui.inputX, ui.inputY).sub(transformInitInput);

					if (!transformStartedMouse) {
						if (ui.isKeyPressed && ui.key == KeyCode.X) {
							elem.width = Std.int(transformInitSize.x);
							elem.height = Std.int(transformInitSize.y);
							dragRight = true;
							dragBottom = !dragBottom;
						}
						if (ui.isKeyPressed && ui.key == KeyCode.Y) {
							elem.width = Std.int(transformInitSize.x);
							elem.height = Std.int(transformInitSize.y);
							dragBottom = true;
							dragRight = !dragRight;
						}
					}

					if (dragRight) {
						transformDelta.x = Math.calculateTransformDelta(ui, gridSnapPos, gridUseRelative, gridSize, transformDelta.x, transformInitPos.x + transformInitSize.x);
						elem.width = Std.int(transformInitSize.x + transformDelta.x);
					} else if (dragLeft) {
						transformDelta.x = Math.calculateTransformDelta(ui, gridSnapPos, gridUseRelative, gridSize, transformDelta.x, transformInitPos.x);
						elem.x = transformInitPos.x + transformDelta.x;
						elem.width = Std.int(transformInitSize.x - transformDelta.x);
					}
					if (dragBottom) {
						transformDelta.y = Math.calculateTransformDelta(ui, gridSnapPos, gridUseRelative, gridSize, transformDelta.y, transformInitPos.y + transformInitSize.y);
						elem.height = Std.int(transformInitSize.y + transformDelta.y);
					}
					else if (dragTop) {
						transformDelta.y = Math.calculateTransformDelta(ui, gridSnapPos, gridUseRelative, gridSize, transformDelta.y, transformInitPos.y);
						elem.y = transformInitPos.y + transformDelta.y;
						elem.height = Std.int(transformInitSize.y - transformDelta.y);
					}

					if (elem.type != ElementType.Image) {
						if (elem.width < 1) elem.width = 1;
						if (elem.height < 1) elem.height = 1;
					}

					if (!dragLeft && !dragRight && !dragBottom && !dragTop) {
						grab = true;
						grabX = true;
						grabY = true;
						drag = false;
					} else {
						// Ensure there the delta is 0 on unused axes
						if (!dragBottom && !dragTop) transformDelta.y = 0;
						else if (!dragLeft && !dragRight) transformDelta.y = 0;

						currentOperation = ' x: ${elem.x}  y: ${elem.y}  w: ${elem.width}  h: ${elem.height}  (dx: ${transformDelta.x}  dy: ${transformDelta.y})';
					}

				} else if (grab) {
					var transformDelta = new Vector2(ui.inputX, ui.inputY).sub(transformInitInput);

					if (ui.isKeyPressed && ui.key == KeyCode.X) {
						elem.x = transformInitPos.x;
						elem.y = transformInitPos.y;
						grabX = true;
						grabY = !grabY;
					}
					if (ui.isKeyPressed && ui.key == KeyCode.Y) {
						elem.x = transformInitPos.x;
						elem.y = transformInitPos.y;
						grabY = true;
						grabX = !grabX;
					}

					if (grabX) {
						transformDelta.x = Math.calculateTransformDelta(ui, gridSnapPos, gridUseRelative, gridSize, transformDelta.x, transformInitPos.x);
						elem.x = Std.int(transformInitPos.x + transformDelta.x);
					}
					if (grabY) {
						transformDelta.y = Math.calculateTransformDelta(ui, gridSnapPos, gridUseRelative, gridSize, transformDelta.y, transformInitPos.y);
						elem.y = Std.int(transformInitPos.y + transformDelta.y);
					}

					// Ensure there the delta is 0 on unused axes
					if (!grabX) transformDelta.x = 0;
					else if (!grabY) transformDelta.y = 0;

					currentOperation = ' x: ${elem.x}  y: ${elem.y}  (dx: ${transformDelta.x}  dy: ${transformDelta.y})';

				} else if (rotate) {
					var elemCenter = new Vector2(canvas.x + ex + ew / 2, canvas.y + ey + eh / 2);
					var inputPos = new Vector2(ui.inputX, ui.inputY).sub(elemCenter);

					// inputPos.x and inputPos.y are both positive when the mouse is in the lower right
					// corner of the elements center, so the positive x axis used for the angle calculation
					// in atan2() is equal to the global negative y axis. That's why we have to invert the
					// angle and add Pi to get the correct rotation. atan2() also returns an angle in the
					// intervall (-PI, PI], so we don't have to calculate the angle % PI*2 anymore.
					var inputAngle = -std.Math.atan2(inputPos.x, inputPos.y) + std.Math.PI;

					// Ctrl toggles rotation step mode
					if ((ui.isKeyDown && ui.key == Main.prefs.keyMap.gridInvert) != useRotationSteps) {
						inputAngle = std.Math.round(inputAngle / rotationSteps) * rotationSteps;
					}

					elem.rotation = inputAngle;
					currentOperation = " Rot: " + Math.roundPrecision(Math.toDegrees(inputAngle), 2) + "deg";
				}
			}

			if (ui.isKeyPressed && !ui.isTyping) {
				if (!grab && ui.key == Main.prefs.keyMap.grabKey){startElementManipulation(); grab = true; grabX = true; grabY = true;}
				if (!drag && ui.key == Main.prefs.keyMap.sizeKey) {startElementManipulation(); drag = true; dragLeft = false; dragTop = false; dragRight = true; dragBottom = true;}
				if (!rotate && ui.key == Main.prefs.keyMap.rotateKey) {startElementManipulation(); rotate = true;}

				if (!isManipulating) {
					// Move with arrows
					if (ui.key == KeyCode.Left) gridSnapPos ? elem.x -= gridSize : elem.x--;
					if (ui.key == KeyCode.Right) gridSnapPos ? elem.x += gridSize : elem.x++;
					if (ui.key == KeyCode.Up) gridSnapPos ? elem.y -= gridSize : elem.y--;
					if (ui.key == KeyCode.Down) gridSnapPos ? elem.y += gridSize : elem.y++;

					if (ui.isBackspaceDown || ui.isDeleteDown){
						CanvasTools.removeElem(canvas, Elements.selectedElem);
		                selectedElem = null;
					}
					else if (ui.key == KeyCode.D) selectedElem = CanvasTools.duplicateElem(canvas, elem);
				}
			}
		} else {
			endElementManipulation();
		}

		if (Popup.show) Popup.update();

		updateFiles();
	}

	function startElementManipulation(?mousePressed=false) {
		if (isManipulating) endElementManipulation(true);

		transformInitInput = new Vector2(ui.inputX, ui.inputY);
		transformInitPos = new Vector2(selectedElem.x, selectedElem.y);
		transformInitSize = new Vector2(selectedElem.width, selectedElem.height);
		transformInitRot = selectedElem.rotation;
		transformStartedMouse = mousePressed;

		isManipulating = true;
	}

	function endElementManipulation(reset=false) {
		if (reset) {
			selectedElem.x = transformInitPos.x;
			selectedElem.y = transformInitPos.y;
			selectedElem.width = Std.int(transformInitSize.x);
			selectedElem.height = Std.int(transformInitSize.y);
			selectedElem.rotation = transformInitRot;
		}

		isManipulating = false;

		grab = false;
		drag = false;
		rotate = false;

		transformStartedMouse = false;
		currentOperation = "";
	}

	function updateCanvas() {
		if (showFiles || ui.inputX > kha.System.windowWidth() - uiw) return;

		// Select elem
		var selectButton = Main.prefs.keyMap.selectMouseButton;
		if (selectButton == "Left" && ui.inputStarted && ui.inputDown ||
				selectButton == "Right" && ui.inputStartedR && ui.inputDownR) {
			var i = canvas.elements.length;
			for (elem in canvas.elements) {
				var ex = scaled(Math.absx(canvas, elem));
				var ey = scaled(Math.absy(canvas, elem));
				var ew = scaled(elem.width);
				var eh = scaled(elem.height);

				if (Math.hitbox(ui, canvas.x + ex, canvas.y + ey, ew, eh, elem.rotation) &&
						selectedElem != elem) {
					selectedElem = elem;
					break;
				}
			}
		}

		if (!isManipulating) {
			// Pan canvas
			if (ui.inputDownR) {
				coffX += Std.int(ui.inputDX);
				coffY += Std.int(ui.inputDY);
			}

			// Zoom canvas
			if (ui.inputWheelDelta != 0) {
				zoom += -ui.inputWheelDelta / 10;
				if (zoom < 0.4) zoom = 0.4;
				else if (zoom > 1.0) zoom = 1.0;
				zoom = std.Math.round(zoom * 10) / 10;
				cui.ops.scaleFactor = zoom;
			}
		}

		// Canvas resize
		if (ui.inputStarted && Math.hitbox(ui, canvas.x + scaled(canvas.width) - 3, canvas.y + scaled(canvas.height) - 3, 6, 6)) {
			resizeCanvas = true;
		}
		if (ui.inputReleased && resizeCanvas) {
			resizeCanvas = false;
		}
		if (resizeCanvas) {
			canvas.width += Std.int(ui.inputDX);
			canvas.height += Std.int(ui.inputDY);
			if (canvas.width < 1) canvas.width = 1;
			if (canvas.height < 1) canvas.height = 1;
		}
	}

	function updateFiles() {
		if (!showFiles) return;

		if (ui.inputReleased) {
			var appw = kha.System.windowWidth();
			var apph = kha.System.windowHeight();
			var left = appw / 2 - modalRectW / 2;
			var right = appw / 2 + modalRectW / 2;
			var top = apph / 2 - modalRectH / 2;
			var bottom = apph / 2 + modalRectH / 2;
			if (ui.inputX < left || ui.inputX > right || ui.inputY < top + modalHeaderH || ui.inputY > bottom) {
				showFiles = false;
			}
		}
	}

	static var modalW = 625;
	static var modalH = 545;
	static var modalHeaderH = 66;
	static var modalRectW = 625; // No shadow
	static var modalRectH = 545;

	static var path = '/';
	function renderFiles(g:kha.graphics2.Graphics) {
		var appw = kha.System.windowWidth();
		var apph = kha.System.windowHeight();
		var left = appw / 2 - modalW / 2;
		var top = apph / 2 - modalH / 2;

		g.begin(false);
		g.color = 0xff202020;
		g.fillRect(left, top, modalW, modalH);
		g.end();

		var leftRect = Std.int(appw / 2 - modalRectW / 2);
		var rightRect = Std.int(appw / 2 + modalRectW / 2);
		var topRect = Std.int(apph / 2 - modalRectH / 2);
		var bottomRect = Std.int(apph / 2 + modalRectH / 2);
		topRect += modalHeaderH;

		uimodal.begin(g);
		if (uimodal.window(Id.handle(), leftRect, topRect, modalRectW, modalRectH - 100)) {
			var pathHandle = Id.handle();
			pathHandle.text = uimodal.textInput(pathHandle);
			path = uimodal.fileBrowser(pathHandle, foldersOnly);
		}
		uimodal.end(false);

		g.begin(false);

		uimodal.beginRegion(g, rightRect - 100, bottomRect - 30, 100);
		if (uimodal.button("OK")) {
			showFiles = false;
			filesDone(path);
		}
		uimodal.endRegion(false);

		uimodal.beginRegion(g, rightRect - 200, bottomRect - 30, 100);
		if (uimodal.button("Cancel")) {
			showFiles = false;
		}
		uimodal.endRegion();

		g.end();
	}

	inline function scaled(f: Float): Int { return Std.int(f * cui.SCALE()); }
}
