import {
  shoppingAssert,
  shoppingListContract as contract,
} from "./shoppingListContract";

// Bounded ordinary ZIP only. Streaming inflation is capped before ExcelJS sees
// the archive; raw numeric XML is retained before its binary number conversion.
const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8", { fatal: true });
export type ShoppingListPackage = Map<string, Uint8Array>;
function crc32(bytes: Uint8Array) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let n = 0; n < 8; n++) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
async function inflate(bytes: Uint8Array, limit: number) {
  const stream = new ReadableStream<BufferSource>({
    start(controller) {
      controller.enqueue(new Uint8Array(bytes));
      controller.close();
    },
  }).pipeThrough(new DecompressionStream("deflate-raw"));
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const r = await reader.read();
      if (r.done) break;
      size += r.value.length;
      shoppingAssert(size <= limit, "RESOURCE_LIMIT");
      chunks.push(r.value);
    }
  } finally {
    await reader.cancel();
  }
  const out = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.length;
  }
  return out;
}
export async function readShoppingListPackage(
  input: ArrayBuffer | Uint8Array,
): Promise<ShoppingListPackage> {
  const bytes = input instanceof Uint8Array ? input : new Uint8Array(input);
  const limits = contract.resourceLimits;
  shoppingAssert(
    bytes.length >= 22 && bytes.length <= limits.compressedBytes,
    "RESOURCE_LIMIT",
  );
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let end = bytes.length - 22;
  while (
    end >= Math.max(0, bytes.length - 65557) &&
    view.getUint32(end, true) !== 0x06054b50
  )
    end--;
  shoppingAssert(
    end >= 0 && end + 22 + view.getUint16(end + 20, true) === bytes.length,
  );
  shoppingAssert(
    view.getUint16(end + 4, true) === 0 && view.getUint16(end + 6, true) === 0,
  );
  const count = view.getUint16(end + 10, true);
  shoppingAssert(
    count > 0 &&
      count <= limits.zipEntries &&
      count === view.getUint16(end + 8, true),
  );
  let cursor = view.getUint32(end + 16, true);
  const directorySize = view.getUint32(end + 12, true);
  shoppingAssert(cursor + directorySize === end);
  const files: ShoppingListPackage = new Map();
  let total = 0;
  const ranges: [number, number][] = [];
  for (let i = 0; i < count; i++) {
    shoppingAssert(
      cursor + 46 <= end && view.getUint32(cursor, true) === 0x02014b50,
    );
    const flags = view.getUint16(cursor + 8, true),
      method = view.getUint16(cursor + 10, true),
      crc = view.getUint32(cursor + 16, true),
      compressed = view.getUint32(cursor + 20, true),
      size = view.getUint32(cursor + 24, true),
      nameSize = view.getUint16(cursor + 28, true),
      extra = view.getUint16(cursor + 30, true),
      comment = view.getUint16(cursor + 32, true),
      local = view.getUint32(cursor + 42, true);
    shoppingAssert(
      !(flags & 1) &&
        (method === 0 || method === 8) &&
        compressed !== 0xffffffff &&
        size !== 0xffffffff &&
        local !== 0xffffffff,
    );
    shoppingAssert(cursor + 46 + nameSize + extra + comment <= end);
    const name = decoder.decode(
      bytes.subarray(cursor + 46, cursor + 46 + nameSize),
    );
    shoppingAssert(
      name.length &&
        !name.startsWith("/") &&
        !name.includes("\\") &&
        !name.includes(":") &&
        !name.split("/").some((p) => p === ".." || p === ".") &&
        !files.has(name),
    );
    total += size;
    shoppingAssert(
      total <= limits.totalUncompressedBytes &&
        (!/\.(xml|rels)$/.test(name) || size <= limits.xmlPartBytes),
      "RESOURCE_LIMIT",
    );
    shoppingAssert(
      size <= limits.largeEntryThresholdBytes ||
        size / Math.max(1, compressed) <= limits.maximumLargeEntryRatio,
      "RESOURCE_LIMIT",
    );
    shoppingAssert(
      local + 30 <= view.getUint32(end + 16, true) &&
        view.getUint32(local, true) === 0x04034b50,
    );
    shoppingAssert(
      view.getUint16(local + 6, true) === flags &&
        view.getUint16(local + 8, true) === method,
    );
    const localNameSize = view.getUint16(local + 26, true),
      localExtra = view.getUint16(local + 28, true),
      start = local + 30 + localNameSize + localExtra;
    shoppingAssert(
      decoder.decode(bytes.subarray(local + 30, local + 30 + localNameSize)) ===
        name && start + compressed <= view.getUint32(end + 16, true),
    );
    shoppingAssert(
      !ranges.some(([a, b]) => local < b && start + compressed > a),
    );
    ranges.push([local, start + compressed]);
    const packed = bytes.subarray(start, start + compressed);
    const data = method === 0 ? packed : await inflate(packed, size);
    shoppingAssert(data.length === size && crc32(data) === crc);
    files.set(name, data);
    cursor += 46 + nameSize + extra + comment;
  }
  shoppingAssert(cursor === end);
  return files;
}
export function packageText(files: ShoppingListPackage, path: string) {
  const bytes = files.get(path);
  shoppingAssert(bytes);
  return decoder.decode(bytes);
}
export function setPackageText(
  files: ShoppingListPackage,
  path: string,
  text: string,
) {
  files.set(path, encoder.encode(text));
}

// Stored entries keep exact patched XML and use no extra library/dependency.
export function writeShoppingListPackage(
  files: ShoppingListPackage,
): Uint8Array {
  const localParts: Uint8Array[] = [];
  const centralParts: Uint8Array[] = [];
  let offset = 0,
    centralLength = 0;
  for (const [name, data] of files) {
    const filename = encoder.encode(name);
    const crc = crc32(data);
    const local = new Uint8Array(30 + filename.length + data.length);
    const v = new DataView(local.buffer);
    v.setUint32(0, 0x04034b50, true);
    v.setUint16(4, 20, true);
    v.setUint16(6, 0x800, true);
    v.setUint32(14, crc, true);
    v.setUint32(18, data.length, true);
    v.setUint32(22, data.length, true);
    v.setUint16(26, filename.length, true);
    local.set(filename, 30);
    local.set(data, 30 + filename.length);
    const central = new Uint8Array(46 + filename.length);
    const c = new DataView(central.buffer);
    c.setUint32(0, 0x02014b50, true);
    c.setUint16(4, 20, true);
    c.setUint16(6, 20, true);
    c.setUint16(8, 0x800, true);
    c.setUint32(16, crc, true);
    c.setUint32(20, data.length, true);
    c.setUint32(24, data.length, true);
    c.setUint16(28, filename.length, true);
    c.setUint32(42, offset, true);
    central.set(filename, 46);
    localParts.push(local);
    centralParts.push(central);
    offset += local.length;
    centralLength += central.length;
  }
  const end = new Uint8Array(22);
  const e = new DataView(end.buffer);
  e.setUint32(0, 0x06054b50, true);
  e.setUint16(8, files.size, true);
  e.setUint16(10, files.size, true);
  e.setUint32(12, centralLength, true);
  e.setUint32(16, offset, true);
  const output = new Uint8Array(offset + centralLength + 22);
  let position = 0;
  for (const part of [...localParts, ...centralParts, end]) {
    output.set(part, position);
    position += part.length;
  }
  shoppingAssert(
    output.length <= contract.resourceLimits.compressedBytes,
    "RESOURCE_LIMIT",
  );
  return output;
}
export function parsePackageXml(text: string) {
  shoppingAssert(!/<!DOCTYPE|<!ENTITY/i.test(text));
  const doc = new DOMParser().parseFromString(text, "application/xml");
  shoppingAssert(!doc.getElementsByTagName("parsererror").length);
  return doc;
}
export function xmlElements(node: Document | Element, name: string) {
  return Array.from(node.getElementsByTagNameNS("*", name));
}
