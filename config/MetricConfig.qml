import Quickshell.Io

// Показ одной метрики системного монитора.
// mode: "off" — не выводить, "always" — всегда, "yellow" — от жёлтого порога, "red" — от красного.
JsonObject {
    property string mode: "always"
    property int yellow: 60
    property int red: 85
}
