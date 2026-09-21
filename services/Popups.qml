pragma Singleton
import QtQuick
import Quickshell

// Какое окно виджета открыто сейчас: одновременно может быть только одно.
Singleton {
    property string activeId: ""
}
