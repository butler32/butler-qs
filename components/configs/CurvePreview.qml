import QtQuick
import "../../theme"

// График кривой скорости: по горизонтали время, по вертикали прогресс анимации (выход за 0–1 = «отскок»).
Canvas {
    id: c
    property var pts: [0.25, 0.1, 0.25, 1]
    property color line: Theme.accent
    property color grid: Theme.border
    implicitWidth: 110
    implicitHeight: 110

    onPtsChanged: requestPaint()
    onLineChanged: requestPaint()
    onGridChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        const pad = 8, lo = -0.6, hi = 1.6
        const X = x => pad + x * (width - 2 * pad)
        const Y = y => height - pad - ((y - lo) / (hi - lo)) * (height - 2 * pad)
        ctx.lineWidth = 1
        ctx.strokeStyle = grid.toString()
        ctx.beginPath()
        ctx.moveTo(X(0), Y(0)); ctx.lineTo(X(1), Y(0))
        ctx.moveTo(X(0), Y(1)); ctx.lineTo(X(1), Y(1))
        ctx.stroke()
        ctx.lineWidth = 2
        ctx.strokeStyle = line.toString()
        ctx.beginPath()
        ctx.moveTo(X(0), Y(0))
        ctx.bezierCurveTo(X(pts[0]), Y(pts[1]), X(pts[2]), Y(pts[3]), X(1), Y(1))
        ctx.stroke()
    }
}
