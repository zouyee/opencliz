//! 可选内置 HTML → Markdown（阶段 E）：标题/段落/列表/`<br>`/`<a>`/`<pre>` 围栏代码/`<blockquote>` 引用；
//! 行内 **`<strong>`/`b`**、*`<em>`/`i`*、`` `<code>` ``、`~~del/s/strike~~`、`![alt](src)`；与 Turndown 不兼容。
const std = @import("std");

fn startsWithCi(hay: []const u8, needle: []const u8) bool {
    return hay.len >= needle.len and std.ascii.eqlIgnoreCase(hay[0..needle.len], needle);
}

fn appendDecoded(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) error{OutOfMemory}!void {
    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '&') {
            if (std.mem.indexOfScalarPos(u8, text, i + 1, ';')) |semi_rel| {
                const semi = i + 1 + semi_rel;
                const ent = text[i + 1 .. semi];
                if (std.mem.eql(u8, ent, "amp")) {
                    try out.append(allocator, '&');
                } else if (std.mem.eql(u8, ent, "lt")) {
                    try out.append(allocator, '<');
                } else if (std.mem.eql(u8, ent, "gt")) {
                    try out.append(allocator, '>');
                } else if (std.mem.eql(u8, ent, "quot")) {
                    try out.append(allocator, '"');
                } else if (std.mem.eql(u8, ent, "nbsp")) {
                    try out.append(allocator, ' ');
                } else {
                    try out.appendSlice(allocator, text[i .. semi + 1]);
                }
                i = semi + 1;
                continue;
            }
        }
        try out.append(allocator, text[i]);
        i += 1;
    }
}

fn closesWithName(html: []const u8, i: usize, name: []const u8) ?usize {
    if (!startsWithCi(html[i..], "</")) return null;
    var j = i + 2;
    while (j < html.len and std.ascii.isWhitespace(html[j])) j += 1;
    if (j + name.len > html.len) return null;
    if (!std.ascii.eqlIgnoreCase(html[j .. j + name.len], name)) return null;
    j += name.len;
    while (j < html.len and html[j] != '>') j += 1;
    if (j >= html.len or html[j] != '>') return null;
    return j + 1;
}

fn findCloseTag(html: []const u8, from: usize, name: []const u8) ?struct { lt: usize, after: usize } {
    var i = from;
    while (i < html.len) {
        if (html[i] == '<') {
            if (closesWithName(html, i, name)) |after| {
                return .{ .lt = i, .after = after };
            }
        }
        i += 1;
    }
    return null;
}

fn tryConsumeComment(html: []const u8, pos: *usize) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<!--")) return false;
    if (std.mem.indexOf(u8, html[pos.*..], "-->")) |rel| {
        pos.* += rel + "-->".len;
        return true;
    }
    return false;
}

fn tryConsumeBr(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<br")) return false;
    var j = pos.* + 3;
    while (j < html.len and std.ascii.isWhitespace(html[j])) j += 1;
    if (j < html.len and html[j] == '/') j += 1;
    while (j < html.len and std.ascii.isWhitespace(html[j])) j += 1;
    if (j >= html.len or html[j] != '>') return false;
    pos.* = j + 1;
    try out.append(allocator, '\n');
    return true;
}

/// `<hr>` → Markdown 水平线（`---`）。
fn tryConsumeHr(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<hr")) return false;
    var j = pos.* + 3;
    while (j < html.len and std.ascii.isWhitespace(html[j])) j += 1;
    if (j < html.len and html[j] == '/') j += 1;
    while (j < html.len and std.ascii.isWhitespace(html[j])) j += 1;
    if (j >= html.len or html[j] != '>') return false;
    pos.* = j + 1;
    try out.appendSlice(allocator, "\n---\n\n");
    return true;
}

fn extractRowCells(allocator: std.mem.Allocator, row_html: []const u8) error{OutOfMemory}!struct { cells: [][]const u8, all_th: bool } {
    var list: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (list.items) |c| allocator.free(c);
        list.deinit(allocator);
    }
    var p: usize = 0;
    var all_th = true;
    var any = false;
    while (p < row_html.len) {
        if (row_html[p] != '<') {
            p += 1;
            continue;
        }
        const is_th = startsWithCi(row_html[p..], "<th");
        const is_td = startsWithCi(row_html[p..], "<td");
        if (!is_th and !is_td) {
            p += 1;
            continue;
        }
        any = true;
        const tag: []const u8 = if (is_th) "th" else "td";
        if (is_td) all_th = false;
        const gt = std.mem.indexOfScalarPos(u8, row_html, p + 3, '>') orelse {
            p += 1;
            continue;
        };
        const inner_start = gt + 1;
        const cl = findCloseTag(row_html, inner_start, tag) orelse break;
        const cell_inner = row_html[inner_start..cl.lt];
        const cell_md = try convertInlineFragment(allocator, cell_inner);
        try list.append(allocator, cell_md);
        p = cl.after;
    }
    if (!any) {
        list.deinit(allocator);
        return .{ .cells = &[_][]const u8{}, .all_th = false };
    }
    return .{ .cells = try list.toOwnedSlice(allocator), .all_th = all_th };
}

/// 极简 `<table>`：仅 `<tr>` / `<th>` / `<td>`；首行若**均为** `<th>` 则输出 GFM 表头分隔行。
fn tryConsumeTable(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<table")) return false;
    const after_tag = pos.* + 6;
    if (after_tag >= html.len) return false;
    {
        const c = html[after_tag];
        if (c != '>' and c != '/' and !std.ascii.isWhitespace(c)) return false;
    }
    const gt = std.mem.indexOfScalarPos(u8, html, after_tag, '>') orelse return false;
    const content_start = gt + 1;
    const close = findCloseTag(html, content_start, "table") orelse return false;
    const inner = html[content_start..close.lt];
    pos.* = close.after;

    var rows_cells: std.ArrayList([][]const u8) = .empty;
    defer {
        for (rows_cells.items) |row| {
            for (row) |c| allocator.free(c);
            allocator.free(row);
        }
        rows_cells.deinit(allocator);
    }
    var header_row: std.ArrayList(bool) = .empty;
    defer header_row.deinit(allocator);

    var p2: usize = 0;
    while (p2 < inner.len) {
        if (inner[p2] != '<') {
            p2 += 1;
            continue;
        }
        if (!startsWithCi(inner[p2..], "<tr")) {
            p2 += 1;
            continue;
        }
        const tr_gt = std.mem.indexOfScalarPos(u8, inner, p2 + 3, '>') orelse {
            p2 += 1;
            continue;
        };
        const r_start = tr_gt + 1;
        const tr_close = findCloseTag(inner, r_start, "tr") orelse break;
        const row_inner = inner[r_start..tr_close.lt];
        p2 = tr_close.after;

        const parsed = try extractRowCells(allocator, row_inner);
        if (parsed.cells.len == 0) continue;
        try rows_cells.append(allocator, parsed.cells);
        try header_row.append(allocator, parsed.all_th);
    }

    if (rows_cells.items.len == 0) return true;

    const first_is_header = header_row.items[0];
    try out.append(allocator, '\n');
    for (rows_cells.items, 0..) |row, ri| {
        try out.append(allocator, '|');
        for (row) |cell| {
            try out.append(allocator, ' ');
            try out.appendSlice(allocator, std.mem.trim(u8, cell, " \t\r\n"));
            try out.appendSlice(allocator, " |");
        }
        try out.append(allocator, '\n');
        if (ri == 0 and first_is_header) {
            try out.append(allocator, '|');
            for (row) |_| {
                try out.appendSlice(allocator, " --- |");
            }
            try out.append(allocator, '\n');
        }
    }
    try out.append(allocator, '\n');
    return true;
}

fn tryConsumeHeading(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (pos.* + 3 > html.len) return false;
    if (!startsWithCi(html[pos.*..], "<h")) return false;
    const digit = html[pos.* + 2];
    if (digit < '1' or digit > '6') return false;
    const level: usize = @intCast(digit - '0');
    const gt = std.mem.indexOfScalarPos(u8, html, pos.* + 3, '>') orelse return false;
    const content_start = gt + 1;
    var tag_name: [2]u8 = .{ 'h', digit };
    const close = findCloseTag(html, content_start, tag_name[0..2]) orelse return false;
    const inner = html[content_start..close.lt];
    pos.* = close.after;

    const md = try convertInlineFragment(allocator, inner);
    defer allocator.free(md);

    try out.append(allocator, '\n');
    for (0..level) |_| try out.append(allocator, '#');
    try out.append(allocator, ' ');
    try out.appendSlice(allocator, std.mem.trim(u8, md, " \t\r\n"));
    try out.appendSlice(allocator, "\n\n");
    return true;
}

/// `<pre>` → Markdown 围栏代码块（内文做实体解码，保留换行）。
fn tryConsumePre(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<pre")) return false;
    if (html.len - pos.* > 4) {
        const c = html[pos.* + 4];
        if (c != '>' and !std.ascii.isWhitespace(c)) return false;
    }
    const gt = std.mem.indexOfScalarPos(u8, html, pos.* + 4, '>') orelse return false;
    const content_start = gt + 1;
    const close = findCloseTag(html, content_start, "pre") orelse return false;
    const inner = html[content_start..close.lt];
    pos.* = close.after;
    try out.appendSlice(allocator, "\n```\n");
    try appendDecoded(allocator, out, inner);
    try out.appendSlice(allocator, "\n```\n\n");
    return true;
}

/// `<blockquote>` → 每行前加 `> `（内文先行内 Markdown 化）。
fn tryConsumeBlockquote(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<blockquote")) return false;
    if (html.len - pos.* > 11) {
        const c = html[pos.* + 11];
        if (c != '>' and !std.ascii.isWhitespace(c)) return false;
    }
    const gt = std.mem.indexOfScalarPos(u8, html, pos.* + 11, '>') orelse return false;
    const content_start = gt + 1;
    const close = findCloseTag(html, content_start, "blockquote") orelse return false;
    const inner = html[content_start..close.lt];
    pos.* = close.after;

    const md = try convertInlineFragment(allocator, inner);
    defer allocator.free(md);

    try out.append(allocator, '\n');
    var it = std.mem.splitScalar(u8, md, '\n');
    while (it.next()) |line| {
        const t = std.mem.trimRight(u8, line, "\r");
        try out.appendSlice(allocator, "> ");
        try out.appendSlice(allocator, std.mem.trim(u8, t, " \t"));
        try out.append(allocator, '\n');
    }
    try out.append(allocator, '\n');
    return true;
}

fn tryConsumeParagraph(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<p")) return false;
    if (html[pos.* + 2] != '>' and !std.ascii.isWhitespace(html[pos.* + 2])) return false;
    const gt = std.mem.indexOfScalarPos(u8, html, pos.* + 2, '>') orelse return false;
    const content_start = gt + 1;
    const close = findCloseTag(html, content_start, "p") orelse return false;
    const inner = html[content_start..close.lt];
    pos.* = close.after;

    const md = try convertInlineFragment(allocator, inner);
    defer allocator.free(md);
    try out.appendSlice(allocator, std.mem.trim(u8, md, " \t\r\n"));
    try out.appendSlice(allocator, "\n\n");
    return true;
}

fn tryConsumeListItem(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<li")) return false;
    if (html.len - pos.* > 3 and html[pos.* + 3] != '>' and !std.ascii.isWhitespace(html[pos.* + 3])) return false;
    const gt = std.mem.indexOfScalarPos(u8, html, pos.* + 3, '>') orelse return false;
    const content_start = gt + 1;
    const close = findCloseTag(html, content_start, "li") orelse return false;
    const inner = html[content_start..close.lt];
    pos.* = close.after;

    const md = try convertInlineFragment(allocator, inner);
    defer allocator.free(md);
    try out.appendSlice(allocator, "- ");
    try out.appendSlice(allocator, std.mem.trim(u8, md, " \t\r\n"));
    try out.append(allocator, '\n');
    return true;
}

/// 行内 `` ` ``：若含反引号则用 GFM 双反引号包裹（两侧各加空格以界定）。
fn appendInlineCodeDecoded(allocator: std.mem.Allocator, out: *std.ArrayList(u8), inner: []const u8) error{OutOfMemory}!void {
    if (std.mem.indexOfScalar(u8, inner, '`') == null) {
        try out.append(allocator, '`');
        try appendDecoded(allocator, out, inner);
        try out.append(allocator, '`');
        return;
    }
    try out.appendSlice(allocator, " `` ");
    try appendDecoded(allocator, out, inner);
    try out.appendSlice(allocator, " `` ");
}

fn openTagEnd(html: []const u8, from: usize) ?usize {
    return std.mem.indexOfScalarPos(u8, html, from, '>');
}

/// `<strong>` / `<b>`（排除 `<blockquote` 误匹配）。
fn tryInlineStrong(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (startsWithCi(html[pos.*..], "<strong")) {
        const gt = openTagEnd(html, pos.* + 7) orelse return false;
        const start = gt + 1;
        const cl = findCloseTag(html, start, "strong") orelse return false;
        const inner = html[start..cl.lt];
        pos.* = cl.after;
        try out.appendSlice(allocator, "**");
        try convertInlineInto(allocator, inner, out);
        try out.appendSlice(allocator, "**");
        return true;
    }
    if (startsWithCi(html[pos.*..], "<b")) {
        const after_b = pos.* + 2;
        if (after_b < html.len) {
            const c = html[after_b];
            if (c == 'l') return false; // blockquote
            if (c != '>' and c != '/' and !std.ascii.isWhitespace(c)) return false;
        }
        const gt = openTagEnd(html, after_b) orelse return false;
        const start = gt + 1;
        const cl = findCloseTag(html, start, "b") orelse return false;
        const inner = html[start..cl.lt];
        pos.* = cl.after;
        try out.appendSlice(allocator, "**");
        try convertInlineInto(allocator, inner, out);
        try out.appendSlice(allocator, "**");
        return true;
    }
    return false;
}

fn tryInlineEm(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (startsWithCi(html[pos.*..], "<em")) {
        const gt = openTagEnd(html, pos.* + 3) orelse return false;
        const start = gt + 1;
        const cl = findCloseTag(html, start, "em") orelse return false;
        const inner = html[start..cl.lt];
        pos.* = cl.after;
        try out.append(allocator, '*');
        try convertInlineInto(allocator, inner, out);
        try out.append(allocator, '*');
        return true;
    }
    if (startsWithCi(html[pos.*..], "<i")) {
        const after = pos.* + 2;
        if (after >= html.len) return false;
        const c = html[after];
        if (c != '>' and c != '/' and !std.ascii.isWhitespace(c)) return false; // 排除 `<img` / `<iframe` 等
        const gt = openTagEnd(html, after) orelse return false;
        const start = gt + 1;
        const cl = findCloseTag(html, start, "i") orelse return false;
        const inner = html[start..cl.lt];
        pos.* = cl.after;
        try out.append(allocator, '*');
        try convertInlineInto(allocator, inner, out);
        try out.append(allocator, '*');
        return true;
    }
    return false;
}

fn tryInlineCode(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<code")) return false;
    if (html.len - pos.* > 5) {
        const c = html[pos.* + 5];
        if (c != '>' and !std.ascii.isWhitespace(c)) return false;
    }
    const gt = std.mem.indexOfScalarPos(u8, html, pos.* + 5, '>') orelse return false;
    const start = gt + 1;
    const cl = findCloseTag(html, start, "code") orelse return false;
    const inner = html[start..cl.lt];
    pos.* = cl.after;
    try appendInlineCodeDecoded(allocator, out, inner);
    return true;
}

fn tryInlineDel(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (startsWithCi(html[pos.*..], "<del")) {
        const gt = openTagEnd(html, pos.* + 4) orelse return false;
        const start = gt + 1;
        const cl = findCloseTag(html, start, "del") orelse return false;
        const inner = html[start..cl.lt];
        pos.* = cl.after;
        try out.appendSlice(allocator, "~~");
        try convertInlineInto(allocator, inner, out);
        try out.appendSlice(allocator, "~~");
        return true;
    }
    if (startsWithCi(html[pos.*..], "<strike")) {
        const gt = openTagEnd(html, pos.* + 7) orelse return false;
        const start = gt + 1;
        const cl = findCloseTag(html, start, "strike") orelse return false;
        const inner = html[start..cl.lt];
        pos.* = cl.after;
        try out.appendSlice(allocator, "~~");
        try convertInlineInto(allocator, inner, out);
        try out.appendSlice(allocator, "~~");
        return true;
    }
    if (startsWithCi(html[pos.*..], "<s")) {
        const after = pos.* + 2;
        if (after >= html.len) return false;
        const c = html[after];
        if (c != '>' and c != '/' and !std.ascii.isWhitespace(c)) return false; // `<script` / `<span` 等
        const gt = openTagEnd(html, after) orelse return false;
        const start = gt + 1;
        const cl = findCloseTag(html, start, "s") orelse return false;
        const inner = html[start..cl.lt];
        pos.* = cl.after;
        try out.appendSlice(allocator, "~~");
        try convertInlineInto(allocator, inner, out);
        try out.appendSlice(allocator, "~~");
        return true;
    }
    return false;
}

fn attrQuotedValue(html: []const u8, key: []const u8) ?[]const u8 {
    var j: usize = 0;
    while (j < html.len) {
        if (std.ascii.toLower(html[j]) == std.ascii.toLower(key[0]) and j + key.len <= html.len and
            std.ascii.eqlIgnoreCase(html[j .. j + key.len], key) and
            (j + key.len >= html.len or html[j + key.len] == '=' or std.ascii.isWhitespace(html[j + key.len])))
        {
            var k = j + key.len;
            while (k < html.len and std.ascii.isWhitespace(html[k])) k += 1;
            if (k >= html.len or html[k] != '=') return null;
            k += 1;
            while (k < html.len and std.ascii.isWhitespace(html[k])) k += 1;
            if (k >= html.len) return null;
            const q = html[k];
            if (q != '"' and q != '\'') return null;
            k += 1;
            const v0 = k;
            while (k < html.len and html[k] != q) k += 1;
            if (k >= html.len) return null;
            return html[v0..k];
        }
        j += 1;
    }
    return null;
}

/// `<img ...>` / `<img .../>`（仅解析 **`src`**、**`alt`**）。
fn tryInlineImg(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<img")) return false;
    const gt = std.mem.indexOfScalarPos(u8, html, pos.* + 4, '>') orelse return false;
    const tag_inner = html[pos.* + 4 .. gt];
    const src = attrQuotedValue(tag_inner, "src") orelse return false;
    const alt = attrQuotedValue(tag_inner, "alt") orelse "";
    pos.* = gt + 1;
    try out.appendSlice(allocator, "![");
    const alt_esc = try escapeLinkText(allocator, alt);
    defer allocator.free(alt_esc);
    try out.appendSlice(allocator, alt_esc);
    try out.appendSlice(allocator, "](");
    try out.appendSlice(allocator, src);
    try out.append(allocator, ')');
    return true;
}

fn tryInlineBr(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<br")) return false;
    var j = pos.* + 3;
    while (j < html.len and std.ascii.isWhitespace(html[j])) j += 1;
    if (j < html.len and html[j] == '/') j += 1;
    while (j < html.len and std.ascii.isWhitespace(html[j])) j += 1;
    if (j >= html.len or html[j] != '>') return false;
    pos.* = j + 1;
    try out.append(allocator, '\n');
    return true;
}

fn tryInlineComment(html: []const u8, pos: *usize) error{OutOfMemory}!bool {
    return tryConsumeComment(html, pos);
}

/// 将一段 HTML 当作**行内**（可嵌套）转成 Markdown 写入 **`out`**。
fn convertInlineInto(allocator: std.mem.Allocator, html: []const u8, out: *std.ArrayList(u8)) error{OutOfMemory}!void {
    var pos: usize = 0;
    while (pos < html.len) {
        const lt = std.mem.indexOfScalarPos(u8, html, pos, '<') orelse {
            try appendDecoded(allocator, out, html[pos..]);
            break;
        };
        if (lt > pos) {
            try appendDecoded(allocator, out, html[pos..lt]);
        }
        pos = lt;
        if (try tryInlineComment(html, &pos)) continue;
        if (try tryInlineBr(allocator, html, &pos, out)) continue;
        if (try tryInlineImg(allocator, html, &pos, out)) continue;
        if (try tryInlineStrong(allocator, html, &pos, out)) continue;
        if (try tryInlineEm(allocator, html, &pos, out)) continue;
        if (try tryInlineCode(allocator, html, &pos, out)) continue;
        if (try tryInlineDel(allocator, html, &pos, out)) continue;
        if (try tryConsumeAnchorInFragment(allocator, html, &pos, out)) continue;
        const gt = std.mem.indexOfScalarPos(u8, html, pos + 1, '>') orelse {
            try out.append(allocator, '<');
            pos += 1;
            continue;
        };
        pos = gt + 1;
    }
}

/// 供 **`convertInlineInto`** 使用的 `<a href>`（与块级 **`tryConsumeAnchor`** 同逻辑，写入 **`out`**）。
fn tryConsumeAnchorInFragment(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<a")) return false;
    if (html.len - pos.* < 4) return false;
    const href_key = "href";
    var j = pos.* + 2;
    while (j < html.len and html[j] != '>') {
        if (std.ascii.toLower(html[j]) == 'h' and j + href_key.len < html.len and
            std.ascii.eqlIgnoreCase(html[j .. j + href_key.len], href_key) and
            (html[j + href_key.len] == '=' or std.ascii.isWhitespace(html[j + href_key.len])))
        {
            var k = j + href_key.len;
            while (k < html.len and std.ascii.isWhitespace(html[k])) k += 1;
            if (k >= html.len or html[k] != '=') return false;
            k += 1;
            while (k < html.len and std.ascii.isWhitespace(html[k])) k += 1;
            if (k >= html.len) return false;
            const q = html[k];
            if (q != '"' and q != '\'') return false;
            k += 1;
            const url_start = k;
            while (k < html.len and html[k] != q) k += 1;
            if (k >= html.len) return false;
            const href = html[url_start..k];
            k += 1;
            const gt = std.mem.indexOfScalarPos(u8, html, k, '>') orelse return false;
            const content_start = gt + 1;
            const close = findCloseTag(html, content_start, "a") orelse return false;
            const inner = html[content_start..close.lt];
            pos.* = close.after;

            var inner_out: std.ArrayList(u8) = .empty;
            defer inner_out.deinit(allocator);
            try convertInlineInto(allocator, inner, &inner_out);
            const inner_md = try inner_out.toOwnedSlice(allocator);
            defer allocator.free(inner_md);
            const esc = try escapeLinkText(allocator, inner_md);
            defer allocator.free(esc);
            try out.append(allocator, '[');
            try out.appendSlice(allocator, esc);
            try out.appendSlice(allocator, "](");
            try out.appendSlice(allocator, href);
            try out.append(allocator, ')');
            return true;
        }
        j += 1;
    }
    return false;
}

fn convertInlineFragment(allocator: std.mem.Allocator, html: []const u8) error{OutOfMemory}![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try convertInlineInto(allocator, html, &out);
    return try out.toOwnedSlice(allocator);
}

fn escapeLinkText(allocator: std.mem.Allocator, text: []const u8) error{OutOfMemory}![]const u8 {
    var b: std.ArrayList(u8) = .empty;
    defer b.deinit(allocator);
    for (text) |c| {
        switch (c) {
            '\\' => try b.appendSlice(allocator, "\\\\"),
            ']' => try b.appendSlice(allocator, "\\]"),
            else => try b.append(allocator, c),
        }
    }
    return try b.toOwnedSlice(allocator);
}

fn tryConsumeAnchor(allocator: std.mem.Allocator, html: []const u8, pos: *usize, out: *std.ArrayList(u8)) error{OutOfMemory}!bool {
    if (!startsWithCi(html[pos.*..], "<a")) return false;
    if (html.len - pos.* < 4) return false;
    const href_key = "href";
    var j = pos.* + 2;
    while (j < html.len and html[j] != '>') {
        if (std.ascii.toLower(html[j]) == 'h' and j + href_key.len < html.len and
            std.ascii.eqlIgnoreCase(html[j .. j + href_key.len], href_key) and
            (html[j + href_key.len] == '=' or std.ascii.isWhitespace(html[j + href_key.len])))
        {
            var k = j + href_key.len;
            while (k < html.len and std.ascii.isWhitespace(html[k])) k += 1;
            if (k >= html.len or html[k] != '=') return false;
            k += 1;
            while (k < html.len and std.ascii.isWhitespace(html[k])) k += 1;
            if (k >= html.len) return false;
            const q = html[k];
            if (q != '"' and q != '\'') return false;
            k += 1;
            const url_start = k;
            while (k < html.len and html[k] != q) k += 1;
            if (k >= html.len) return false;
            const href = html[url_start..k];
            k += 1;
            const gt = std.mem.indexOfScalarPos(u8, html, k, '>') orelse return false;
            const content_start = gt + 1;
            const close = findCloseTag(html, content_start, "a") orelse return false;
            const inner = html[content_start..close.lt];
            pos.* = close.after;

            const inner_md = try convertInlineFragment(allocator, inner);
            defer allocator.free(inner_md);
            const esc = try escapeLinkText(allocator, inner_md);
            defer allocator.free(esc);
            try out.append(allocator, '[');
            try out.appendSlice(allocator, esc);
            try out.appendSlice(allocator, "](");
            try out.appendSlice(allocator, href);
            try out.append(allocator, ')');
            return true;
        }
        j += 1;
    }
    return false;
}

fn collapseBlankLines(allocator: std.mem.Allocator, input: []const u8) error{OutOfMemory}![]const u8 {
    var r: std.ArrayList(u8) = .empty;
    defer r.deinit(allocator);
    var nl_run: u32 = 0;
    for (input) |c| {
        if (c == '\n') {
            nl_run += 1;
            if (nl_run <= 2) try r.append(allocator, '\n');
        } else {
            nl_run = 0;
            try r.append(allocator, c);
        }
    }
    const slice = try r.toOwnedSlice(allocator);
    const trimmed = std.mem.trim(u8, slice, " \t\r\n");
    const out_slice = try allocator.dupe(u8, trimmed);
    allocator.free(slice);
    return out_slice;
}

/// 将已去 script/style 的 HTML 转为简化 Markdown（不保证合法 HTML 的完备解析）。
pub fn convert(allocator: std.mem.Allocator, html: []const u8) error{OutOfMemory}![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    var pos: usize = 0;
    while (pos < html.len) {
        const lt = std.mem.indexOfScalarPos(u8, html, pos, '<') orelse {
            try appendDecoded(allocator, &out, html[pos..]);
            break;
        };
        if (lt > pos) {
            try appendDecoded(allocator, &out, html[pos..lt]);
        }
        pos = lt;
        if (try tryConsumeComment(html, &pos)) continue;
        if (try tryConsumeBr(allocator, html, &pos, &out)) continue;
        if (try tryConsumeHr(allocator, html, &pos, &out)) continue;
        if (try tryConsumeHeading(allocator, html, &pos, &out)) continue;
        if (try tryConsumePre(allocator, html, &pos, &out)) continue;
        if (try tryConsumeBlockquote(allocator, html, &pos, &out)) continue;
        if (try tryConsumeTable(allocator, html, &pos, &out)) continue;
        if (try tryConsumeParagraph(allocator, html, &pos, &out)) continue;
        if (try tryConsumeListItem(allocator, html, &pos, &out)) continue;
        if (try tryConsumeAnchor(allocator, html, &pos, &out)) continue;
        const gt = std.mem.indexOfScalarPos(u8, html, pos + 1, '>') orelse {
            try out.append(allocator, '<');
            pos += 1;
            continue;
        };
        pos = gt + 1;
    }
    return try collapseBlankLines(allocator, out.items);
}

test "simple heading paragraph link" {
    const a = std.testing.allocator;
    const html = "<h1>Title</h1><p>a &amp; b</p><a href=\"http://x\">L</a>";
    const md = try convert(a, html);
    defer a.free(md);
    try std.testing.expect(std.mem.indexOf(u8, md, "# Title") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "a & b") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "[L](http://x)") != null);
}

test "br and list item" {
    const a = std.testing.allocator;
    const html = "<ul><li>one</li><li>two<br/>x</li></ul>";
    const md = try convert(a, html);
    defer a.free(md);
    try std.testing.expect(std.mem.indexOf(u8, md, "- one") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "- two") != null);
}

test "pre to fenced code" {
    const a = std.testing.allocator;
    const html = "<p>x</p><pre>a &amp; b\nline2</pre>";
    const md = try convert(a, html);
    defer a.free(md);
    try std.testing.expect(std.mem.indexOf(u8, md, "```") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "a & b") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "line2") != null);
}

test "blockquote single paragraph" {
    const a = std.testing.allocator;
    const html = "<blockquote>quoted text</blockquote>";
    const md = try convert(a, html);
    defer a.free(md);
    try std.testing.expect(std.mem.indexOf(u8, md, "> quoted text") != null);
}

test "hr horizontal rule" {
    const a = std.testing.allocator;
    const html = "<p>a</p><hr/><p>b</p>";
    const md = try convert(a, html);
    defer a.free(md);
    try std.testing.expect(std.mem.indexOf(u8, md, "\n---\n") != null);
}

test "simple table with header row" {
    const a = std.testing.allocator;
    const html = "<table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table>";
    const md = try convert(a, html);
    defer a.free(md);
    try std.testing.expect(std.mem.indexOf(u8, md, "| A |") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "| --- |") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "| 1 |") != null);
}

test "inline strong em code del img in paragraph" {
    const a = std.testing.allocator;
    const html = "<p><strong>a</strong> <em>b</em> <code>c</code> <del>d</del> <img src=\"u\" alt=\"i\"/></p>";
    const md = try convert(a, html);
    defer a.free(md);
    try std.testing.expect(std.mem.indexOf(u8, md, "**a**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "*b*") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "`c`") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "~~d~~") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "![i](u)") != null);
}

test "heading and blockquote preserve inline markdown" {
    const a = std.testing.allocator;
    const html = "<h2>x <b>y</b></h2><blockquote><i>z</i></blockquote>";
    const md = try convert(a, html);
    defer a.free(md);
    try std.testing.expect(std.mem.indexOf(u8, md, "## x **y**") != null);
    try std.testing.expect(std.mem.indexOf(u8, md, "> *z*") != null);
}

test "table cell inline formatting" {
    const a = std.testing.allocator;
    const html = "<table><tr><th>H</th></tr><tr><td><strong>x</strong></td></tr></table>";
    const md = try convert(a, html);
    defer a.free(md);
    try std.testing.expect(std.mem.indexOf(u8, md, "| **x** |") != null);
}

test "span and script not matched as s or i" {
    const a = std.testing.allocator;
    const html = "<p><span>ok</span></p>";
    const md = try convert(a, html);
    defer a.free(md);
    try std.testing.expect(std.mem.indexOf(u8, md, "ok") != null);
}
