pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick

// Upstream recolours icons via CUtils.getDominantColour, which touches
// QJSValue from a QThreadPool worker (thread-unsafe in libcaelestia.so) and
// crashes the shell with SEGV. Plain icon instead; API kept identical.
IconImage {
    id: root

    required property color colour
    property color dominantColour

    asynchronous: true
}
