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

struct Usage { var fiveUtil: Double?; var fiveReset: Date?; var weekUtil: Double?; var weekReset: Date?; var updated: Date }

struct Card {
    var name: String, weekLeft: TimeInterval, weekDate: String, weekUsed: Double
    var isActive: Bool
    var weekUtil: Double?, winUtil: Double?
    var winLeft: TimeInterval?, winClock: String?, winOpen: Bool
}

func sev(_ u: Double) -> NSColor { u < 0.6 ? .systemGreen : (u < 0.85 ? .systemOrange : .systemRed) }

class CardView: NSView {
    let c: Card
    init(_ c: Card) {
        self.c = c
        super.init(frame: NSRect(x: 0, y: 0, width: 380, height: 150))
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    var onClick: (() -> Void)?
    var hover = false
    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with e: NSEvent) { hover = true; needsDisplay = true }
    override func mouseExited(with e: NSEvent) { hover = false; needsDisplay = true }
    override func acceptsFirstMouse(for e: NSEvent?) -> Bool { true }
    override func mouseUp(with e: NSEvent) {
        enclosingMenuItem?.menu?.cancelTracking()
        onClick?()
    }

    @discardableResult
    func text(_ s: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular,
              color: NSColor = .labelColor, right: Bool = false, mono: Bool = false) -> CGFloat {
        let font = mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
        let a = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
        let w = a.size().width
        a.draw(at: NSPoint(x: right ? x - w : x, y: y))
        return w
    }

    func pill(_ s: String, _ x: CGFloat, _ y: CGFloat, _ color: NSColor) {
        let a = NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: 9, weight: .bold), .foregroundColor: color])
        let r = NSRect(x: x, y: y, width: a.size().width + 12, height: 15)
        color.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: r, xRadius: 7.5, yRadius: 7.5).fill()
        a.draw(at: NSPoint(x: x + 6, y: y + 2))
    }

    func bar(_ y: CGFloat, _ frac: Double, _ color: NSColor, mark: Double? = nil) {
        let r = NSRect(x: 18, y: y, width: bounds.width - 36, height: 9)
        NSColor.labelColor.withAlphaComponent(0.14).setFill()
        NSBezierPath(roundedRect: r, xRadius: 4.5, yRadius: 4.5).fill()
        var f = r; f.size.width = max(9, r.width * CGFloat(min(max(frac, 0), 1)))
        color.setFill()
        NSBezierPath(roundedRect: f, xRadius: 4.5, yRadius: 4.5).fill()
        if let m = mark {
            NSColor.labelColor.setFill()
            NSBezierPath(roundedRect: NSRect(x: r.minX + r.width * CGFloat(min(max(m, 0), 1)) - 1, y: y - 3, width: 2, height: 15), xRadius: 1, yRadius: 1).fill()
        }
    }

    func block(_ y: CGFloat, caption: String, right: String, util: Double?, sub: String, mark: Double?, fallback: Double, fallbackColor: NSColor) {
        let W = bounds.width
        text(caption, 18, y, size: 10, weight: .bold, color: .secondaryLabelColor)
        text(right, W - 18, y, size: 11, weight: .medium, color: .labelColor, right: true, mono: true)
        let col = util.map(sev) ?? fallbackColor
        bar(y + 20, util ?? fallback, col, mark: mark)
        if let u = util {
            let pct = min(100, Int((u * 100).rounded()))
            let w = text("\(pct)% usato", 18, y + 36, size: 12, weight: .semibold, color: col)
            if u >= 1 { text("  limite raggiunto", 18 + w, y + 36, size: 12, weight: .semibold, color: .systemRed) }
        } else {
            text("uso non disponibile", 18, y + 36, size: 12, color: .tertiaryLabelColor)
        }
        text(sub, W - 18, y + 37, size: 11, color: .secondaryLabelColor, right: true)
    }

    override func draw(_ dirtyRect: NSRect) {
        let W = bounds.width
        if hover {
            NSColor.labelColor.withAlphaComponent(0.08).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 8, yRadius: 8).fill()
        }
        let worst = max(c.weekUtil ?? 0, c.winUtil ?? 0)
        (c.weekUtil == nil && c.winUtil == nil ? NSColor.tertiaryLabelColor : sev(worst)).setFill()
        NSBezierPath(ovalIn: NSRect(x: 18, y: 11, width: 10, height: 10)).fill()
        let nw = text(c.name, 36, 7, size: 15, weight: .semibold)
        if c.isActive { pill("IN USO", 36 + nw + 8, 9, .systemBlue) }

        block(32, caption: "SETTIMANA",
              right: "reset tra \(fmt(c.weekLeft))  ·  \(c.weekDate)",
              util: c.weekUtil, sub: "\(Int(c.weekUsed * 100))% del tempo trascorso",
              mark: c.weekUtil != nil ? c.weekUsed : nil, fallback: c.weekUsed, fallbackColor: .systemGray)
        if let l = c.winLeft {
            block(92, caption: "SESSIONE 5 ORE",
                  right: c.winOpen ? "reset tra \(fmt(l))  ·  \(c.winClock ?? "")" : "riparte tra \(fmt(l))  ·  \(c.winClock ?? "")",
                  util: c.winUtil, sub: c.winOpen ? "finestra aperta" : "finestra scaduta", mark: nil, fallback: 0, fallbackColor: .systemGray)
        }
    }
}

// ---- Server selection (hosts are tailnet IPs) ----
struct Server: Decodable {
    let name: String; let host: String        // host = tailnet IP (100.x.y.z) or name
    let user: String?; let key: String?       // ssh user, optional private key
    let sudo: Bool?                           // run claude-switch-remote through sudo
    let remoteSwitch: Bool?                   // card clicks switch the account ON this server
}
let serversPath = NSString(string: "~/ClaudeResetWidget/servers.json").expandingTildeInPath
let selectedPath = NSString(string: "~/ClaudeResetWidget/server_selected.txt").expandingTildeInPath

func loadServers() -> [Server] {
    guard let d = FileManager.default.contents(atPath: serversPath),
          let l = try? JSONDecoder().decode([Server].self, from: d) else { return [] }
    return l
}
func selectedServer() -> Server? {
    let l = loadServers(); if l.isEmpty { return nil }
    let n = (try? String(contentsOfFile: selectedPath, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
    return l.first { $0.name == n } ?? l[0]
}
func remoteServer() -> Server? { let s = selectedServer(); return s?.remoteSwitch == true ? s : nil }

func sshRun(_ sv: Server, _ cmd: String) -> String? {
    var a = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=5"]
    if let k = sv.key { a += ["-i", NSString(string: k).expandingTildeInPath, "-o", "IdentitiesOnly=yes"] }
    a += [(sv.user.map { $0 + "@" } ?? "") + sv.host, cmd]
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh"); p.arguments = a
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
    do { try p.run() } catch { return nil }
    let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
    return p.terminationStatus == 0 ? String(data: d, encoding: .utf8) : nil
}
func switchCmd(_ sv: Server, _ args: String) -> String {
    (sv.sudo == true ? "sudo " : "") + "/usr/local/bin/claude-switch-remote \(args)"
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

    var usage: [String: Usage] = [:]
    func fetchUsage() {
        guard let srv = selectedServer() else { return }
        DispatchQueue.global().async { [weak self] in
            guard let out = sshRun(srv, "grep -H '' /var/lib/buongiorno/usage/*.json") else { return }
            var res: [String: Usage] = [:]
            for line in out.split(separator: "\n") {
                guard let c = line.firstIndex(of: ":") else { continue }
                let name = ((String(line[..<c]) as NSString).lastPathComponent as NSString).deletingPathExtension
                guard let j = try? JSONSerialization.jsonObject(with: Data(line[line.index(after: c)...].utf8)) as? [String: Any] else { continue }
                func w(_ k: String) -> (Double?, Date?) {
                    guard let m = j[k] as? [String: Any] else { return (nil, nil) }
                    return (m["utilization"] as? Double, (m["resetsAt"] as? Double).map { Date(timeIntervalSince1970: $0) })
                }
                let f = w("five_hour"), s7 = w("seven_day")
                res[name] = Usage(fiveUtil: f.0, fiveReset: f.1, weekUtil: s7.0, weekReset: s7.1,
                                  updated: Date(timeIntervalSince1970: (j["updated"] as? Double) ?? 0))
            }
            DispatchQueue.main.async {
                guard let s = self, selectedServer()?.name == srv.name else { return }
                if "\(res)" != "\(s.usage)" { s.usage = res; s.refresh(fetch: false) }
            }
        }
    }

    var remoteList: [(String, Bool)] = []
    func fetchRemote() {
        guard let srv = remoteServer() else { return }
        DispatchQueue.global().async { [weak self] in
            guard let out = sshRun(srv, switchCmd(srv, "list")) else { return }
            let list = out.split(separator: "\n").map { l -> (String, Bool) in
                let t = String(l); return (t.dropFirst(2).trimmingCharacters(in: .whitespaces), t.hasPrefix("*")) }
            DispatchQueue.main.async {
                guard let s = self, remoteServer()?.name == srv.name else { return }
                if list.map({ "\($0.0)\($0.1)" }) != s.remoteList.map({ "\($0.0)\($0.1)" }) { s.remoteList = list; s.refresh(fetch: false) }
            }
        }
    }
    @objc func switchRemote(_ s: NSMenuItem) {
        guard let name = s.representedObject as? String, let srv = remoteServer() else { return }
        DispatchQueue.global().async { [weak self] in
            _ = sshRun(srv, switchCmd(srv, name))
            DispatchQueue.main.async { self?.fetchRemote() }
        }
    }

    // Stato online dei nodi del tailnet (CLI di Tailscale), chiave = IP tailnet
    var tsOnline: [String: Bool] = [:]
    func fetchTailscale() {
        DispatchQueue.global().async { [weak self] in
            let paths = ["/Applications/Tailscale.app/Contents/MacOS/Tailscale", "/usr/local/bin/tailscale", "/opt/homebrew/bin/tailscale"]
            guard let bin = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return }
            let p = Process(); p.executableURL = URL(fileURLWithPath: bin); p.arguments = ["status", "--json"]
            let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
            do { try p.run() } catch { return }
            let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
            guard let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let peers = j["Peer"] as? [String: Any] else { return }
            var m: [String: Bool] = [:]
            for (_, v) in peers {
                guard let n = v as? [String: Any], let ips = n["TailscaleIPs"] as? [String] else { continue }
                for ip in ips { m[ip] = (n["Online"] as? Bool) ?? false }
            }
            DispatchQueue.main.async { guard let s = self else { return }; if m != s.tsOnline { s.tsOnline = m; s.refresh(fetch: false) } }
        }
    }
    @objc func selectServer(_ s: NSMenuItem) {
        guard let n = s.representedObject as? String else { return }
        try? n.write(toFile: selectedPath, atomically: true, encoding: .utf8)
        usage = [:]; remoteList = []
        refresh()
    }

    // Barra a batteria dell'account in uso: sopra la sessione 5h, sotto la settimana.
    func statusImage(_ it: (String, Double?, Double?)) -> NSImage {
        let bw: CGFloat = 90, H: CGFloat = 22
        let lab = NSAttributedString(string: it.0, attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                                                                 .foregroundColor: NSColor.labelColor.withAlphaComponent(0.85)])
        let lw = ceil(lab.size().width)
        let img = NSImage(size: NSSize(width: lw + 8 + bw + 4, height: H), flipped: false) { _ in
            lab.draw(at: NSPoint(x: 0, y: (H - lab.size().height) / 2))
            let x0 = lw + 8
            let r = NSRect(x: x0, y: 9, width: bw, height: 11)
            NSColor.labelColor.withAlphaComponent(0.7).setStroke()
            let outline = NSBezierPath(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3); outline.lineWidth = 1; outline.stroke()
            NSColor.labelColor.withAlphaComponent(0.7).setFill()
            NSBezierPath(rect: NSRect(x: r.maxX, y: 12.5, width: 1.6, height: 4)).fill()
            if let f = it.1 {
                sev(f).setFill()
                let inner = r.insetBy(dx: 2, dy: 2)
                NSBezierPath(roundedRect: NSRect(x: inner.minX, y: inner.minY, width: max(2, inner.width * CGFloat(min(f, 1))), height: inner.height), xRadius: 1.5, yRadius: 1.5).fill()
            }
            let t = NSRect(x: x0, y: 3, width: bw, height: 3.5)
            NSColor.labelColor.withAlphaComponent(0.2).setFill()
            NSBezierPath(roundedRect: t, xRadius: 1.75, yRadius: 1.75).fill()
            if let w = it.2 {
                sev(w).setFill()
                NSBezierPath(roundedRect: NSRect(x: t.minX, y: t.minY, width: max(3, t.width * CGFloat(min(w, 1))), height: t.height), xRadius: 1.75, yRadius: 1.75).fill()
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    func refresh(fetch: Bool = true) {
        if fetch { fetchRemote(); fetchUsage(); fetchTailscale() }
        let now = Date()
        var activeName: String? = nil
        if remoteServer() != nil { activeName = remoteList.first { $0.1 }?.0 }
        else {
            let cur = currentVSCodeDir()
            activeName = loadAccounts().first { a in
                let d = a.configDir.map { NSString(string: $0).expandingTildeInPath }
                return d == cur }?.name
        }
        let rows = loadAccounts().map { ($0, nextReset($0.anchor, now: now)) }.sorted { $0.1 < $1.1 }
        let m = NSMenu()
        var nextWindow: (String, Date)? = nil
        for (i, r) in rows.enumerated() {
            let (a, reset) = r
            let left = reset.timeIntervalSince(now)
            let u = usage[a.name]
            var card = Card(name: a.name, weekLeft: left, weekDate: df.string(from: reset), weekUsed: 1 - left / week,
                            isActive: a.name == activeName, weekUtil: nil, winUtil: nil, winLeft: nil, winClock: nil, winOpen: false)
            if let u = u {
                if let wr = u.weekReset, wr > now { card.weekUtil = u.weekUtil }
                if let fr = u.fiveReset, fr > now { card.winUtil = u.fiveUtil }
            }
            if let off = a.offset {
                let base = cycleBase.addingTimeInterval(Double(off) * 60)
                let start = base.addingTimeInterval(floor(now.timeIntervalSince(base) / cycle) * cycle)
                var end = start.addingTimeInterval(windowLen)
                if let fr = u?.fiveReset, fr > now { end = fr }          // dato reale, se disponibile
                let nextSend = start.addingTimeInterval(cycle)
                if now < end {
                    card.winOpen = true; card.winLeft = end.timeIntervalSince(now); card.winClock = hm.string(from: end)
                    if nextWindow == nil || end < nextWindow!.1 { nextWindow = (a.name, end) }
                } else {
                    card.winLeft = nextSend.timeIntervalSince(now); card.winClock = hm.string(from: nextSend)
                    if nextWindow == nil || nextSend < nextWindow!.1 { nextWindow = (a.name, nextSend) }
                }
            }
            let mi = NSMenuItem()
            let cv = CardView(card)
            cv.onClick = { [weak self] in self?.pick(a.name) }
            mi.view = cv
            m.addItem(mi)
            if i < rows.count - 1 { m.addItem(.separator()) }
        }
        // Selettore server (IP del tailnet)
        m.addItem(.separator())
        let svs = loadServers()
        if !svs.isEmpty {
            let cur = selectedServer()
            let sm = NSMenu()
            for sv in svs {
                let dot = tsOnline[sv.host].map { $0 ? "●" : "○" } ?? "·"
                let it = NSMenuItem(title: "\(dot)  \(sv.name)   \(sv.host)", action: #selector(selectServer(_:)), keyEquivalent: "")
                it.target = self; it.representedObject = sv.name; it.state = sv.name == cur?.name ? .on : .off
                sm.addItem(it)
            }
            let sp = NSMenuItem(title: "Server: \(cur?.name ?? "-")  (\(cur?.host ?? ""))", action: nil, keyEquivalent: "")
            sp.submenu = sm; m.addItem(sp)
        }
        // Selettore account per VS Code
        let cur = currentVSCodeDir()
        let sub = NSMenu()
        if remoteServer() != nil {
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
        let parent = NSMenuItem(title: remoteServer() != nil ? "Account Claude sul server" : "Account VS Code", action: nil, keyEquivalent: "")
        parent.submenu = sub; m.addItem(parent)
        var title = "⏳ nessun account"
        if let first = rows.first {
            title = "⏳ \(first.0.name) \(fmt(first.1.timeIntervalSince(now)))"
            if let w = nextWindow { title += "  ⟳ \(w.0) \(fmt(w.1.timeIntervalSince(now)))" }
        }
        let now2 = Date()
        let shown = loadAccounts().first { $0.name == activeName } ?? loadAccounts().first
        if let a = shown, !usage.isEmpty {
            let u = usage[a.name]
            let five = (u?.fiveReset ?? .distantPast) > now2 ? u?.fiveUtil : nil
            let wk = (u?.weekReset ?? .distantPast) > now2 ? u?.weekUtil : nil
            item.button?.title = ""; item.button?.image = statusImage((a.name, five, wk))
        } else { item.button?.image = nil; item.button?.title = title }
        item.button?.toolTip = title
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

    // Clic su una scheda = stessa azione di "Account VS Code -> nome"
    func pick(_ name: String) {
        let it = NSMenuItem(); it.representedObject = name
        if remoteServer() != nil { switchRemote(it) } else { switchAccount(it) }
    }

    @objc func openConfig() { NSWorkspace.shared.open(URL(fileURLWithPath: configPath)) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
