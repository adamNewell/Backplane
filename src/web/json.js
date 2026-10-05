// Convert host data to Bend JSON. Sparse number text preserves cache values.
/** Build Bend JSON from host data, using sparse exact-number text when supplied. */
export function toJson(v, numberText) {
  if (v === null || v === undefined) return { $: "Null" };
  if (typeof v === "boolean") return { $: "Flag", value: v };
  if (typeof v === "number") return { $: "Num", raw: typeof numberText === "string" ? numberText : String(v) };
  if (typeof v === "string") return { $: "Str", text: v };
  if (Array.isArray(v)) {
    let items = { $: "End" };
    for (let i = v.length - 1; i >= 0; i -= 1) items = { $: "Item", head: toJson(v[i], numberText?.[i]), tail: items };
    return { $: "Arr", items };
  }
  let fields = { $: "End" };
  const keys = Object.keys(v);
  for (let i = keys.length - 1; i >= 0; i -= 1) {
    fields = { $: "Field", key: keys[i], value: toJson(v[keys[i]], numberText?.[keys[i]]), tail: fields };
  }
  return { $: "Obj", fields };
}
