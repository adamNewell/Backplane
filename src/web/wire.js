// Decode the hub's JSON CBOR directly from its byte buffer. Dictionaries
// and header rules come from core/cbor.bend. This file reads buffers
// and builds host values; Bend defines the accepted wire grammar.
export function wireDecoder(keys, words, rules, keyText) {
  const text = new TextDecoder("utf-8", { ignoreBOM: true });
  // Actions name host construction operations. Their byte and tag
  // assignments come only from the Bend rule table.
  const kinds = ["KBad", "KInteger", "KNegative", "KText", "KArray", "KObject", "KWordTag", "KNumberTag", "KWord", "KNumberText", "KFalseValue", "KTrueValue", "KNullValue"];
  const [, INTEGER, NEGATIVE, TEXT, ARRAY, OBJECT, WORD_TAG,
    NUMBER_TAG, WORD, NUMBER_TEXT, FALSE, TRUE, NULL] = kinds.map((_, i) => i);
  const plans = new Uint8Array(768);
  let index = 0;
  for (let rows = rules; rows.$ === "Con"; rows = rows.tail) {
    for (let xs = rows.head; xs.$ === "Con"; xs = xs.tail) {
      const action = kinds.indexOf(xs.head.kind.$);
      if (action < 0) throw new Error("Unknown CBOR construction action");
      plans[index++] = action | (Number(xs.head.extra) << 4);
    }
  }
  if (index !== 768) throw new Error("Incomplete CBOR rule table");
  return function decode(bytes) {
    let at = 0;
    const take = (n) => {
      if (n > bytes.length - at) throw new Error("Truncated CBOR");
      const start = at;
      at += n;
      return start;
    };
    let itemKind = 0, itemSize = 0;
    const head = (tag) => {
      const h = bytes[take(1)], plan = plans[(tag << 8) | h], kind = plan & 15, extra = plan >>> 4;
      let n = h & 31;
      if (extra) {
        const start = take(extra);
        n = 0;
        for (let i = start; i < at; i++) n = n * 256 + bytes[i];
      }
      if (kind === WORD_TAG) return head(1);
      if (kind === NUMBER_TAG) return head(2);
      itemKind = kind;
      itemSize = n;
    };
    const str = (n) => text.decode(bytes.subarray(take(n), at));
    const dictionary = (names, n) => {
      const value = names[n];
      if (value === undefined) throw new Error("Invalid CBOR dictionary index");
      return value;
    };
    const numberKey = (raw) => {
      const key = keyText(raw);
      if (key.$ !== "Some") throw new Error("Invalid CBOR key");
      return key.value;
    };
    const key = () => {
      head(0);
      const kind = itemKind, n = itemSize;
      if (kind === INTEGER) return dictionary(keys, n);
      if (kind === NEGATIVE) return numberKey(String(-1 - n));
      if (kind === TEXT) return str(n);
      if (kind === WORD) return dictionary(words, n);
      if (kind === NUMBER_TEXT) return numberKey(str(n));
      throw new Error("Invalid CBOR key");
    };
    const item = (depth = 0) => {
      if (depth > 512) throw new Error("CBOR nesting limit");
      head(0);
      const kind = itemKind, n = itemSize;
      if (kind === INTEGER || kind === NEGATIVE) {
        const value = kind === INTEGER ? n : -1 - n;
        return { json: { $: "Num", raw: String(value) }, value };
      }
      if (kind === TEXT) {
        const value = str(n);
        return { json: { $: "Str", text: value }, value };
      }
      if (kind === ARRAY) {
        if (n > bytes.length - at) throw new Error("Truncated CBOR array");
        const value = [], nodes = [];
        for (let i = 0; i < n; i++) {
          const v = item(depth + 1);
          value.push(v.value);
          nodes.push(v.json);
        }
        let items = { $: "End" };
        for (let i = nodes.length - 1; i >= 0; i--) items = { $: "Item", head: nodes[i], tail: items };
        return { json: { $: "Arr", items }, value };
      }
      if (kind === OBJECT) {
        if (n > (bytes.length - at) / 2) throw new Error("Truncated CBOR map");
        const value = {}, nodes = [];
        for (let i = 0; i < n; i++) {
          const name = key();
          const v = item(depth + 1);
          Object.defineProperty(value, name, { value: v.value, enumerable: true, writable: true, configurable: true });
          nodes.push({ key: name, json: v.json });
        }
        let fields = { $: "End" };
        for (let i = nodes.length - 1; i >= 0; i--) fields = { $: "Field", key: nodes[i].key, value: nodes[i].json, tail: fields };
        return { json: { $: "Obj", fields }, value };
      }
      if (kind === WORD) {
        const value = dictionary(words, n);
        return { json: { $: "Str", text: value }, value };
      }
      if (kind === NUMBER_TEXT) {
        const raw = str(n);
        return { json: { $: "Num", raw }, value: Number(raw) };
      }
      if (kind === FALSE || kind === TRUE || kind === NULL) {
        const value = kind === NULL ? null : kind === TRUE;
        return { json: value === null ? { $: "Null" } : { $: "Flag", value }, value };
      }
      throw new Error("Unsupported CBOR value");
    };
    try {
      const result = item();
      if (at !== bytes.length) throw new Error("Trailing CBOR bytes");
      return result;
    } catch {
      return { json: { $: "Null" }, value: null };
    }
  };
}
