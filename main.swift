import Cocoa

struct Account: Decodable { let name: String; let anchor: String; let offset: Int?; let configDir: String? }
struct Acc { let name: String; let anchor: Date; let offset: Int?; let configDir: String? }

let configPath = NSString(string: "~/ClaudeResetWidget/accounts.json").expandingTildeInPath
let week: TimeInterval = 7 * 86400
let cycleBase = ISO8601DateFormatter().date(from: "2026-10-07T01:04:00+02:00")!
let cycle: TimeInterval = 305 * 60
let windowLen: TimeInterval = 300 * 60

func loadAccounts() -> [Acc] {
    guard let data = FileManager.default.contents(atPath: configPath),
          let list = try? JSONDecoder().decode([Account].self, from: data) else { return [] }
    let f = ISO8601DateFormatter()
    return list.compactMap { a in f.date(from: a.anchor).map { Acc(name: a.name, anchor: $0, offset: a.offset, configDir: a.configDir) } }
}

func nextReset(_ anchor: Date, now: Date) -> Date {
    let diff = now.timeIntervalSince(anchor)
    return anchor.addingTimeInterval((diff <= 0 ? 0 : ceil(diff / week)) * week)
}

func fmt(_ t: TimeInterval) -> String {
    let s = max(0, Int(t))
    let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
    return d > 0 ? "\(d)g \(h)h \(m)m" : "\(h)h \(m)m"
}

struct Card {
    var name: String, weekLeft: TimeInterval, weekDate: String, weekUsed: Double, isNext: Bool
    var winText: String?, winFrac: Double, winOpen: Bool
}

class CardView: NSView {
    let c: Card
    init(_ c: Card) {
        self.c = c
        super.init(frame: NSRect(x: 0, y: 0, width: 350, height: 112))
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }

    func text(_ s: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular,
              color: NSColor = .labelColor, right: Bool = false, mono: Bool = false) {
        let font = mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
                        : NSFont.systemFont(ofSize: size, weight: weight)
        let a = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
        let w = a.size().width
        a.draw(at: NSPoint(x: right ? x - w : x, y: y))
    }

    func bar(_ y: CGFloat, _ frac: Double, _ color: NSColor, h: CGFloat) {
        let r = NSRect(x: 16, y: y, width: bounds.width - 32, height: h)
        NSColor.labelColor.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: r, xRadius: h / 2, yRadius: h / 2).fill()
        var f = r; f.size.width = max(h, r.width * CGFloat(min(max(frac, 0), 1)))
        color.setFill()
        NSBezierPath(roundedRect: f, xRadius: h / 2, yRadius: h / 2).fill()
    }

    override func draw(_ dirtyRect: NSRect) {
        let urgent: NSColor = c.weekLeft < 86400 ? .systemRed : (c.weekLeft < 2 * 86400 ? .systemOrange : .systemGreen)
        let W = bounds.width
        // Riga 1: nome + tempo alla scadenza settimanale
        urgent.setFill()
        NSBezierPath(ovalIn: NSRect(x: 16, y: 11, width: 9, height: 9)).fill()
        text(c.name, 31, 6, size: 14, weight: .semibold)
        if c.isNext {
            text("PROSSIMO", 31 + (c.name as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold)]).width + 8,
                 9, size: 9, weight: .bold, color: .systemOrange)
        }
        text(fmt(c.weekLeft), W - 16, 5, size: 16, weight: .semibold, color: urgent, right: true, mono: true)
        // Riga 2: dettaglio settimana
        text("Reset settimanale  \(c.weekDate)", 16, 29, size: 11, color: .secondaryLabelColor)
        text("\(Int(c.weekUsed * 100))% trascorso", W - 16, 29, size: 11, color: .secondaryLabelColor, right: true)
        bar(46, c.weekUsed, urgent, h: 7)
        // Riga 3: finestra 5h
        if let t = c.winText {
            let col: NSColor = c.winOpen ? .systemBlue : .tertiaryLabelColor
            text("Finestra 5h", 16, 66, size: 11, color: .secondaryLabelColor)
            text(t, W - 16, 66, size: 11, weight: .medium, color: c.winOpen ? .labelColor : .secondaryLabelColor, right: true, mono: true)
            bar(84, c.winFrac, col, h: 5)
        }
    }
}

class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let df: DateFormatter = {
        let d = DateFormatter(); d.locale = Locale(identifier: "it_IT")
        d.dateFormat = "EEE d MMM, HH:mm"; return d
    }()
    let hm: DateFormatter = { let d = DateFormatter(); d.dateFormat = "HH:mm"; return d }()

    func applicationDidFinishLaunching(_ n: Notification) {
        refresh()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)
    }

    var remoteList: [(String, Bool)] = []
    let remotePath = NSString(string: "~/ClaudeResetWidget/remote.txt").expandingTildeInPath
    func remoteHost() -> String? {
        guard let t = try? String(contentsOfFile: remotePath, encoding: .utf8) else { return nil }
        let h = t.trimmingCharacters(in: .whitespacesAndNewlines); return h.isEmpty ? nil : h
    }
    func runRemote(_ host: String, _ args: String) -> String? {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        p.arguments = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=5", host, "sudo /usr/local/bin/claude-switch-remote \(args)"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return p.terminationStatus == 0 ? String(data: d, encoding: .utf8) : nil
    }
    func fetchRemote() {
        guard let host = remoteHost() else { return }
        DispatchQueue.global().async { [weak self] in
            guard let out = self?.runRemote(host, "list") else { return }
            let list = out.split(separator: "\n").map { l -> (String, Bool) in
                let t = String(l); return (t.dropFirst(2).trimmingCharacters(in: .whitespaces), t.hasPrefix("*")) }
            DispatchQueue.main.async {
                guard let s = self else { return }
                if list.map({ "\($0.0)\($0.1)" }) != s.remoteList.map({ "\($0.0)\($0.1)" }) { s.remoteList = list; s.refresh(fetch: false) }
            }
        }
    }
    @objc func switchRemote(_ s: NSMenuItem) {
        guard let name = s.representedObject as? String, let host = remoteHost() else { return }
        DispatchQueue.global().async { [weak self] in
            _ = self?.runRemote(host, name)
            DispatchQueue.main.async { self?.fetchRemote() }
        }
    }

    func refresh(fetch: Bool = true) {
        if fetch { fetchRemote() }
        let now = Date()
        let rows = loadAccounts().map { ($0, nextReset($0.anchor, now: now)) }.sorted { $0.1 < $1.1 }
        let m = NSMenu()
        var nextWindow: (String, Date)? = nil
        for (i, r) in rows.enumerated() {
            let (a, reset) = r
            let left = reset.timeIntervalSince(now)
            var card = Card(name: a.name, weekLeft: left, weekDate: df.string(from: reset),
                            weekUsed: 1 - left / week, isNext: i == 0, winText: nil, winFrac: 0, winOpen: false)
            if let off = a.offset {
                let base = cycleBase.addingTimeInterval(Double(off) * 60)
                let start = base.addingTimeInterval(floor(now.timeIntervalSince(base) / cycle) * cycle)
                let end = start.addingTimeInterval(windowLen)
                let nextSend = start.addingTimeInterval(cycle)
                if now < end {
                    card.winOpen = true
                    card.winFrac = now.timeIntervalSince(start) / windowLen
                    card.winText = "reset tra \(fmt(end.timeIntervalSince(now)))  ·  \(hm.string(from: end))"
                    if nextWindow == nil || end < nextWindow!.1 { nextWindow = (a.name, end) }
                } else {
                    card.winFrac = 1
                    card.winText = "riparte \(hm.string(from: nextSend))  ·  tra \(fmt(nextSend.timeIntervalSince(now)))"
                    if nextWindow == nil || nextSend < nextWindow!.1 { nextWindow = (a.name, nextSend) }
                }
            }
            let mi = NSMenuItem()
            mi.view = CardView(card)
            m.addItem(mi)
            if i < rows.count - 1 { m.addItem(.separator()) }
        }
        // Selettore account per VS Code
        m.addItem(.separator())
        let cur = currentVSCodeDir()
        let sub = NSMenu()
        if remoteHost() != nil {
            for (n, on) in remoteList {
                let it = NSMenuItem(title: n, action: #selector(switchRemote(_:)), keyEquivalent: "")
                it.target = self; it.representedObject = n; it.state = on ? .on : .off; sub.addItem(it)
            }
            if remoteList.isEmpty { sub.addItem(NSMenuItem(title: "server non raggiungibile…", action: nil, keyEquivalent: "")) }
        } else {
        for a in loadAccounts() {
            let dir = a.configDir.map { NSString(string: $0).expandingTildeInPath }
            let ready = dir == nil || FileManager.default.fileExists(atPath: dir!)
            let it = NSMenuItem(title: ready ? a.name : "\(a.name)  (login necessario)", action: #selector(switchAccount(_:)), keyEquivalent: "")
            it.target = self; it.representedObject = a.name
            it.state = (dir == cur) ? .on : .off
            sub.addItem(it)
        }
        }
        let parent = NSMenuItem(title: remoteHost() != nil ? "Account Claude sul server" : "Account VS Code", action: nil, keyEquivalent: "")
        parent.submenu = sub; m.addItem(parent)
        var title = "⏳ nessun account"
        if let first = rows.first {
            title = "⏳ \(first.0.name) \(fmt(first.1.timeIntervalSince(now)))"
            if let w = nextWindow { title += "  ⟳ \(w.0) \(fmt(w.1.timeIntervalSince(now)))" }
        }
        item.button?.title = title
        m.addItem(.separator())
        let edit = NSMenuItem(title: "Modifica account…", action: #selector(openConfig), keyEquivalent: "")
        edit.target = self; m.addItem(edit)
        m.addItem(NSMenuItem(title: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = m
    }

    func currentVSCodeDir() -> String? {
        let p = NSString(string: "~/Library/Application Support/Code/User/settings.json").expandingTildeInPath
        guard let d = FileManager.default.contents(atPath: p),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let ev = j["claudeCode.environmentVariables"] as? [[String: String]] else { return nil }
        return ev.first { $0["name"] == "CLAUDE_CONFIG_DIR" }?["value"]
    }

    @objc func switchAccount(_ s: NSMenuItem) {
        guard let name = s.representedObject as? String else { return }
        let script = NSString(string: "~/ClaudeResetWidget/claude-switch").expandingTildeInPath
        let p = Process(); p.executableURL = URL(fileURLWithPath: script); p.arguments = [name]
        let pipe = Pipe(); p.standardError = pipe; p.standardOutput = pipe
        try? p.run(); p.waitUntilExit()
        if p.terminationStatus != 0 {
            // non ancora autenticato: apre Terminal per il login una tantum
            let cmd = "\(script) login \(name)"
            let osa = "tell application \"Terminal\" to activate\ntell application \"Terminal\" to do script \"\(cmd)\""
            let o = Process(); o.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); o.arguments = ["-e", osa]
            try? o.run()
        }
        refresh()
    }

    @objc func openConfig() { NSWorkspace.shared.open(URL(fileURLWithPath: configPath)) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
