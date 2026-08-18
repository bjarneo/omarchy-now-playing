import QtQuick
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

// Now playing. Prefers the actively playing MPRIS player, falls back to
// the first one with a track. Absent media, absent widget.
BarWidget {
  id: root
  moduleName: "now-playing"

  readonly property var player: {
    var players = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < players.length; i++) {
      if (players[i] && players[i].isPlaying) return players[i]
    }
    for (var j = 0; j < players.length; j++) {
      if (players[j] && players[j].trackTitle) return players[j]
    }
    return null
  }

  readonly property string title: player && player.trackTitle ? player.trackTitle : ""
  readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
  readonly property bool playing: player !== null && player.isPlaying
  readonly property string label: artist ? artist + " - " + title : title
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property real maxLabelWidth: Style.space(Math.max(120, Number(setting("maxWidth", 220)) || 220))
  readonly property color pillFill: Color.background
  property bool controlsVisible: false
  readonly property color pillBorder: Style.controlBorder(false, controlsVisible, foreground, Color.accent)

  HoverHandler {
    id: hoverHandler
    onHoveredChanged: root.syncControlsVisibility()
  }

  Timer {
    id: controlsHide
    interval: 180
    onTriggered: root.controlsVisible = false
  }

  function syncControlsVisibility() {
    if (hoverHandler.hovered || previousControl.tooltipHovered || playControl.tooltipHovered || nextControl.tooltipHovered) {
      controlsHide.stop()
      controlsVisible = true
    } else if (controlsVisible) {
      controlsHide.restart()
    }
  }

  function controlPlayer(mouseButton) {
    if (!player) return
    if (mouseButton === Qt.RightButton && player.canGoNext) player.next()
    else if (mouseButton === Qt.MiddleButton && player.canGoPrevious) player.previous()
    else player.togglePlaying()
  }

  function prioritizeControls() {
    if (!bar || !bar.registerClickTarget || !bar.unregisterClickTarget) return
    var controls = [previousControl, playControl, nextControl]
    for (var i = 0; i < controls.length; i++) bar.unregisterClickTarget(controls[i])
    for (var j = 0; j < controls.length; j++) bar.registerClickTarget(controls[j])
  }

  Timer {
    id: marqueeStart
    interval: 180
    onTriggered: {
      labelText.x = 0
      if (labelClip.overflow > 0) marquee.restart()
    }
  }

  onLabelChanged: marqueeStart.restart()
  onVisibleChanged: if (!visible) controlsVisible = false
  Component.onCompleted: Qt.callLater(function() { root.prioritizeControls() })

  visible: !vertical && title !== ""
  implicitWidth: visible ? content.implicitWidth + Style.space(18) : 0
  implicitHeight: barSize

  Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: " "
    dimmed: !root.playing
    tooltipText: root.artist ? root.artist + " - " + root.title : root.title
    onPressed: function(mouseButton) { root.controlPlayer(mouseButton) }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.topMargin: 2
      anchors.bottomMargin: 2
      z: -1
      radius: height / 2
      color: root.pillFill
      border.width: Style.controlBorderWidth(false, root.controlsVisible)
      border.color: root.pillBorder

      Behavior on color { ColorAnimation { duration: 120 } }
      Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    Item {
      id: content
      anchors.centerIn: parent
      implicitWidth: Math.max(Style.space(78), glyph.implicitWidth + Style.space(6) + labelClip.normalWidth)
      width: implicitWidth
      height: parent.height

      WidgetButton {
        id: previousControl
        bar: root.bar
        text: "\u{f04ae}"
        fontSize: Style.font.bodySmall
        foreground: root.foreground
        fixedWidth: Style.space(20)
        fixedHeight: root.barSize
        interactive: root.controlsVisible
        opacity: root.controlsVisible ? (root.player && root.player.canGoPrevious ? 1 : 0.45) : 0
        pressable: root.player && root.player.canGoPrevious
        tooltipText: qsTr("Previous track")
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        onTooltipHoveredChanged: root.syncControlsVisibility()
        onPressed: function(mouseButton) {
          if (mouseButton === Qt.LeftButton && root.player && root.player.canGoPrevious)
            root.player.previous()
        }
      }

      Text {
        id: glyph
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.controlsVisible ? 0 : 1
        x: 0
        text: root.playing ? "\u{f03e4}" : "\u{f040a}"
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall

        Behavior on opacity { OpacityAnimator { duration: 120; easing.type: Easing.OutCubic } }
      }

      WidgetButton {
        id: playControl
        bar: root.bar
        text: root.playing ? "\u{f03e4}" : "\u{f040a}"
        fontSize: Style.font.bodySmall
        foreground: root.foreground
        fixedWidth: Style.space(20)
        fixedHeight: root.barSize
        interactive: root.controlsVisible
        opacity: root.controlsVisible ? 1 : 0
        tooltipText: root.artist ? root.artist + " - " + root.title : root.title
        x: previousControl.width + Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        onTooltipHoveredChanged: root.syncControlsVisibility()
        onPressed: function(mouseButton) { root.controlPlayer(mouseButton) }
      }

      WidgetButton {
        id: nextControl
        bar: root.bar
        text: "\u{f04ad}"
        fontSize: Style.font.bodySmall
        foreground: root.foreground
        fixedWidth: Style.space(20)
        fixedHeight: root.barSize
        interactive: root.controlsVisible
        opacity: root.controlsVisible ? (root.player && root.player.canGoNext ? 1 : 0.45) : 0
        pressable: root.player && root.player.canGoNext
        tooltipText: qsTr("Next track")
        x: playControl.x + playControl.width + Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        onTooltipHoveredChanged: root.syncControlsVisibility()
        onPressed: function(mouseButton) {
          if (mouseButton === Qt.LeftButton && root.player && root.player.canGoNext)
            root.player.next()
        }
      }

      Item {
        id: labelClip
        readonly property real normalWidth: Math.min(root.maxLabelWidth, labelText.implicitWidth)
        x: root.controlsVisible ? nextControl.x + nextControl.width + Style.space(6) : glyph.x + glyph.implicitWidth + Style.space(6)
        width: root.controlsVisible ? Math.max(0, parent.width - x) : Math.min(normalWidth, parent.width - x)
        height: glyph.implicitHeight
        clip: true
        anchors.verticalCenter: parent.verticalCenter
        readonly property real overflow: Math.max(0, labelText.implicitWidth - width)

        Text {
          id: labelText
          anchors.verticalCenter: parent.verticalCenter
          text: root.label
          color: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          renderType: Text.NativeRendering
        }

        SequentialAnimation {
          id: marquee

          PauseAnimation { duration: 650 }
          NumberAnimation {
            target: labelText
            property: "x"
            from: 0
            to: -labelClip.overflow
            duration: Math.max(1600, labelClip.overflow * 24)
            easing.type: Easing.InOutSine
          }
          PauseAnimation { duration: 900 }
          NumberAnimation {
            target: labelText
            property: "x"
            from: -labelClip.overflow
            to: 0
            duration: Math.max(1200, labelClip.overflow * 18)
            easing.type: Easing.InOutSine
          }
        }

        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(Style.space(24), parent.width)
          height: parent.height
          visible: labelText.implicitWidth > parent.width
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(root.pillFill.r, root.pillFill.g, root.pillFill.b, 0) }
            GradientStop { position: 1; color: root.pillFill }
          }
        }
      }
    }
  }
}
