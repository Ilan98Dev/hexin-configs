.pragma library

// Shared helpers for the launcher and Spotlight.
//
// Keeping the scoring and the maths parser here means both panels rank the
// same app the same way, and there is exactly one expression evaluator to fix
// when something like 2^-3 turns up.

// ───────────── app matching ─────────────

function keywordsOf(app) {
    const k = app.keywords;
    if (!k)
        return "";
    return Array.isArray(k) ? k.join(" ").toLowerCase() : String(k).toLowerCase();
}

/// Higher is better; 0 means "no match".
function scoreApp(app, q) {
    const name = String(app.name).toLowerCase();
    const generic = String(app.genericName).toLowerCase();
    const comment = String(app.comment).toLowerCase();
    const keywords = keywordsOf(app);

    if (name === q)
        return 100;
    if (name.startsWith(q))
        return 90;
    if (name.includes(q))
        return 70;
    if (generic.startsWith(q))
        return 60;
    if (generic.includes(q))
        return 45;
    if (keywords.includes(q))
        return 35;
    if (comment.includes(q))
        return 20;
    return 0;
}

// ───────────── quick maths ─────────────

/// Returns { value, text } when `input` is a complete arithmetic expression,
/// otherwise null. Deliberately strict: bare numbers and anything with a
/// letter in it (other than nothing) are not maths.
function evaluate(input) {
    let src = String(input == null ? "" : input).trim();
    src = src.replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-").replace(/,/g, "");
    if (!/[0-9]/.test(src))
        return null;
    if (!/[+\-*/%^]/.test(src))
        return null;
    if (!/^[0-9+\-*/%^().\s]+$/.test(src))
        return null;

    let value;
    try {
        const p = new Parser(src);
        value = p.expression();
        if (!p.atEnd())
            return null;
    } catch (e) {
        return null;
    }
    if (typeof value !== "number" || !isFinite(value))
        return null;
    return {
        value: value,
        text: formatNumber(value)
    };
}

function formatNumber(v) {
    if (Object.is(v, -0))
        v = 0;
    if (Number.isInteger(v) && Math.abs(v) < 1e15)
        return String(v);
    const s = String(Number(v.toPrecision(12)));
    return s === "NaN" || s === "Infinity" ? "" : s;
}

function Parser(text) {
    this.t = text;
    this.i = 0;
}

Parser.prototype.ws = function () {
    while (this.i < this.t.length && /\s/.test(this.t.charAt(this.i)))
        this.i++;
};

Parser.prototype.atEnd = function () {
    this.ws();
    return this.i >= this.t.length;
};

Parser.prototype.take = function () {
    this.ws();
    return this.t.charAt(this.i);
};

Parser.prototype.expression = function () {
    let v = this.term();
    for (;;) {
        const c = this.take();
        if (c === "+") {
            this.i++;
            v += this.term();
        } else if (c === "-") {
            this.i++;
            v -= this.term();
        } else {
            return v;
        }
    }
};

Parser.prototype.term = function () {
    let v = this.unary();
    for (;;) {
        const c = this.take();
        if (c === "*") {
            this.i++;
            v *= this.unary();
        } else if (c === "/") {
            this.i++;
            v /= this.unary();
        } else if (c === "%") {
            this.i++;
            v %= this.unary();
        } else {
            return v;
        }
    }
};

Parser.prototype.unary = function () {
    const c = this.take();
    if (c === "-") {
        this.i++;
        return -this.unary();
    }
    if (c === "+") {
        this.i++;
        return this.unary();
    }
    return this.power();
};

// Right-associative, and binds tighter than unary minus: -2^2 = -4.
Parser.prototype.power = function () {
    const base = this.primary();
    if (this.take() === "^") {
        this.i++;
        return Math.pow(base, this.unary());
    }
    return base;
};

Parser.prototype.primary = function () {
    this.ws();
    if (this.t.charAt(this.i) === "(") {
        this.i++;
        const v = this.expression();
        this.ws();
        if (this.t.charAt(this.i) !== ")")
            throw new Error("unbalanced");
        this.i++;
        return v;
    }
    const start = this.i;
    while (this.i < this.t.length && /[0-9.]/.test(this.t.charAt(this.i)))
        this.i++;
    if (start === this.i)
        throw new Error("expected number");
    const n = Number(this.t.slice(start, this.i));
    if (isNaN(n))
        throw new Error("bad number");
    return n;
};

// ───────────── the web ─────────────

/// "zen-browser" -> "Zen", "firefox" -> "Firefox".
function browserLabel(command) {
    const bin = String(command || "").trim().split(/\s+/)[0].split("/").pop();
    if (!bin)
        return "the browser";
    const base = bin.replace(/-browser$/, "").replace(/^zen$/, "zen");
    return base.charAt(0).toUpperCase() + base.slice(1);
}

/// A single token that is either an explicit URL or looks like a domain.
function looksLikeUrl(q) {
    const s = String(q || "").trim();
    if (!s || /\s/.test(s))
        return false;
    if (/^https?:\/\/\S+$/i.test(s))
        return true;
    // Require a letter in the host so "2.5" stays maths, not a website.
    return /^(?=.*[a-z])[\w-]+(\.[\w-]+)+(\/\S*)?$/i.test(s);
}

function webUrl(q) {
    const s = String(q || "").trim();
    if (/^https?:\/\//i.test(s))
        return s;
    if (looksLikeUrl(s))
        return "https://" + s;
    return "https://duckduckgo.com/?q=" + encodeURIComponent(s);
}

// ───────────── files ─────────────

/// The find(1) command behind the file rows. Bounded depth, common folders
/// only, and the wallpaper folder is skipped so a huge collection never slows
/// a search down.
function fileSearchScript(q, home) {
    const dirs = ["Desktop", "Documents", "Downloads", "Pictures", "Projects", "Videos", "Music"]
        .map(d => shellQuote(home + "/" + d))
        .join(" ");
    return "for d in " + dirs + "; do "
        + "[ -d \"$d\" ] || continue; "
        + "find \"$d\" -maxdepth 4 "
        + "-not -path " + shellQuote(home + "/Pictures/Wallpapers/*") + " "
        + "-not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/__pycache__/*' "
        + "-iname " + shellQuote("*" + q + "*") + " 2>/dev/null; "
        + "done | head -n 60";
}

function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

/// "/home/you/Documents/a/b.pdf" -> "~/Documents/a"
function parentDir(path, home) {
    const cut = String(path).lastIndexOf("/");
    if (cut <= 0)
        return path;
    const dir = String(path).slice(0, cut);
    if (home && dir.startsWith(home))
        return "~" + dir.slice(home.length);
    return dir;
}

function baseName(path) {
    return String(path).split("/").pop();
}
