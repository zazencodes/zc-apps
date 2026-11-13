import AppKit
import Carbon.HIToolbox
import Testing
@testable import PrettyDrawKit

private func mark(_ x: CGFloat) -> Mark {
    let pen = Pen(width: 11, style: .clean)
    return Mark(display: 1, color: Palette.classic.colors[0], kind: .rectangle(CGRect(x: x, y: 0, width: 10, height: 10), pen: pen))
}

@Suite struct DrawingTests {
    @Test func undoAndRedoStepThroughChanges() {
        var drawing = Drawing()
        let first = mark(0), second = mark(20)
        drawing.add(first)
        drawing.add(second)
        #expect(drawing.marks == [first, second])
        drawing.undo()
        #expect(drawing.marks == [first])
        drawing.undo()
        #expect(drawing.marks.isEmpty)
        let undidNothing = drawing.undo()
        #expect(!undidNothing)
        drawing.redo()
        drawing.redo()
        #expect(drawing.marks == [first, second])
        let redidNothing = drawing.redo()
        #expect(!redidNothing)
    }

    @Test func clearIsOneUndoableStep() {
        var drawing = Drawing()
        drawing.add(mark(0))
        drawing.add(mark(20))
        drawing.clear()
        #expect(drawing.marks.isEmpty)
        drawing.undo()
        #expect(drawing.marks.count == 2)
    }

    // Ending a session clears its drawing, and the next session starts from there.
    @Test func undoBringsBackADrawingClearedAtTheEndOfASession() {
        var drawing = Drawing()
        let first = mark(0), second = mark(20)
        drawing.add(first)
        drawing.add(second)
        drawing.clear()
        drawing.undo()
        #expect(drawing.marks == [first, second])
        drawing.undo()
        #expect(drawing.marks == [first])
    }

    @Test func clearingNothingLeavesNoUndoStep() {
        var drawing = Drawing()
        drawing.clear()
        #expect(!drawing.canUndo)
    }

    @Test func aNewChangeDropsTheRedoHistory() {
        var drawing = Drawing()
        drawing.add(mark(0))
        drawing.undo()
        drawing.add(mark(40))
        #expect(!drawing.canRedo)
    }

    @Test func updatingTextIsUndoable() {
        var drawing = Drawing()
        let content = TextContent(string: "hi", origin: .zero, fontName: "Menlo-Bold", size: 40)
        var text = Mark(display: 1, color: Palette.classic.colors[0], kind: .text(content))
        drawing.add(text)
        text.kind = .text(TextContent(string: "hello", origin: .zero, fontName: "Menlo-Bold", size: 40))
        drawing.update(text)
        #expect(drawing.mark(text.id)?.text?.string == "hello")
        drawing.undo()
        #expect(drawing.mark(text.id)?.text?.string == "hi")
    }

    @Test func updatingWithNoChangeLeavesNoUndoStep() {
        var drawing = Drawing()
        let rectangle = mark(0)
        drawing.add(rectangle)
        drawing.update(rectangle)
        drawing.undo()
        #expect(drawing.marks.isEmpty)
    }
}

@Suite struct KeyCommandTests {
    private func command(_ characters: String, _ keyCode: Int = 0, _ modifiers: KeyCommand.Modifiers = []) -> KeyCommand? {
        KeyCommand(keyCode: keyCode, characters: characters, modifiers: modifiers)
    }

    @Test func presentifyKeysMap() {
        #expect(command("1") == .color(0))
        #expect(command("5") == .color(4))
        #expect(command("f") == .tool(.freehand))
        #expect(command("a") == .tool(.arrow))
        #expect(command("r") == .tool(.rectangle))
        #expect(command("t") == .tool(.text))
        #expect(command("[") == .smaller)
        #expect(command("]") == .larger)
        #expect(command("/") == .toggleShortcuts)
        #expect(command("", kVK_Delete) == .clear)
        #expect(command("z", kVK_ANSI_Z, .command) == .undo)
        #expect(command("z", kVK_ANSI_Z, [.command, .shift]) == .redo)
        #expect(command("", kVK_Escape) == .cancel)
    }

    @Test func droppedPresentifyKeysDoNothing() {
        // Circle, highlighter, random colors, touch drawing and whiteboard are out of scope.
        for key in ["c", "h", "6", "d", "w"] {
            #expect(command(key) == nil)
        }
    }

    @Test func modifiedLettersAreNotTools() {
        #expect(command("r", kVK_ANSI_R, .command) == nil)
        #expect(command("a", kVK_ANSI_A, .shift) == nil)
    }
}

@Suite struct SizeStepTests {
    @Test func stepsMoveAwayFromTheDefaultBothWays() {
        let width = SizeSteps.defaultLineWidth
        #expect(SizeSteps.step(width, in: SizeSteps.lineWidths, up: true) == 12)
        #expect(SizeSteps.step(width, in: SizeSteps.lineWidths, up: false) == 10)
        #expect(SizeSteps.lineWidths.contains(width))
        #expect(SizeSteps.textSizes.contains(SizeSteps.defaultTextSize))
    }

    @Test func stepsStopAtTheEnds() {
        #expect(SizeSteps.step(32, in: SizeSteps.lineWidths, up: true) == 32)
        #expect(SizeSteps.step(2, in: SizeSteps.lineWidths, up: false) == 2)
    }

    @Test func offStepValuesSnapToTheNextStep() {
        #expect(SizeSteps.step(11.5, in: SizeSteps.lineWidths, up: true) == 12)
        #expect(SizeSteps.step(11.5, in: SizeSteps.lineWidths, up: false) == 11)
    }
}

@Suite struct PreferencesTests {
    private func freshDefaults() -> UserDefaults {
        let name = "PrettyDrawTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func newInstallsUseTheBuiltInDefaults() {
        let preferences = Preferences(defaults: freshDefaults())
        #expect(preferences.palette == .classic)
        #expect(preferences.lineWidth == 11)
        #expect(preferences.textSize == 40)
        #expect(preferences.hotKey == .standard)
        #expect(preferences.hotKey.displayString == "⌃B")
        #expect(preferences.toolbarPosition == nil)
        #expect(preferences.customFonts.isEmpty)
        #expect(preferences.fonts == Preferences.standardFonts)
        #expect(preferences.fontName == Preferences.standardFonts[0])
        #expect(preferences.lineStyles == .standard)
        #expect(preferences.closesLoops)
        #expect(preferences.showsToolbar)
        #expect(Tool.allCases.filter { $0 != .text }.allSatisfy { preferences.lineStyles[$0] == .clean })
    }

    @Test func settingsSurviveARelaunch() {
        let defaults = freshDefaults()
        let preferences = Preferences(defaults: defaults)
        let custom = preferences.duplicate(.pastel)
        preferences.tool = .arrow
        preferences.colorIndex = 3
        preferences.lineWidth = 14
        preferences.lineStyles[.rectangle] = .handDrawn
        preferences.closesLoops = false
        preferences.showsToolbar = false
        preferences.textSize = 56
        preferences.addCustomFont("Didot-Bold")
        preferences.fontName = "Didot-Bold"
        preferences.toolbarPosition = CGPoint(x: 0.3, y: 0.1)

        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.tool == .arrow)
        #expect(reloaded.colorIndex == 3)
        #expect(reloaded.lineWidth == 14)
        #expect(reloaded.lineStyles == LineStyles(freehand: .clean, arrow: .clean, rectangle: .handDrawn))
        #expect(reloaded.pen(for: .rectangle) == Pen(width: 14, style: .handDrawn))
        #expect(!reloaded.closesLoops)
        #expect(!reloaded.showsToolbar)
        #expect(reloaded.textSize == 56)
        #expect(reloaded.customFonts == ["Didot-Bold"])
        #expect(reloaded.fontName == "Didot-Bold")
        #expect(reloaded.palette == custom)
        #expect(reloaded.toolbarPosition == CGPoint(x: 0.3, y: 0.1))
    }

    @Test func duplicatingNamesTheCopyUniquely() {
        let preferences = Preferences(defaults: freshDefaults())
        #expect(preferences.duplicate(.classic).name == "Classic Copy")
        #expect(preferences.duplicate(.classic).name == "Classic Copy 2")
    }

    @Test func deletingTheSelectedPaletteSelectsClassic() {
        let preferences = Preferences(defaults: freshDefaults())
        let custom = preferences.duplicate(.neon)
        preferences.delete(custom)
        #expect(preferences.palette == .classic)
        #expect(preferences.customPalettes.isEmpty)
    }

    @Test func customFontsComeBeforeTheStandardOnes() {
        let preferences = Preferences(defaults: freshDefaults())
        preferences.addCustomFont("Didot-Bold")
        preferences.addCustomFont("MarkerFelt-Wide")
        #expect(preferences.fonts == ["Didot-Bold", "MarkerFelt-Wide"] + Preferences.standardFonts)
    }

    @Test func removingTheCustomFontInUseSelectsTheFirstStandardFont() {
        let preferences = Preferences(defaults: freshDefaults())
        preferences.addCustomFont("Didot-Bold")
        preferences.fontName = "Didot-Bold"
        preferences.removeCustomFont("Didot-Bold")
        #expect(preferences.customFonts.isEmpty)
        #expect(preferences.fontName == Preferences.standardFonts[0])
    }

    @Test func eachLineToolKeepsItsOwnStyle() {
        let preferences = Preferences(defaults: freshDefaults())
        preferences.lineStyles[.freehand] = .handDrawn
        #expect(preferences.pen(for: .freehand).style == .handDrawn)
        #expect(preferences.pen(for: .arrow).style == .clean)
        #expect(preferences.pen(for: .rectangle).style == .clean)
        preferences.lineStyles[.arrow] = .handDrawn
        preferences.lineStyles[.freehand] = .clean
        #expect(preferences.lineStyles == LineStyles(freehand: .clean, arrow: .handDrawn, rectangle: .clean))
    }

    @Test func sizeKeysChangeTheTextSizeForTheTextTool() {
        let preferences = Preferences(defaults: freshDefaults())
        preferences.stepSize(for: .text, up: true)
        #expect(preferences.textSize == 48)
        #expect(preferences.lineWidth == 11)
        preferences.stepSize(for: .rectangle, up: false)
        #expect(preferences.lineWidth == 10)
    }

    @Test func paletteColorsRoundTripThroughDisplayP3() {
        let lavender = PaletteColor(red: 0.828782022, green: 0.7046652436, blue: 0.9787839055)
        #expect(PaletteColor(lavender.nsColor) == lavender)
    }
}
