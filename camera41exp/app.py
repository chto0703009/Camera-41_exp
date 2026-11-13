# SPDX-License-Identifier: GPL-3.0-or-later
"""Native macOS interface for Camera-41_exp."""

import argparse
from dataclasses import asdict
from datetime import datetime
from io import BytesIO
import json
import math
import re
from pathlib import Path
import sys
from threading import Thread

import AppKit as A
from Foundation import NSData, NSObject, NSMakeRect
import numpy as np
import objc
from PIL import Image, ImageDraw
from PyObjCTools import AppHelper

from camera41exp.exposure import (
    AreaReview, CHANNELS, MIN_SIGNAL, PASS_MARGIN, RAW_EXTENSIONS, ROOT, analyse, automatic_area, decode,
    is_raw, raw_probe,
)

APP_NAME = "Camera-41_exp"

VERSION = (ROOT / "VERSION").read_text().strip()
PREFERENCES = A.NSUserDefaults.standardUserDefaults()
LOG_PATH = (Path.home() / "Library/Logs/Camera-41_exp/camera41_exp.jsonl"
            if getattr(sys, "frozen", False) else ROOT / "logs/camera41_exp.jsonl")
HANDOFF = (
    "Capture the current film’s FB+F and two independent dark RAWs at the chosen "
    "shutter time, with the same camera, ISO and aperture. Load them in PRE tab 7 "
    "to measure noise and S/N."
)
SELECTION_MESSAGES = {
    "NO_PASSING_EXPOSURE": "No shutter time passed in every replicate.",
    "PROVISIONAL_ADD_HIGHER_EXPOSURE": "Provisional. Add a longer exposure to establish the upper bracket.",
    "PROVISIONAL_REFINE_BRACKET": "Provisional. Measure a time between the passing and upper bracket.",
    "HIGHEST_BRACKETED_PASS_EXPOSURE_ONLY": "Highest passing time within a bracket of one third EV.",
    "REVIEW_LINEAR_RESPONSE_BEFORE_USING_CANDIDATE": "Review the linear response before using this time.",
    "REVIEW_INCONSISTENT_SERIES": (
        "The series is inconsistent: headroom should shrink and signal grow with longer shutter times. "
        "Check that the light, sample and camera settings were unchanged, then repeat the series."
    ),
}
WELCOME_TITLE = "Find the shutter time for digitising film negatives"
WELCOME = (
    "Camera-41_exp compares RAW captures of clear film base + fog (FB+F) from a VALOI setup. "
    "It shows which shutter time gives a strong signal with room before a sensor channel clips. "
    "Your RAW files are never changed.\n"
    "What to do\n"
    "1.  Photograph the empty film base at several shutter times in 1/3 EV steps. "
    "Keep the camera, ISO, aperture and light the same, and save the captures as RAW files.\n"
    "2.  Choose Add FB+F RAWs… and select those RAW files. JPEG, TIFF and other exports cannot be used.\n"
    "3.  Describe the Light setup and the Film base + fog sample, "
    "then tick Same FB+F sample in all RAWs.\n"
    "4.  Optional: choose Preview selected to inspect the yellow measurement area. "
    "Drag on the image to move it.\n"
    "5.  Choose Analyse RAW images, then read Results and Exposure comparison.\n"
    "6.  Pick a measured passing time in the list beside the Analyse button "
    "and use it for the film’s captures."
)
NO_RESULTS = "No results yet. Add FB+F RAWs, fill in the fields above and choose Analyse RAW images."
NO_CHARTS = "The signal and headroom charts appear here after Analyse RAW images."
log_enabled = True


def app_icon():
    image = A.NSImage.alloc().initWithContentsOfFile_(str(ROOT / "resources/Camera41Exp.icns"))
    return image or A.NSApplication.sharedApplication().applicationIconImage()


def raw_types():
    """Content types for the RAW extensions, without a PyObjC wrapper dependency."""
    A.NSBundle.bundleWithPath_("/System/Library/Frameworks/UniformTypeIdentifiers.framework").load()
    create = objc.lookUpClass("UTType").typeWithFilenameExtension_
    return [kind for kind in map(create, RAW_EXTENSIONS) if kind is not None]


def build_menu(app):
    main = A.NSMenu.alloc().init()

    def submenu(title, *entries):
        menu = A.NSMenu.alloc().initWithTitle_(title)
        for entry in entries:
            if entry is None:
                menu.addItem_(A.NSMenuItem.separatorItem())
            else:
                menu.addItemWithTitle_action_keyEquivalent_(*entry)
        main.addItemWithTitle_action_keyEquivalent_(title, None, "").setSubmenu_(menu)
        return menu

    submenu(APP_NAME, (f"About {APP_NAME}", "orderFrontStandardAboutPanel:", ""), None,
            (f"Hide {APP_NAME}", "hide:", "h"), None, (f"Quit {APP_NAME}", "terminate:", "q"))
    submenu("Edit", ("Undo", "undo:", "z"), ("Redo", "redo:", "Z"), None, ("Cut", "cut:", "x"),
            ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a"))
    app.setWindowsMenu_(submenu("Window", ("Minimize", "performMiniaturize:", "m"),
                                ("Close", "performClose:", "w")))
    app.setMainMenu_(main)


def log(event, **details):
    if not log_enabled:
        return
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with LOG_PATH.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps({"Timestamp": datetime.now().astimezone().isoformat(),
                                     "Event": event, **details}, ensure_ascii=False) + "\n")
    except OSError as error:
        print(f"Camera-41_exp log: {error}", file=sys.stderr)


def native_image(image):
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    content = buffer.getvalue()
    return A.NSImage.alloc().initWithData_(NSData.dataWithBytes_length_(content, len(content)))


def preview_image(capture):
    source = capture.linear
    h, w = (size - size % 2 for size in source.shape)
    reduced = sum(source[r:h:8, c:w:8] for r, c in ((0, 0), (0, 1), (1, 0), (1, 1))) / 4
    image = Image.fromarray(np.uint8(np.sqrt(np.clip(reduced, 0, 1)) * 255))
    return image.resize((900, max(1, round(900 * h / w))))


# Nominal camera display values for successive 1/3 EV positions.
SHUTTER_DENOMINATORS = (
    12500, 10000, 8000, 6400, 5000, 4000, 3200, 2500, 2000, 1600,
    1250, 1000, 800, 640, 500, 400, 320, 250, 200, 160, 125, 100,
    80, 60, 50, 40, 30, 25, 20, 15, 13, 10, 8, 6, 5, 4,
)
SHUTTER_SECONDS = (
    .3, .4, .5, .6, .8, 1, 1.3, 1.6, 2, 2.5, 3.2, 4, 5, 6, 8, 10,
    13, 15, 20, 25, 30,
)
SHUTTER_SCALE = (
    [(1 / n, f"1/{n}") for n in SHUTTER_DENOMINATORS]
    + [(t, f"{t:g}") for t in SHUTTER_SECONDS]
)


def shutter_axis(seconds):
    nominal = np.log2([t for t, _ in SHUTTER_SCALE])
    positions = []
    for time in seconds:
        log_time = math.log2(time)
        nearest = int(np.argmin(np.abs(nominal - log_time)))
        if abs(log_time - nominal[nearest]) <= .12:
            positions.append(float(nearest))
        elif log_time < nominal[0]:
            positions.append(3 * (log_time - nominal[0]))
        elif log_time > nominal[-1]:
            positions.append(len(nominal) - 1 + 3 * (log_time - nominal[-1]))
        else:
            positions.append(float(np.interp(log_time, nominal, np.arange(len(nominal)))))
    low, high = math.floor(min(positions)), math.ceil(max(positions))
    if low == high:
        low, high = low - 1, high + 1
    ticks = []
    for index in range(low, high + 1):
        if index < 0:
            label = f"1/{round(SHUTTER_DENOMINATORS[0] * 2**(-index/3))}"
        elif index >= len(SHUTTER_SCALE):
            label = f"{SHUTTER_SECONDS[-1] * 2**((index-len(SHUTTER_SCALE)+1)/3):.3g}"
        else:
            label = SHUTTER_SCALE[index][1]
        ticks.append((index, label))
    return positions, ticks


def comparison_image(rows):
    image = Image.new("RGB", (900, 570), "white")
    draw = ImageDraw.Draw(image)
    positions, ticks = shutter_axis([row.seconds for row in rows])
    low, high = ticks[0][0], ticks[-1][0]
    colors = ("#b52235", "#19783c", "#557814", "#275aaa")
    for name, title, offset in (("signal", "Median RAW signal above black (sensor codes)", 0),
                                ("margin", "Headroom before clipping (EV)", 285)):
        values = np.array([getattr(row, name) for row in rows])
        if name == "signal":
            minimum, maximum = 0, max(1, float(values.max()))
        else:
            minimum = min(0, float(values.min()))
            maximum = max(PASS_MARGIN, float(values.max()))
        raw_step = (maximum - minimum) / 5
        magnitude = 10 ** math.floor(math.log10(raw_step))
        step = next(multiplier * magnitude for multiplier in (1, 2, 2.5, 5, 10)
                    if multiplier * magnitude >= raw_step)
        lower_tick, upper_tick = math.floor(minimum / step), math.ceil(maximum / step)
        minimum, maximum = lower_tick * step, upper_tick * step
        x0, y0, x1, y1 = 90, offset + 58, 865, offset + 226
        draw.text((x0, offset + 8), title, fill="black", font_size=17)
        subtitle = ("Higher values mean more signal from the film base." if name == "signal"
                    else "Higher values mean more room before clipping. At 0 EV the signal reaches the limit.")
        draw.text((x0, offset + 32), subtitle, fill="#444444", font_size=13)
        for i, color in enumerate(colors):
            draw.text((x1 - 175 + 43*i, offset + 13), CHANNELS[i], fill=color, font_size=14)

        def ordinate(value):
            return y1 - (value - minimum) / (maximum - minimum) * (y1 - y0)

        for index in range(lower_tick, upper_tick + 1):
            value = index * step
            y = ordinate(value)
            draw.line((x0, y, x1, y), fill="#d1d5db")
            label = f"{value:,.8f}".rstrip("0").rstrip(".")
            draw.text((x0-8, y), label, anchor="rm", fill="black", font_size=13)
        def abscissa(position):
            return x0 + (x1-x0) * (position-low) / (high-low)

        label_every = max(1, math.ceil((high-low) / 12))
        for tick, label in ticks:
            x = abscissa(tick)
            draw.line((x, y0, x, y1), fill="#e3e6e9")
            draw.line((x, y1, x, y1+4), fill="#606060")
            if (tick-low) % label_every == 0:
                draw.text((x, y1+8), label, anchor="mt", fill="black", font_size=13)
        draw.text(((x0+x1)//2, y1+32), "Shutter speed (s) · 1/3 EV steps",
                  anchor="mt", fill="black", font_size=14)
        if name == "margin":
            y = ordinate(PASS_MARGIN)
            for x in range(x0, x1, 14):
                draw.line((x, y, min(x+7, x1), y), fill="#505050")
            label = "Minimum headroom for PASS: 1/3 EV"
            # Headroom is largest at the short times, so the left end stays clear of the curves.
            left, top, right, bottom = draw.textbbox((x0+8, y-7), label, anchor="lb", font_size=13)
            draw.rectangle((left-4, top-2, right+4, bottom+2), fill="white")
            draw.text((x0+8, y-7), label, anchor="lb", fill="#333333", font_size=13)
        plotted_x = [abscissa(position) for position in positions]
        for i, color in enumerate(colors):
            points = list(zip(plotted_x, map(ordinate, values[:, i])))
            if len(points) > 1:
                draw.line(points, fill=color, width=2)
            for x, y in points:
                draw.ellipse((x-3, y-3, x+3, y+3), fill=color)
    return image


class ImagePanel(A.NSView):
    def isFlipped(self):
        return True

    def drawRect_(self, rect):
        A.NSColor.controlBackgroundColor().setFill()
        A.NSRectFill(A.NSIntersectionRect(rect, self.bounds()))
        if self.image is None:
            return
        w, h = self.image.size()
        size = self.bounds().size
        factor = min(size.width / w, size.height / h)
        self.frame_image = NSMakeRect((size.width-w*factor)/2, (size.height-h*factor)/2, w*factor, h*factor)
        self.image.drawInRect_fromRect_operation_fraction_respectFlipped_hints_(
            self.frame_image, A.NSZeroRect, A.NSCompositingOperationSourceOver, 1.0, True, None
        )
        if self.owner and self.owner.sensor:
            w, h = self.owner.sensor
            x, y, rw, rh = self.drag_roi or self.owner.roi
            origin, size = self.frame_image.origin, self.frame_image.size
            A.NSColor.systemYellowColor().setStroke()
            outline = A.NSBezierPath.bezierPathWithRect_(NSMakeRect(
                origin.x+(x-1)*size.width/w, origin.y+(y-1)*size.height/h,
                rw*size.width/w, rh*size.height/h,
            ))
            outline.setLineWidth_(2)
            outline.stroke()

    @objc.python_method
    def show(self, image):
        self.image = image
        if self.placeholder is not None:
            self.placeholder.setHidden_(image is not None)
        self.setNeedsDisplay_(True)

    @objc.python_method
    def sensor_point(self, event):
        p = self.convertPoint_fromView_(event.locationInWindow(), None)
        origin, size = self.frame_image.origin, self.frame_image.size
        w, h = self.owner.sensor
        return (max(0, min(w, round((p.x-origin.x)*w/size.width))),
                max(0, min(h, round((p.y-origin.y)*h/size.height))))

    def mouseDown_(self, event):
        if self.owner and self.owner.sensor and not self.owner.busy and hasattr(self, "frame_image"):
            self.start = self.sensor_point(event)

    def mouseDragged_(self, event):
        if self.start is None:
            return
        x, y = self.sensor_point(event)
        a, b = self.start
        self.drag_roi = (1+min(x, a), 1+min(y, b), abs(x-a), abs(y-b))
        self.setNeedsDisplay_(True)

    def mouseUp_(self, event):
        if self.start is None:
            return
        self.mouseDragged_(event)
        roi = self.drag_roi
        self.start = self.drag_roi = None
        if min(roi[2:]) >= 20:
            self.owner.set_roi(roi)
            self.owner.automatic.setState_(A.NSControlStateValueOff)
            self.owner.manual_needed = False
            self.owner.settingsChanged_(None)
        self.setNeedsDisplay_(True)


class Controller(NSObject):
    @objc.python_method
    def button(self, title, action):
        button = A.NSButton.buttonWithTitle_target_action_(title, self, action)
        self.controls.append(button)
        return button

    @objc.python_method
    def stack(self, vertical, *views):
        stack = A.NSStackView.stackViewWithViews_(views)
        stack.setOrientation_(A.NSUserInterfaceLayoutOrientationVertical if vertical
                              else A.NSUserInterfaceLayoutOrientationHorizontal)
        stack.setAlignment_(A.NSLayoutAttributeLeading if vertical else A.NSLayoutAttributeCenterY)
        stack.setSpacing_(8)
        return stack

    @objc.python_method
    def field(self, width):
        field = A.NSTextField.textFieldWithString_("")
        field.setDelegate_(self)
        field.widthAnchor().constraintGreaterThanOrEqualToConstant_(width).setActive_(True)
        self.controls.append(field)
        return field

    @objc.python_method
    def panel(self, owner, body, title=None, icon=None):
        panel = ImagePanel.alloc().initWithFrame_(NSMakeRect(0, 0, 600, 300))
        panel.setWantsLayer_(True)
        panel.layer().setMasksToBounds_(True)
        panel.image = panel.drag_roi = panel.start = None
        panel.owner = owner
        # Guidance shown until the panel has an image.
        style = A.NSMutableParagraphStyle.alloc().init()
        style.setParagraphSpacing_(9)
        text = A.NSMutableAttributedString.alloc().init()
        for content, font in ((title, A.NSFont.boldSystemFontOfSize_(18)), (body, A.NSFont.systemFontOfSize_(14))):
            if content:
                text.appendAttributedString_(A.NSAttributedString.alloc().initWithString_attributes_(
                    content + "\n", {A.NSFontAttributeName: font, A.NSParagraphStyleAttributeName: style,
                                     A.NSForegroundColorAttributeName: A.NSColor.labelColor()}))
        text.deleteCharactersInRange_((text.length() - 1, 1))
        label = A.NSTextField.wrappingLabelWithString_("")
        label.setAttributedStringValue_(text)
        label.setSelectable_(False)
        guide = label
        if icon is not None:
            picture = A.NSImageView.imageViewWithImage_(icon)
            picture.setImageScaling_(A.NSImageScaleProportionallyUpOrDown)
            for anchor in (picture.widthAnchor(), picture.heightAnchor()):
                anchor.constraintEqualToConstant_(128).setActive_(True)
            guide = self.stack(False, picture, label)
            guide.setAlignment_(A.NSLayoutAttributeTop)
            guide.setSpacing_(24)
        guide.setTranslatesAutoresizingMaskIntoConstraints_(False)
        panel.addSubview_(guide)
        for constraint in (
            guide.centerXAnchor().constraintEqualToAnchor_(panel.centerXAnchor()),
            guide.centerYAnchor().constraintEqualToAnchor_(panel.centerYAnchor()),
            label.widthAnchor().constraintLessThanOrEqualToConstant_(660),
            guide.leadingAnchor().constraintGreaterThanOrEqualToAnchor_constant_(panel.leadingAnchor(), 24),
        ):
            constraint.setActive_(True)
        panel.placeholder = guide
        return panel

    @objc.python_method
    def build(self):
        self.paths, self.controls = [], []
        self.busy = self.manual_needed = False
        self.sensor = None
        self.roi = (1, 1, 100, 100)
        self.window = A.NSWindow.alloc().initWithContentRect_styleMask_backing_defer_(
            NSMakeRect(80, 80, 1120, 790),
            A.NSWindowStyleMaskTitled | A.NSWindowStyleMaskClosable | A.NSWindowStyleMaskResizable,
            A.NSBackingStoreBuffered, False,
        )
        self.window.setTitle_(f"Camera-41_exp {VERSION} — Digital camera setup")
        self.window.setMinSize_((900, 640))
        self.window.setDelegate_(self)
        self.window.setReleasedWhenClosed_(False)
        self.files = A.NSPopUpButton.alloc().initWithFrame_pullsDown_(NSMakeRect(0, 0, 320, 24), False)
        self.files.addItemWithTitle_("No RAW files")
        self.files.widthAnchor().constraintEqualToConstant_(315).setActive_(True)
        self.controls.append(self.files)
        buttons = self.stack(False, self.button("Add FB+F RAWs…", "addFiles:"), self.files,
                             self.button("Remove selected", "removeFile:"), self.button("Preview selected", "preview:"))
        self.light, self.sample = self.field(245), self.field(245)
        fields = self.stack(False, A.NSTextField.labelWithString_("Light setup"), self.light,
                            A.NSTextField.labelWithString_("Film base + fog"), self.sample)
        self.automatic = A.NSButton.checkboxWithTitle_target_action_("Automatic area", self, "settingsChanged:")
        self.confirm = A.NSButton.checkboxWithTitle_target_action_("Same FB+F sample in all RAWs", self, "settingsChanged:")
        self.controls.extend([self.automatic, self.confirm])
        self.automatic.setState_(A.NSControlStateValueOn)
        self.coords = [self.field(58) for _ in range(4)]
        coordinates = [item for label, field in zip(("X", "Y", "Width", "Height"), self.coords)
                       for item in (A.NSTextField.labelWithString_(label), field)]
        area = self.stack(False, self.automatic, *coordinates, self.confirm)
        self.set_roi(self.roi)

        self.preview_panel = self.panel(self, WELCOME, WELCOME_TITLE, app_icon())
        self.graph = self.panel(None, NO_CHARTS)
        self.report = A.NSTextView.alloc().initWithFrame_(NSMakeRect(0, 0, 600, 200))
        self.report.setEditable_(False)
        self.report.setString_(NO_RESULTS)
        self.report.setFont_(A.NSFont.monospacedSystemFontOfSize_weight_(13, A.NSFontWeightRegular))
        self.report.setVerticallyResizable_(True)
        self.report.setAutoresizingMask_(A.NSViewWidthSizable)
        scroll = A.NSScrollView.alloc().initWithFrame_(NSMakeRect(0, 0, 600, 200))
        scroll.setHasVerticalScroller_(True)
        scroll.setDocumentView_(self.report)
        self.tabs = A.NSTabView.alloc().initWithFrame_(NSMakeRect(0, 0, 600, 300))
        for identifier, name, view in (("preview", "RAW preview", self.preview_panel),
                                        ("results", "Results", scroll),
                                        ("comparison", "Exposure comparison", self.graph)):
            tab = A.NSTabViewItem.alloc().initWithIdentifier_(identifier)
            tab.setLabel_(name)
            tab.setView_(view)
            self.tabs.addTabViewItem_(tab)
        self.tabs.heightAnchor().constraintGreaterThanOrEqualToConstant_(350).setActive_(True)
        self.status = A.NSTextField.wrappingLabelWithString_(
            "Add a film-base bracket at fixed ISO and aperture. Preview a RAW to inspect or drag the yellow measurement area."
        )
        self.status.setContentHuggingPriority_forOrientation_(750, A.NSLayoutConstraintOrientationVertical)
        self.status.setContentCompressionResistancePriority_forOrientation_(1000, A.NSLayoutConstraintOrientationVertical)
        self.times = A.NSPopUpButton.alloc().initWithFrame_pullsDown_(NSMakeRect(0, 0, 200, 24), False)
        self.times.setTarget_(self)
        self.times.setAction_("chooseTime:")
        self.times.addItemWithTitle_("Analyse first")
        self.times.setEnabled_(False)
        footer = self.stack(False, self.button("Analyse RAW images", "runAnalysis:"), self.times,
                            self.button("Open log", "openLog:"))
        container = self.window.contentView()
        previous = None
        for view in (buttons, fields, area, self.tabs, self.status, footer):
            view.setTranslatesAutoresizingMaskIntoConstraints_(False)
            container.addSubview_(view)
            top = previous.bottomAnchor() if previous is not None else container.topAnchor()
            view.topAnchor().constraintEqualToAnchor_constant_(top, 8 if previous else 14).setActive_(True)
            view.leadingAnchor().constraintEqualToAnchor_constant_(container.leadingAnchor(), 14).setActive_(True)
            trailing = view.trailingAnchor()
            if view in (self.tabs, self.status):
                trailing.constraintEqualToAnchor_constant_(container.trailingAnchor(), -14).setActive_(True)
            else:
                trailing.constraintLessThanOrEqualToAnchor_constant_(container.trailingAnchor(), -14).setActive_(True)
                view.setContentHuggingPriority_forOrientation_(750, A.NSLayoutConstraintOrientationVertical)
                view.setContentCompressionResistancePriority_forOrientation_(1000, A.NSLayoutConstraintOrientationVertical)
            previous = view
        footer.bottomAnchor().constraintEqualToAnchor_constant_(container.bottomAnchor(), -14).setActive_(True)
        self.update_controls()
        self.window.center()
        return self.window

    @objc.python_method
    def set_roi(self, roi):
        self.roi = roi
        # Plain digits: locale grouping such as "1 311" does not read back as a number.
        for field, value in zip(self.coords, roi):
            field.setStringValue_(str(value))

    @objc.python_method
    def typed_roi(self):
        values = []
        for field in self.coords:
            value = str(field.stringValue()).strip()
            if not re.fullmatch(r"[0-9]+|[0-9]{1,3}(?:[   ][0-9]{3})+", value):
                return None
            values.append(int("".join(value.split())))
        return tuple(values)

    @objc.python_method
    def update_controls(self):
        for control in self.controls:
            control.setEnabled_(not self.busy)
        manual = self.automatic.state() == A.NSControlStateValueOff
        for field in self.coords:
            field.setEditable_(manual)
        self.times.setEnabled_(not self.busy and self.times.numberOfItems() > 1)

    def controlTextDidChange_(self, notification):
        if notification.object() in self.coords:
            roi = self.typed_roi()
            self.manual_needed = roi is None or min(roi) <= 0 or min(roi[2:]) < 20
            if not self.manual_needed:
                self.roi = roi
            self.preview_panel.setNeedsDisplay_(True)
        self.settingsChanged_(None)

    def settingsChanged_(self, sender):
        self.times.removeAllItems()
        self.times.addItemWithTitle_("Analyse first")
        self.report.setString_(NO_RESULTS)
        self.graph.show(None)
        self.status.setStringValue_("Settings changed. Analyse to update the exposure result.")
        self.update_controls()

    @objc.python_method
    def update_files(self):
        self.files.removeAllItems()
        if self.paths:
            self.files.addItemsWithTitles_([str(path) for path in self.paths])
        else:
            self.files.addItemWithTitle_("No RAW files")
        self.preview_panel.show(None)
        self.sensor = None
        self.manual_needed = False
        self.automatic.setState_(A.NSControlStateValueOn)
        self.settingsChanged_(None)
        log("files.updated", Files=[str(path) for path in self.paths])

    def addFiles_(self, sender):
        panel = A.NSOpenPanel.openPanel()
        panel.setAllowsMultipleSelection_(True)
        panel.setAllowedContentTypes_(raw_types())
        folder = PREFERENCES.stringForKey_("Camera41ExpPythonRAWFolder")
        if folder and Path(folder).is_dir():
            panel.setDirectoryURL_(A.NSURL.fileURLWithPath_(folder))
        if panel.runModal() == A.NSModalResponseOK:
            chosen = [Path(url.path()).resolve() for url in panel.URLs()]
            additions = [path for path in chosen if is_raw(path)]
            PREFERENCES.setObject_forKey_(str(chosen[0].parent), "Camera41ExpPythonRAWFolder")
            if additions:
                self.paths = list(dict.fromkeys(self.paths + additions))
                self.update_files()
            if len(additions) < len(chosen):
                self.status.setStringValue_(
                    f"Only camera RAW files can be analysed ({', '.join(RAW_EXTENSIONS).upper()}). "
                    f"Left out {len(chosen) - len(additions)} other file(s).")

    def removeFile_(self, sender):
        if self.paths:
            del self.paths[self.files.indexOfSelectedItem()]
            self.update_files()

    @objc.python_method
    def background(self, message, work, complete):
        self.busy = True
        self.status.setStringValue_(message)
        self.update_controls()

        def run():
            try:
                result = work()
            except Exception as error:
                AppHelper.callAfter(finish, None, error)
            else:
                AppHelper.callAfter(finish, result, None)

        def finish(result, error):
            self.busy = False
            self.update_controls()
            if isinstance(error, AreaReview):
                self.manual_needed = True
                self.files.selectItemAtIndex_(self.paths.index(error.path))
                self.start_preview(error.path, error)
            elif error:
                self.status.setStringValue_(str(error))
                log("error", Message=str(error))
            else:
                complete(result)

        Thread(target=run, daemon=True).start()

    @objc.python_method
    def start_preview(self, path, review=None):
        def work():
            capture = decode(path)
            area, reasons = automatic_area(capture.linear)
            return preview_image(capture), capture.linear.shape[::-1], area, reasons

        def complete(result):
            image, self.sensor, area, reasons = result
            if review or self.automatic.state() == A.NSControlStateValueOn:
                self.set_roi(area)
            if review:
                self.automatic.setState_(A.NSControlStateValueOff)
                self.update_controls()
            self.preview_panel.show(native_image(image))
            self.tabs.selectTabViewItemWithIdentifier_("preview")
            self.status.setStringValue_(str(review) if review else
                "Display preview. Drag the yellow area to measure a clean part of the film base.")
            log("preview.complete", File=str(path), ROI=self.roi, AreaWarnings=reasons)

        self.background("Decoding selected RAW…", work, complete)

    def preview_(self, sender):
        if self.paths:
            self.start_preview(self.paths[self.files.indexOfSelectedItem()])

    def runAnalysis_(self, sender):
        light, sample = (str(field.stringValue()).strip() for field in (self.light, self.sample))
        if not self.paths or not light or not sample or not self.confirm.state():
            self.status.setStringValue_("Add RAWs, describe the light and film base, and confirm the same FB+F sample.")
            return
        if self.manual_needed:
            self.status.setStringValue_("Adjust the yellow measurement area before analysing again.")
            return
        roi = None if self.automatic.state() else self.typed_roi()
        if not self.automatic.state() and roi is None:
            self.status.setStringValue_("Enter whole numbers for X, Y, Width and Height.")
            return
        paths = self.paths.copy()
        self.settingsChanged_(None)
        log("analysis.begin", Files=[str(path) for path in paths], Light=light, Sample=sample, ROI=roi)
        self.background("Analysing RAW exposures…", lambda: analyse(paths, roi), self.show_results)

    @objc.python_method
    def show_results(self, result):
        roi, rows, selection = result
        self.set_roi(roi)
        self.preview_panel.setNeedsDisplay_(True)
        lines = [SELECTION_MESSAGES[selection.status], f"Measurement area [x y width height]  {roi}",
                 f"Proportionality  {selection.proportionality.replace('_', ' ').lower()}",
                 "Pass limits per channel  ≥ ⅓ EV headroom, < 0.01% at the clipping reference"
                 f" and a median within {-math.log2(MIN_SIGNAL):g} EV of it (otherwise LOW)."]
        if any(row.white_level_fallback for row in rows):
            lines.append("Clipping reference  LibRaw white level. These RAWs carry no per-channel linearity limit.")
        if selection.candidate is not None:
            lines.append(f"Suggested measured time  {selection.candidate:.8g} s")
        if selection.next_test is not None:
            lines.append(f"Next test  {selection.next_test:.8g} s")
        for row in rows:
            lines += ["", f"{Path(row.path).name}   {row.seconds:.8g} s   {row.status}"]
            for i, channel in enumerate(CHANNELS):
                lines.append(f"  {channel:2s}  {row.signal[i]:9.1f} codes  {row.margin[i]:7.3f} EV"
                             f"  {100*row.clipped[i]:9.4f}%  {row.channel_status[i]}")
        if selection.candidate is not None:
            lines += ["", HANDOFF]
        self.report.setString_("\n".join(lines))
        self.graph.show(native_image(comparison_image(rows)))
        passing = sorted({row.seconds for row in rows if row.status == "PASS"}
                         - {row.seconds for row in rows if row.status != "PASS"})
        if selection.status == "REVIEW_INCONSISTENT_SERIES":
            passing = []
        self.times.removeAllItems()
        self.times.addItemWithTitle_("Repeat the series" if selection.status == "REVIEW_INCONSISTENT_SERIES"
                                    else "Choose a measured time" if passing else "No passing exposure")
        for time in passing:
            self.times.addItemWithTitle_(f"{time:.8g} s")
            self.times.lastItem().setRepresentedObject_(time)
        self.update_controls()
        self.tabs.selectTabViewItemWithIdentifier_("results")
        self.status.setStringValue_(SELECTION_MESSAGES[selection.status])
        log("analysis.complete", ROI=roi, Measurements=[asdict(row) for row in rows],
            Selection=asdict(selection), HasMeasuredNoise=False)

    def chooseTime_(self, sender):
        time = sender.selectedItem().representedObject()
        if time is not None:
            self.status.setStringValue_(f"Chosen time {time:.8g} s. {HANDOFF}")
            log("time.chosen", Seconds=time)

    def openLog_(self, sender):
        log("log.open")
        A.NSWorkspace.sharedWorkspace().openURL_(A.NSURL.fileURLWithPath_(str(LOG_PATH)))

    def windowShouldClose_(self, window):
        if self.busy:
            self.status.setStringValue_("Wait for the RAW operation to finish before closing.")
        return not self.busy

    def applicationShouldTerminate_(self, sender):
        return A.NSTerminateNow if self.windowShouldClose_(self.window) else A.NSTerminateCancel

    def windowWillClose_(self, notification):
        A.NSApplication.sharedApplication().terminate_(None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--startup-check", action="store_true")
    parser.add_argument("--smoke-test", nargs="+", type=Path, metavar="RAW")
    args = parser.parse_args()
    app = A.NSApplication.sharedApplication()
    app.setActivationPolicy_(A.NSApplicationActivationPolicyRegular)
    controller = Controller.alloc().init()
    if args.startup_check or args.smoke_test:
        # Build checks must not write to the user's diagnostic log.
        global log_enabled
        log_enabled = False
    window = controller.build()
    app.setDelegate_(controller)
    build_menu(app)
    app.setApplicationIconImage_(app_icon())
    if args.startup_check or args.smoke_test:
        raw_probe()
        if args.smoke_test:
            paths = args.smoke_test
            capture = decode(paths[0])
            roi, _ = automatic_area(capture.linear)
            assert native_image(preview_image(capture)) is not None
            controller.show_results(analyse(paths))
            assert controller.graph.image is not None and controller.report.string()
        print("CAMERA41_EXP_PYTHON_STARTUP_OK")
        return
    log("window.created", Version=VERSION)
    window.makeKeyAndOrderFront_(None)
    app.activateIgnoringOtherApps_(True)
    AppHelper.runEventLoop()


if __name__ == "__main__":
    main()
