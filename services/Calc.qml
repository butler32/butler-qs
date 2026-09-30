pragma Singleton
import QtQuick
import Quickshell

// Калькулятор и конвертер единиц для строки поиска меню. Без eval: свой разбор
// выражений (+ − × ÷ ^, скобки, sqrt/sin/…, pi, e) и таблица единиц.
//   Calc.evaluate("2*(3+4)")        → { value: "14", label: "14" }
//   Calc.evaluate("5 km in mi")     → { value: "3.10685596 mi", label: "3.10685596 mi" }
// Всё, что не похоже на выражение (обычное слово, одно число), даёт null.
Singleton {
    id: root

    readonly property var funcs: ({
        sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
        sin: Math.sin, cos: Math.cos, tan: Math.tan, ln: Math.log, log: Math.log10, exp: Math.exp
    })
    readonly property var consts: ({ pi: Math.PI, e: Math.E })

    // единица → { cat, f } (множитель к базовой единице категории); температура — отдельно
    readonly property var units: {
        const u = {}
        const add = (cat, f, names) => names.split(" ").forEach(n => u[n] = { cat: cat, f: f })
        add("length", 0.001, "mm мм"); add("length", 0.01, "cm см"); add("length", 1, "m м")
        add("length", 1000, "km км"); add("length", 0.0254, "in дюйм"); add("length", 0.3048, "ft фут")
        add("length", 0.9144, "yd ярд"); add("length", 1609.344, "mi миля миль")
        add("mass", 1e-6, "mg мг"); add("mass", 0.001, "g г"); add("mass", 1, "kg кг")
        add("mass", 1000, "t т"); add("mass", 0.028349523125, "oz унция"); add("mass", 0.45359237, "lb фунт")
        add("volume", 0.001, "ml мл"); add("volume", 1, "l л"); add("volume", 3.785411784, "gal галлон")
        add("volume", 0.0295735295625, "floz")
        add("data", 0.125, "bit бит"); add("data", 1, "b byte байт"); add("data", 1e3, "kb кб"); add("data", 1e6, "mb мб")
        add("data", 1e9, "gb гб"); add("data", 1e12, "tb тб")
        add("data", 1024, "kib"); add("data", 1048576, "mib"); add("data", 1073741824, "gib"); add("data", 1099511627776, "tib")
        add("time", 0.001, "ms мс"); add("time", 1, "s с сек"); add("time", 60, "min мин"); add("time", 3600, "h ч час")
        add("time", 86400, "d д"); add("time", 604800, "w нед")
        add("speed", 1, "m/s м/с"); add("speed", 1 / 3.6, "km/h kmh км/ч"); add("speed", 0.44704, "mph")
        add("speed", 0.514444, "kn")
        add("temp", 0, "c °c °с с° f °f k")
        return u
    }

    function toKelvin(v, u) { return u === "f" || u === "°f" ? (v - 32) * 5 / 9 + 273.15 : u === "k" ? v : v + 273.15 }
    function fromKelvin(k, u) { return u === "f" || u === "°f" ? (k - 273.15) * 9 / 5 + 32 : u === "k" ? k : k - 273.15 }

    function fmt(n) {
        if (typeof n !== "number" || !isFinite(n)) return null
        return String(Number(n.toPrecision(12)))
    }

    // ---------- разбор выражения ----------

    function parse(src) {
        const s = src.replace(/,/g, ".").replace(/[−–]/g, "-").replace(/÷/g, "/").replace(/\*\*/g, "^")
                     .replace(/(\d)\s*[x×]\s*(?=[\d(.])/gi, "$1*").replace(/×/g, "*")
        const re = /\s*(\d+\.?\d*|\.\d+|[a-z]+|[-+*\/^()])/gy
        const toks = []
        let m, last = 0
        while ((m = re.exec(s)) !== null) { toks.push(m[1]); last = re.lastIndex }
        if (s.slice(last).trim() !== "" || toks.length === 0) throw new Error("tokens")

        let i = 0
        let operators = false
        const peek = () => toks[i]
        const next = () => toks[i++]
        function expr() {
            let v = term()
            while (peek() === "+" || peek() === "-") { operators = true; v = next() === "+" ? v + term() : v - term() }
            return v
        }
        function term() {
            let v = unary()
            while (peek() === "*" || peek() === "/") { operators = true; v = next() === "*" ? v * unary() : v / unary() }
            return v
        }
        function unary() {
            if (peek() === "-") { next(); return -unary() }
            if (peek() === "+") { next(); return unary() }
            return power()
        }
        function power() {
            const b = atom()
            if (peek() === "^") { operators = true; next(); return Math.pow(b, unary()) }
            return b
        }
        function atom() {
            const t = next()
            if (t === undefined) throw new Error("eof")
            if (/^[\d.]/.test(t)) return parseFloat(t)
            if (t === "(") { operators = true; const v = expr(); if (next() !== ")") throw new Error("paren"); return v }
            if (root.funcs[t]) {
                if (next() !== "(") throw new Error("call")
                operators = true
                const v = expr()
                if (next() !== ")") throw new Error("paren")
                return root.funcs[t](v)
            }
            if (t in root.consts) { operators = true; return root.consts[t] }
            throw new Error("token " + t)
        }
        const v = expr()
        if (i !== toks.length) throw new Error("trailing")
        return { value: v, plain: !operators }
    }

    function evaluate(text) {
        const q = (text ?? "").trim()
        if (q.length < 2 || q.length > 120) return null
        try {
            // «<выражение> <ед.> in|to|-> <ед.>»
            const c = q.toLowerCase().match(/^(.+?)\s*([^\s\d().+*^-][^\s]*)\s+(?:in|to|->|→|в|во)\s+([^\s]+)$/)
            if (c && root.units[c[2]] && root.units[c[3]]) {
                const from = root.units[c[2]], to = root.units[c[3]]
                const v = root.parse(c[1]).value
                if (from.cat !== to.cat) return null
                const out = from.cat === "temp"
                    ? root.fromKelvin(root.toKelvin(v, c[2]), c[3])
                    : v * from.f / to.f
                const n = root.fmt(out)
                return n === null ? null : { value: n + " " + c[3], label: n + " " + c[3] }
            }
            const r = root.parse(q)
            const n = root.fmt(r.value)
            if (n === null || r.plain) return null
            return { value: n, label: n }
        } catch (e) {
            return null
        }
    }
}
