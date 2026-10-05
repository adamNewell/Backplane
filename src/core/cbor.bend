import Base
import ./json.bend as J
import ./utf8.bend as U

# A compact binary form of the JSON tree (an RFC 8949 CBOR subset), for every
# client/server message on slow links. Scalars: 0xF4 false, 0xF5 true, 0xF6
# null; integers that fit 32 bits as major 0/1; other numbers as tag 7 over
# their raw text; strings as major 3 UTF-8; arrays and maps with definite
# lengths. Map keys found in Cbor.keys() are sent as their index (major 0);
# string values found in Cbor.words() as tag 6 over their index.
# Arguments use the 1-, 2- and 4-byte forms; 8-byte and indefinite lengths
# decode to None.

# Dictionaries
# ------------

# Map keys sent as their index. APPEND-ONLY FOREVER: the order is part of the
# wire format; never reorder, remove or rename an entry.
def Cbor.keys() -> List<&2, String>:
  ["$", "t", "id", "m", "p", "ok", "error", "items", "thread", "msg", "role", "text", "at", "state", "project", "title", "kind", "summary", "tone", "act", "session", "model", "provider", "runtime", "interaction", "since", "seq", "version", "info", "path", "value", "key", "task", "parent", "child", "depth", "branch", "env", "worktree", "root", "pinned", "settled", "name", "result", "content", "type", "cid", "count", "manual", "archived"]

# String values sent as tag 6 over their index. APPEND-ONLY FOREVER, like
# Cbor.keys(). The first 24 cost two bytes, so the busiest words lead.
def Cbor.words() -> List<&2, String>:
  ["MessagePosted", "TurnChanged", "ActivityLogged", "changes", "delta", "reply", "user", "assistant", "running", "completed", "idle", "info", "tool", "error", "log", "update", "view", "hello", "system", "interrupted", "failed", "PendingChanged", "ThreadSettled", "ThreadUnsettled", "ProjectCreated", "ProjectRemoved", "ThreadCreated", "ThreadRenamed", "ThreadArchived", "ThreadPinned", "ThreadDeleted", "WorktreeSet", "SessionSet", "ModesSet", "TaskDelegated", "TaskStateSet", "TaskDelivered", "SettingSet", "local", "worktree", "approval-required", "auto-accept-edits", "auto", "full-access", "default", "plan", "queued", "done", "cancelled",
   "AskOpened", "AskClosed", "device.register", "device.drop", "DeviceRegistered", "DeviceDropped", "ios", "android", "alert", "activity", "sandbox", "production"]

def Cbor.hit(names: List<&2, String>, +s: String) -> Bool:
  match names:
    case n <> _:
      String.eq(n, s)
    case Nil{}:
      False{}

def Cbor.find.go(names: List<&2, String>, hit: Bool, +i: U32, +s: String) -> Maybe<&2, U32>:
  match names hit:
    case _ <> _ True{}:
      Some{i}
    case _ <> +t False{}:
      Cbor.find.go(t, Cbor.hit(t, s), (i + 1 : U32), s)
    case Nil{} _:
      None{}

# the index of s in a dictionary
def Cbor.find(+names: List<&2, String>, +s: String) -> Maybe<&2, U32>:
  Cbor.find.go(names, Cbor.hit(names, s), 0, s)

def Cbor.nth.go(names: List<&2, String>, zero: Bool, +i: U32) -> Maybe<&2, String>:
  match names zero:
    case h <> _ True{}:
      Some{h}
    case _ <> t False{}:
      Cbor.nth.go(t, U32.is_eq(i, 1), (i - 1 : U32))
    case Nil{} _:
      None{}

# the entry at index i of a dictionary
def Cbor.nth(names: List<&2, String>, +i: U32) -> Maybe<&2, String>:
  Cbor.nth.go(names, U32.is_eq(i, 0), i)

# Encoding
# --------

# The encoder walks the tree once, front to back, pushing bytes onto a
# reversed accumulator, and reverses once at the end. Every walk along a
# chain or a string is a tail call, so only nesting depth uses stack.

def Enc.head.k(a: Bool, b: Bool, c: Bool, +mb: U32, +n: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match a b c:
    case True{} _ _:
      U32.or(mb, n) <> acc
    case False{} True{} _:
      n <> U32.or(mb, 24) <> acc
    case False{} False{} True{}:
      U32.and(n, 255) <> U32.shrn(n, 8n) <> U32.or(mb, 25) <> acc
    case False{} False{} False{}:
      U32.and(n, 255) <> U32.and(U32.shrn(n, 8n), 255) <> U32.and(U32.shrn(n, 16n), 255) <> U32.shrn(n, 24n) <> U32.or(mb, 26) <> acc

# an item head in shortest form; mb is the major type already shifted (major * 32)
def Enc.head(+mb: U32, +n: U32, acc: List<&2, U32>) -> List<&2, U32>:
  Enc.head.k(U32.is_lt(n, 24), U32.is_lt(n, 256), U32.is_lt(n, 65536), mb, n, acc)

def Enc.cw.k(a: Bool, b: Bool, c: Bool) -> U32:
  match a b c:
    case True{} _ _:
      1
    case False{} True{} _:
      2
    case False{} False{} True{}:
      3
    case False{} False{} False{}:
      4

# the UTF-8 width of a code point (matches Utf8.put)
def Enc.cw(+c: U32) -> U32:
  Enc.cw.k(U32.is_lt(c, 128), U32.is_lt(c, 2048), U32.is_lt(c, 65536))

# the UTF-8 byte length of a string
def Enc.blen(s: String, acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      Enc.blen(t, (acc + Enc.cw(c) : U32))

def Enc.put.k(a: Bool, b: Bool, c: Bool, +cp: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match a b c:
    case True{} _ _:
      cp <> acc
    case False{} True{} _:
      U32.or(128, U32.and(cp, 63)) <> U32.or(192, U32.shrn(cp, 6n)) <> acc
    case False{} False{} True{}:
      U32.or(128, U32.and(cp, 63)) <> U32.or(128, U32.and(U32.shrn(cp, 6n), 63)) <> U32.or(224, U32.shrn(cp, 12n)) <> acc
    case False{} False{} False{}:
      U32.or(128, U32.and(cp, 63)) <> U32.or(128, U32.and(U32.shrn(cp, 6n), 63)) <> U32.or(128, U32.and(U32.shrn(cp, 12n), 63)) <> U32.or(240, U32.shrn(cp, 18n)) <> acc

# the UTF-8 bytes of a code point, reversed onto acc (the same bytes as Utf8.put)
def Enc.put(+cp: U32, acc: List<&2, U32>) -> List<&2, U32>:
  Enc.put.k(U32.is_lt(cp, 128), U32.is_lt(cp, 2048), U32.is_lt(cp, 65536), cp, acc)

def Enc.utf8(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      Enc.utf8(t, Enc.put(c, acc))

# a text string item
def Enc.text(+s: String, acc: List<&2, U32>) -> List<&2, U32>:
  Enc.utf8(s, Enc.head(96, Enc.blen(s, 0), acc))

# Numbers: which ones travel as integers
type Sc is Data:
  Sc{ok: Bool, val: U32, len: U32, zero: Bool}

def Enc.sc.step(st: Sc, +c: U32) -> Sc:
  match st:
    case Sc{ok, +v, +l, z}:
      +d = (c - 48 : U32)
      +fits = U32.is_lt(v, 429496729) || (U32.is_eq(v, 429496729) && U32.is_le(d, 5))
      Sc{ok && U32.is_lt(d, 10) && U32.is_lt(l, 10) && fits, (v * 10 + d : U32), (l + 1 : U32), z || (U32.is_eq(l, 0) && U32.is_eq(c, 48))}

def Enc.scan(s: String, st: Sc) -> Sc:
  match s:
    case SNil{}:
      st
    case SCon{Chr{c}, t}:
      Enc.scan(t, Enc.sc.step(st, c))

type NumK is Data:
  KPos{n: U32}
  KNeg{n: U32}
  KTxt{}

def Enc.pos.k(ok: Bool, v: U32) -> NumK:
  match ok:
    case True{}:
      KPos{v}
    case False{}:
      KTxt{}

# digits only, 1..10 of them, no leading zero, below 2^32
def Enc.pos(sc: Sc) -> NumK:
  match sc:
    case Sc{ok, v, +l, z}:
      Enc.pos.k(ok && U32.is_lt(0, l) && (Bool.not(z) || U32.is_eq(l, 1)), v)

def Enc.neg.k(p: NumK) -> NumK:
  match p:
    case KPos{+v}:
      Bool.pick(NumK, U32.is_eq(v, 0), KTxt{}, KNeg{(v - 1 : U32)})
    case _:
      KTxt{}

def Enc.kind.k(neg: Bool, +c: U32, t: String) -> NumK:
  match neg:
    case True{}:
      Enc.neg.k(Enc.pos(Enc.scan(t, Sc{True{}, 0, 0, False{}})))
    case False{}:
      Enc.pos(Enc.scan(SCon{Chr{c}, t}, Sc{True{}, 0, 0, False{}}))

# how a Num's raw text travels: as a non-negative or negative integer, or as text
def Enc.kind(r: String) -> NumK:
  match r:
    case SNil{}:
      KTxt{}
    case SCon{Chr{+c}, t}:
      Enc.kind.k(U32.is_eq(c, 45), c, t)

def Enc.num.put(k: NumK, r: String, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case KPos{n}:
      Enc.head(0, n, acc)
    case KNeg{n}:
      Enc.head(32, n, acc)
    case KTxt{}:
      Enc.text(r, 199 <> acc)

def Enc.num(+r: String, acc: List<&2, U32>) -> List<&2, U32>:
  Enc.num.put(Enc.kind(r), r, acc)

def Enc.str.k(m: Maybe<&2, U32>, s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match m:
    case Some{i}:
      Enc.head(0, i, 198 <> acc)
    case None{}:
      Enc.text(s, acc)

def Enc.str(+s: String, +ws: List<&2, String>, acc: List<&2, U32>) -> List<&2, U32>:
  Enc.str.k(Cbor.find(ws, s), s, acc)

def Enc.key.k(m: Maybe<&2, U32>, k: String, acc: List<&2, U32>) -> List<&2, U32>:
  match m:
    case Some{i}:
      Enc.head(0, i, acc)
    case None{}:
      Enc.text(k, acc)

def Enc.key(+k: String, +ks: List<&2, String>, acc: List<&2, U32>) -> List<&2, U32>:
  Enc.key.k(Cbor.find(ks, k), k, acc)

# the cells of an Item / Field chain
def Enc.count(xs: J.Json, acc: U32) -> U32:
  match xs:
    case J.Item{_, t}:
      Enc.count(t, (acc + 1 : U32))
    case J.Field{_, _, t}:
      Enc.count(t, (acc + 1 : U32))
    case _:
      acc

# j's bytes, reversed onto acc
def Enc.go(j: J.Json, +ks: List<&2, String>, +ws: List<&2, String>, acc: List<&2, U32>) -> List<&2, U32>:
  match j:
    case J.Null{}:
      246 <> acc
    case J.Flag{True{}}:
      245 <> acc
    case J.Flag{False{}}:
      244 <> acc
    case J.Num{r}:
      Enc.num(r, acc)
    case J.Str{s}:
      Enc.str(s, ws, acc)
    case J.Arr{+xs}:
      Enc.go(xs, ks, ws, Enc.head(128, Enc.count(xs, 0), acc))
    case J.Obj{+fs}:
      Enc.go(fs, ks, ws, Enc.head(160, Enc.count(fs, 0), acc))
    case J.Item{h, t}:
      Enc.go(t, ks, ws, Enc.go(h, ks, ws, acc))
    case J.Field{k, v, t}:
      Enc.go(t, ks, ws, Enc.go(v, ks, ws, Enc.key(k, ks, acc)))
    case J.End{}:
      acc

# the CBOR bytes (0..255 per cell) of a JSON value
def Cbor.encode(j: J.Json) -> List<&2, U32>:
  +ks = Cbor.keys()
  +ws = Cbor.words()
  List.reverse(&2, U32, Enc.go(j, ks, ws, Nil{}))

# Decoding
# --------

# a pending tag: none, 6 (a word index follows) or 7 (number text follows)
type Tag is Data:
  TNone{}
  TWord{}
  TNum{}

# an open array or map: items still owed, items so far (reversed), and for a
# map the key waiting for its value
type Frame is Data:
  FArr{left: Nat, acc: List<&2, J.Json>}
  FObj{left: Nat, acc: List<&2, J.KV>, key: Maybe<&2, String>}

# The decoder walks the bytes once: waiting for an initial byte, reading an
# argument's bytes, or reading a string's bytes.
type St is Data:
  SHead{stack: List<&2, Frame>, tag: Tag}
  SArg{stack: List<&2, Frame>, tag: Tag, major: U32, need: U32, acc: U32}
  SText{stack: List<&2, Frame>, tag: Tag, need: U32, acc: List<&2, U32>}
  SDone{v: J.Json}
  SBad{}

def Dec.keyidx(m: Maybe<&2, U32>, +ks: List<&2, String>) -> Maybe<&2, String>:
  match m:
    case Some{i}:
      Cbor.nth(ks, i)
    case None{}:
      None{}

def Cbor.key_text(raw: String, ks: List<&2, String>) -> Maybe<&2, String>:
  Dec.keyidx(U32.read(raw), ks)

def Dec.keyof(v: J.Json, +ks: List<&2, String>) -> Maybe<&2, String>:
  match v:
    case J.Str{k}:
      Some{k}
    case J.Num{r}:
      Cbor.key_text(r, ks)
    case _:
      None{}

def Dec.key(m: Maybe<&2, String>, n: Nat, acc: List<&2, J.KV>, rest: List<&2, Frame>) -> St:
  match m:
    case Some{k}:
      SHead{FObj{n, acc, Some{k}} <> rest, TNone{}}
    case None{}:
      SBad{}

# a finished value lands in the open container, closing every one it fills
def Dec.put(stack: List<&2, Frame>, v: J.Json, +ks: List<&2, String>) -> St:
  match stack:
    case Nil{}:
      SDone{v}
    case FArr{1n+0n, acc} <> rest:
      Dec.put(rest, J.Arr{J.Parse.chain(v <> acc, J.End{})}, ks)
    case FArr{1n+m, acc} <> rest:
      SHead{FArr{m, v <> acc} <> rest, TNone{}}
    case FArr{0n, _} <> _:
      SBad{}
    case FObj{n, acc, None{}} <> rest:
      Dec.key(Dec.keyof(v, ks), n, acc, rest)
    case FObj{1n+0n, acc, Some{k}} <> rest:
      Dec.put(rest, J.Obj{J.Parse.fchain(J.KV{k, v} <> acc, J.End{})}, ks)
    case FObj{1n+m, acc, Some{k}} <> rest:
      SHead{FObj{m, J.KV{k, v} <> acc, None{}} <> rest, TNone{}}
    case FObj{0n, _, Some{_}} <> _:
      SBad{}

def Dec.word(m: Maybe<&2, String>, stack: List<&2, Frame>, +ks: List<&2, String>) -> St:
  match m:
    case Some{s}:
      Dec.put(stack, J.Str{s}, ks)
    case None{}:
      SBad{}

def Dec.mk(tag: Tag, s: String) -> J.Json:
  match tag:
    case TNum{}:
      J.Num{s}
    case _:
      J.Str{s}

def Dec.negs.k(top: Bool, +n: U32) -> String:
  match top:
    case True{}:
      "-4294967296"
    case False{}:
      "-" ++ U32.show((n + 1 : U32))

# the text of a major-1 integer, -1 - n
def Dec.negs(+n: U32) -> String:
  Dec.negs.k(U32.is_eq(n, 4294967295), n)

def Dec.text.k(empty: Bool, +n: U32, tag: Tag, stack: List<&2, Frame>, +ks: List<&2, String>) -> St:
  match empty:
    case True{}:
      Dec.put(stack, Dec.mk(tag, ""), ks)
    case False{}:
      SText{stack, tag, n, Nil{}}

def Dec.arr.k(empty: Bool, +n: U32, stack: List<&2, Frame>, +ks: List<&2, String>) -> St:
  match empty:
    case True{}:
      Dec.put(stack, J.Arr{J.End{}}, ks)
    case False{}:
      SHead{FArr{U32.to_nat(n), Nil{}} <> stack, TNone{}}

def Dec.obj.k(empty: Bool, +n: U32, stack: List<&2, Frame>, +ks: List<&2, String>) -> St:
  match empty:
    case True{}:
      Dec.put(stack, J.Obj{J.End{}}, ks)
    case False{}:
      SHead{FObj{U32.to_nat(n), Nil{}, None{}} <> stack, TNone{}}

# The wire grammar is shared by both byte readers. The browser gets a
# table made from these rules; it does not define a second CBOR grammar.
type WireKind is Data:
  KInteger{}
  KNegative{}
  KWord{}
  KText{}
  KNumberText{}
  KArray{}
  KObject{}
  KWordTag{}
  KNumberTag{}
  KFalseValue{}
  KTrueValue{}
  KNullValue{}
  KBad{}

type Rule is Data:
  Rule{kind: WireKind, extra: U32}

def Head.value(major: U32, tag: Tag) -> WireKind:
  match major tag:
    case 0 TNone{}:
      KInteger{}
    case 0 TWord{}:
      KWord{}
    case 1 TNone{}:
      KNegative{}
    case 3 TNone{}:
      KText{}
    case 3 TNum{}:
      KNumberText{}
    case 4 TNone{}:
      KArray{}
    case 5 TNone{}:
      KObject{}
    case _ _:
      KBad{}

def Head.argument(ai: U32, kind: WireKind) -> Rule:
  match ai:
    case 24:
      Rule{kind, 1}
    case 25:
      Rule{kind, 2}
    case 26:
      Rule{kind, 4}
    case _:
      Rule{KBad{}, 0}

def Head.length(short: Bool, ai: U32, kind: WireKind) -> Rule:
  match short:
    case True{}:
      Rule{kind, 0}
    case False{}:
      Head.argument(ai, kind)

def Head.tag(ai: U32) -> Rule:
  match ai:
    case 6:
      Rule{KWordTag{}, 0}
    case 7:
      Rule{KNumberTag{}, 0}
    case _:
      Rule{KBad{}, 0}

def Head.simple(ai: U32) -> Rule:
  match ai:
    case 20:
      Rule{KFalseValue{}, 0}
    case 21:
      Rule{KTrueValue{}, 0}
    case 22:
      Rule{KNullValue{}, 0}
    case _:
      Rule{KBad{}, 0}

def Head.read(major: U32, +ai: U32, +tag: Tag) -> Rule:
  match major tag:
    case 6 TNone{}:
      Head.tag(ai)
    case 7 TNone{}:
      Head.simple(ai)
    case 6 _:
      Rule{KBad{}, 0}
    case 7 _:
      Rule{KBad{}, 0}
    case _ _:
      Head.length(U32.is_lt(ai, 24), ai, Head.value(major, tag))

# an item whose head (major type and argument n) is complete
def Dec.value(kind: WireKind, stack: List<&2, Frame>, +n: U32, +ks: List<&2, String>, +ws: List<&2, String>) -> St:
  match kind:
    case KInteger{}:
      Dec.put(stack, J.Num{U32.show(n)}, ks)
    case KWord{}:
      Dec.word(Cbor.nth(ws, n), stack, ks)
    case KNegative{}:
      Dec.put(stack, J.Num{Dec.negs(n)}, ks)
    case KText{}:
      Dec.text.k(U32.is_eq(n, 0), n, TNone{}, stack, ks)
    case KNumberText{}:
      Dec.text.k(U32.is_eq(n, 0), n, TNum{}, stack, ks)
    case KArray{}:
      Dec.arr.k(U32.is_eq(n, 0), n, stack, ks)
    case KObject{}:
      Dec.obj.k(U32.is_eq(n, 0), n, stack, ks)
    case _:
      SBad{}

def Dec.item(major: U32, tag: Tag, stack: List<&2, Frame>, n: U32, ks: List<&2, String>, ws: List<&2, String>) -> St:
  Dec.value(Head.value(major, tag), stack, n, ks, ws)

def Dec.rule(r: Rule, maj: U32, ai: U32, stack: List<&2, Frame>, tag: Tag, +ks: List<&2, String>, ws: List<&2, String>) -> St:
  match r:
    case Rule{KBad{}, _}:
      SBad{}
    case Rule{KWordTag{}, _}:
      SHead{stack, TWord{}}
    case Rule{KNumberTag{}, _}:
      SHead{stack, TNum{}}
    case Rule{KFalseValue{}, _}:
      Dec.put(stack, J.Flag{False{}}, ks)
    case Rule{KTrueValue{}, _}:
      Dec.put(stack, J.Flag{True{}}, ks)
    case Rule{KNullValue{}, _}:
      Dec.put(stack, J.Null{}, ks)
    case Rule{kind, 0}:
      Dec.value(kind, stack, ai, ks, ws)
    case Rule{_, extra}:
      SArg{stack, tag, maj, extra, 0}

# an initial byte: major type in the top 3 bits, additional info in the low 5
def Dec.head(+maj: U32, +ai: U32, stack: List<&2, Frame>, +tag: Tag, ks: List<&2, String>, ws: List<&2, String>) -> St:
  Dec.rule(Head.read(maj, ai, tag), maj, ai, stack, tag, ks, ws)

# Each table has all 256 possible initial bytes, in byte order.
def Cbor.rules.go(left: Nat, +tag: Tag, +byte: U32) -> List<&2, Rule>:
  match left:
    case 0n:
      Nil{}
    case 1n+p:
      Head.read(U32.shrn(byte, 5n), U32.and(byte, 31), tag) <> Cbor.rules.go(p, tag, (byte + 1 : U32))

def Cbor.rules() -> List<&2, List<&2, Rule>>:
  [Cbor.rules.go(256n, TNone{}, 0), Cbor.rules.go(256n, TWord{}, 0), Cbor.rules.go(256n, TNum{}, 0)]

def Dec.arg.k(last: Bool, stack: List<&2, Frame>, tag: Tag, +maj: U32, +need: U32, +acc: U32, +ks: List<&2, String>, +ws: List<&2, String>) -> St:
  match last:
    case True{}:
      Dec.item(maj, tag, stack, acc, ks, ws)
    case False{}:
      SArg{stack, tag, maj, (need - 1 : U32), acc}

def Dec.txt.k(last: Bool, stack: List<&2, Frame>, tag: Tag, +need: U32, acc: List<&2, U32>, +ks: List<&2, String>) -> St:
  match last:
    case True{}:
      Dec.put(stack, Dec.mk(tag, U.Utf8.decode(List.reverse(&2, U32, acc))), ks)
    case False{}:
      SText{stack, tag, (need - 1 : U32), acc}

def Dec.step(st: St, +b: U32, +ks: List<&2, String>, +ws: List<&2, String>) -> St:
  match st:
    case SHead{stack, tag}:
      Dec.head(U32.shrn(b, 5n), U32.and(b, 31), stack, tag, ks, ws)
    case SArg{stack, tag, maj, +need, acc}:
      Dec.arg.k(U32.is_eq(need, 1), stack, tag, maj, need, U32.or(U32.shln(acc, 8n), b), ks, ws)
    case SText{stack, tag, +need, acc}:
      Dec.txt.k(U32.is_eq(need, 1), stack, tag, need, b <> acc, ks)
    case SDone{_}:
      SBad{}
    case SBad{}:
      SBad{}

def Dec.go(bs: List<&2, U32>, st: St, +ks: List<&2, String>, +ws: List<&2, String>) -> St:
  match bs:
    case Nil{}:
      st
    case b <> t:
      Dec.go(t, Dec.step(st, b, ks, ws), ks, ws)

def Dec.fin(st: St) -> Maybe<&2, J.Json>:
  match st:
    case SDone{v}:
      Some{v}
    case _:
      None{}

# the JSON value of CBOR bytes, or None when they are malformed or truncated
def Cbor.decode(bs: List<&2, U32>) -> Maybe<&2, J.Json>:
  +ks = Cbor.keys()
  +ws = Cbor.words()
  Dec.fin(Dec.go(bs, SHead{Nil{}, TNone{}}, ks, ws))
