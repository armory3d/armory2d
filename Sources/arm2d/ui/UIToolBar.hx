package arm2d.ui;

import zui.Canvas.TCanvas;
import zui.Canvas.ElementType;
import zui.Id;
import zui.Zui;

import arm2d.tools.CanvasTools;

class UIToolBar {

	public static function renderToolbar(ui:Zui, cui:Zui, canvas: TCanvas, width:Int) {

		if (ui.window(Id.handle(), 0, 0, width, kha.System.windowHeight())) {
			ui.text("Add Elements:");

			if (ui.panel(Id.handle({selected: true}), "Basic")) {
				ui.indent();

				if (ui.button("Empty")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.Empty);
				}
				if (ui.isHovered) ui.tooltip("Creates empty element");
				if (ui.button("Text")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.Text);
				}
				if (ui.isHovered) ui.tooltip("Create text element");
				if (ui.button("Image")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.Image);
				}
				if (ui.isHovered) ui.tooltip("Creates image element");

				ui.unindent();
			}

			// ui.button("VLayout");
			// ui.button("HLayout");
			if (ui.panel(Id.handle({selected: true}), "Buttons")){
				ui.indent();

				if (ui.button("Button")) {
				Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.Button);
				}
				if (ui.isHovered) ui.tooltip("Creates button element");
				if (ui.button("Check")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.Check);
				}
				if (ui.isHovered) ui.tooltip("Creates check box element");
				if (ui.button("Radio")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.Radio);
				}
				if (ui.isHovered) ui.tooltip("Creates inline-radio element");

				ui.unindent();
			}

			if (ui.panel(Id.handle({selected: true}), "Inputs")){
				ui.indent();

				if (ui.button("Text Input")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.TextInput);
				}
				if (ui.isHovered) ui.tooltip("Creates text input element");
				if (ui.button("Key Input")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.KeyInput);
				}
				if (ui.isHovered) ui.tooltip("Creates key input element");
				if (ui.button("Combo Box")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.Combo);
				}
				if (ui.isHovered) ui.tooltip("Creates combo box element");
				if (ui.button("Slider")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.Slider);
				}
				if (ui.isHovered) ui.tooltip("Creates slider element");

				ui.unindent();
			}

			if (ui.panel(Id.handle({selected: true}), "Shapes")){
				ui.indent();
				if (ui.button("Rect")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.Rectangle);
				}
				if (ui.isHovered) ui.tooltip("Creates rectangle shaped element");
				if (ui.button("Fill Rect")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.FRectangle);
				}
				if (ui.isHovered) ui.tooltip("Creates filled rectangle shaped element");
				if (ui.button("Circle")){
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.Circle);
				}
				if (ui.isHovered) ui.tooltip("Creates circle shaped element");
				if (ui.button("Fill Circle")){
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.FCircle);
				}
				if (ui.isHovered) ui.tooltip("Creates filled circle shaped element");
				if (ui.button("Triangle")){
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.Triangle);
				}
				if (ui.isHovered) ui.tooltip("Creates triangle shaped element");
				if (ui.button("Fill Triangle")){
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.FTriangle);
				}
				if (ui.isHovered) ui.tooltip("Creates filled triangle shaped element");

				ui.unindent();
			}

			if (ui.panel(Id.handle({selected: true}), "ProgressBars")){
				ui.indent();
				if (ui.button("RectPB")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.ProgressBar);
				}
				if (ui.isHovered) ui.tooltip("Creates rectangular progress bar");
				if (ui.button("CircularPB")) {
					Editor.selectedElem = CanvasTools.makeElem(cui, canvas, ElementType.CProgressBar);
				}
				if (ui.isHovered) ui.tooltip("Creates circular progress bar");
				ui.unindent();
			}
		}
	}
}
