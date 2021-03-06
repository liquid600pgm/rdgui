import unicode

import rapid/gfx/text
import rapid/gfx
import rdgui/control
import rdgui/event

type
  TextBox* = ref object of Control
    fWidth, fHeight: float
    fText: seq[Rune]
    textString: string
    caret: int
    scroll: float
    blinkTimer: float
    focused*: bool
    next*: TextBox
    font*: RFont
    fontSize*: int
    placeholder*: string
    onInput*: proc ()
    onAccept*: proc ()

method width*(tb: TextBox): float = tb.fWidth
method height*(tb: TextBox): float = tb.fHeight
proc `width=`*(tb: TextBox, width: float) =
  tb.fWidth = width
proc `height=`*(tb: TextBox, height: float) =
  tb.fHeight = height

proc text*(tb: TextBox): string = tb.textString
proc `text=`*(tb: TextBox, text: string) =
  tb.fText = text.toRunes
  tb.caret = clamp(tb.caret, 0, tb.fText.len)
  tb.textString = text

proc resetBlink(tb: TextBox) =
  tb.blinkTimer = time()

proc canBackspace(tb: TextBox): bool = tb.caret in 1..tb.fText.len
proc canDelete(tb: TextBox): bool = tb.caret in 0..<tb.fText.len

proc insert(tb: TextBox, r: Rune) =
  tb.fText.insert(r, tb.caret)
  inc(tb.caret)

proc delete(tb: TextBox) =
  if tb.canDelete:
    tb.fText.delete(tb.caret)

proc backspace(tb: TextBox) =
  if tb.canBackspace:
    dec(tb.caret)
    tb.fText.delete(tb.caret)

proc left(tb: TextBox) =
  if tb.canBackspace:
    dec(tb.caret)

proc right(tb: TextBox) =
  if tb.canDelete:
    inc(tb.caret)

proc xScroll*(tb: TextBox): float = tb.scroll

proc caretPos(tb: TextBox): float =
  if tb.fText.len > 0:
    tb.font.widthOf(tb.fText[0..<tb.caret]) + tb.xScroll
  else: 0

proc scrollToCaret(tb: TextBox) =
  if tb.caretPos < 0:
    tb.scroll -= tb.caretPos
  elif tb.caretPos > tb.width:
    tb.scroll -= tb.caretPos - tb.width

method onEvent*(tb: TextBox, ev: UIEvent) =
  if ev.kind == evMousePress:
    tb.focused = tb.hasMouse
    if tb.focused:
      tb.resetBlink()
  elif tb.focused and ev.kind in {evKeyChar, evKeyPress, evKeyRepeat}:
    var used = true
    case ev.kind
    of evKeyChar: tb.insert(ev.rune)
    of evKeyPress, evKeyRepeat:
      case ev.key
      of keyBackspace: tb.backspace()
      of keyDelete: tb.delete()
      of keyLeft: tb.left()
      of keyRight: tb.right()
      of keyEnter:
        if tb.onAccept != nil: tb.onAccept()
      of keyTab:
        if tb.next != nil:
          tb.focused = false
          tb.next.focused = true
      else: used = false
    else: discard
    tb.textString = $tb.fText
    tb.resetBlink()
    tb.scrollToCaret()
    if used: ev.consume()
    if tb.onInput != nil: tb.onInput()
  elif ev.kind == evMouseEnter:
    tb.rwin.cursor = ibeam
  elif ev.kind == evMouseLeave:
    tb.rwin.cursor = arrow

proc drawEditor*(tb: TextBox, ctx: RGfxContext) =
  let oldFontHeight = tb.font.height
  tb.font.height = tb.fontSize

  let pos = tb.screenPos
  ctx.scissor(pos.x, pos.y, tb.width, tb.height):
    ctx.text(tb.font, tb.xScroll, tb.height / 2 - 2, tb.fText,
             vAlign = taMiddle)

  if tb.focused and floorMod(time() - tb.blinkTimer, 1.0) < 0.5:
    ctx.begin()
    var x = tb.caretPos
    ctx.line((x, 0.0), (x, tb.height))
    ctx.draw(prLineShape)

  tb.font.height = oldFontHeight

renderer(TextBox, Rd, tb):
  ctx.color = gray(255)
  ctx.begin()
  ctx.rect(-2, -2, tb.width + 4, tb.height + 4)
  ctx.draw()
  ctx.color = gray(127)
  ctx.begin()
  ctx.lrect(-2, -2, tb.width + 4, tb.height + 4)
  ctx.draw(prLineShape)
  ctx.color = gray(0)
  tb.drawEditor(ctx)
  ctx.color = gray(255)

proc initTextBox*(tb: TextBox, x, y, width, height: float, font: RFont,
                  placeholder, text = "", fontSize = 14, prev: TextBox = nil,
                  rend = TextBoxRd) =
  tb.initControl(x, y, rend)
  tb.width = width
  tb.height = height
  tb.font = font
  tb.text = text
  tb.placeholder = placeholder
  tb.fontSize = fontSize
  if prev != nil:
    prev.next = tb

proc newTextBox*(x, y, width, height: float, font: RFont,
                 placeholder, text = "",
                 fontSize = 14, prev: TextBox = nil,
                 rend = TextBoxRd): TextBox =
  result = TextBox()
  result.initTextBox(x, y, width, height, font, placeholder, text, fontSize,
                     prev, rend)
