(() => {
  // build/dev/javascript/prelude.mjs
  class CustomType {
    withFields(fields) {
      let properties = Object.keys(this).map((label) => (label in fields) ? fields[label] : this[label]);
      return new this.constructor(...properties);
    }
  }

  class List {
    static fromArray(array, tail) {
      let t = tail || new Empty;
      for (let i = array.length - 1;i >= 0; --i) {
        t = new NonEmpty(array[i], t);
      }
      return t;
    }
    [Symbol.iterator]() {
      return new ListIterator(this);
    }
    toArray() {
      return [...this];
    }
    atLeastLength(desired) {
      let current = this;
      while (desired-- > 0 && current)
        current = current.tail;
      return current !== undefined;
    }
    hasLength(desired) {
      let current = this;
      while (desired-- > 0 && current)
        current = current.tail;
      return desired === -1 && current instanceof Empty;
    }
    countLength() {
      let current = this;
      let length = 0;
      while (current) {
        current = current.tail;
        length++;
      }
      return length - 1;
    }
  }
  function prepend(element, tail) {
    return new NonEmpty(element, tail);
  }
  function toList(elements, tail) {
    return List.fromArray(elements, tail);
  }

  class ListIterator {
    #current;
    constructor(current) {
      this.#current = current;
    }
    next() {
      if (this.#current instanceof Empty) {
        return { done: true };
      } else {
        let { head, tail } = this.#current;
        this.#current = tail;
        return { value: head, done: false };
      }
    }
  }

  class Empty extends List {
  }
  var List$Empty = () => new Empty;
  var List$isEmpty = (value) => value instanceof Empty;

  class NonEmpty extends List {
    constructor(head, tail) {
      super();
      this.head = head;
      this.tail = tail;
    }
  }
  var List$NonEmpty = (head, tail) => new NonEmpty(head, tail);
  var List$isNonEmpty = (value) => value instanceof NonEmpty;
  class BitArray {
    bitSize;
    byteSize;
    bitOffset;
    rawBuffer;
    constructor(buffer, bitSize, bitOffset) {
      if (!(buffer instanceof Uint8Array)) {
        throw globalThis.Error("BitArray can only be constructed from a Uint8Array");
      }
      this.bitSize = bitSize ?? buffer.length * 8;
      this.byteSize = Math.trunc((this.bitSize + 7) / 8);
      this.bitOffset = bitOffset ?? 0;
      if (this.bitSize < 0) {
        throw globalThis.Error(`BitArray bit size is invalid: ${this.bitSize}`);
      }
      if (this.bitOffset < 0 || this.bitOffset > 7) {
        throw globalThis.Error(`BitArray bit offset is invalid: ${this.bitOffset}`);
      }
      if (buffer.length !== Math.trunc((this.bitOffset + this.bitSize + 7) / 8)) {
        throw globalThis.Error("BitArray buffer length is invalid");
      }
      this.rawBuffer = buffer;
    }
    byteAt(index) {
      if (index < 0 || index >= this.byteSize) {
        return;
      }
      return bitArrayByteAt(this.rawBuffer, this.bitOffset, index);
    }
    equals(other) {
      if (this.bitSize !== other.bitSize) {
        return false;
      }
      const wholeByteCount = Math.trunc(this.bitSize / 8);
      if (this.bitOffset === 0 && other.bitOffset === 0) {
        for (let i = 0;i < wholeByteCount; i++) {
          if (this.rawBuffer[i] !== other.rawBuffer[i]) {
            return false;
          }
        }
        const trailingBitsCount = this.bitSize % 8;
        if (trailingBitsCount) {
          const unusedLowBitCount = 8 - trailingBitsCount;
          if (this.rawBuffer[wholeByteCount] >> unusedLowBitCount !== other.rawBuffer[wholeByteCount] >> unusedLowBitCount) {
            return false;
          }
        }
      } else {
        for (let i = 0;i < wholeByteCount; i++) {
          const a = bitArrayByteAt(this.rawBuffer, this.bitOffset, i);
          const b = bitArrayByteAt(other.rawBuffer, other.bitOffset, i);
          if (a !== b) {
            return false;
          }
        }
        const trailingBitsCount = this.bitSize % 8;
        if (trailingBitsCount) {
          const a = bitArrayByteAt(this.rawBuffer, this.bitOffset, wholeByteCount);
          const b = bitArrayByteAt(other.rawBuffer, other.bitOffset, wholeByteCount);
          const unusedLowBitCount = 8 - trailingBitsCount;
          if (a >> unusedLowBitCount !== b >> unusedLowBitCount) {
            return false;
          }
        }
      }
      return true;
    }
    get buffer() {
      if (this.bitOffset !== 0 || this.bitSize % 8 !== 0) {
        throw new globalThis.Error("BitArray.buffer does not support unaligned bit arrays");
      }
      return this.rawBuffer;
    }
    get length() {
      if (this.bitOffset !== 0 || this.bitSize % 8 !== 0) {
        throw new globalThis.Error("BitArray.length does not support unaligned bit arrays");
      }
      return this.rawBuffer.length;
    }
  }
  function bitArrayByteAt(buffer, bitOffset, index) {
    if (bitOffset === 0) {
      return buffer[index] ?? 0;
    } else {
      const a = buffer[index] << bitOffset & 255;
      const b = buffer[index + 1] >> 8 - bitOffset;
      return a | b;
    }
  }

  class UtfCodepoint {
    constructor(value) {
      this.value = value;
    }
  }
  class Result extends CustomType {
    static isResult(data2) {
      return data2 instanceof Result;
    }
  }

  class Ok extends Result {
    constructor(value) {
      super();
      this[0] = value;
    }
    isOk() {
      return true;
    }
  }
  var Result$Ok = (value) => new Ok(value);
  class Error extends Result {
    constructor(detail) {
      super();
      this[0] = detail;
    }
    isOk() {
      return false;
    }
  }
  var Result$Error = (detail) => new Error(detail);
  // build/dev/javascript/gleam_stdlib/dict.mjs
  class Dict {
    constructor(size, root) {
      this.size = size;
      this.root = root;
    }
  }
  var bits = 5;
  var mask = (1 << bits) - 1;
  var noElementMarker = Symbol();
  var generationKey = Symbol();
  function fold(dict, state, fun) {
    const queue = [dict.root];
    while (queue.length) {
      const node = queue.pop();
      const data2 = node.data;
      const edgesStart = data2.length - popcount(node.nodemap);
      for (let i = 0;i < edgesStart; i += 2) {
        state = fun(state, data2[i], data2[i + 1]);
      }
      for (let i = edgesStart;i < data2.length; ++i) {
        queue.push(data2[i]);
      }
    }
    return state;
  }
  function popcount(n) {
    n -= n >>> 1 & 1431655765;
    n = (n & 858993459) + (n >>> 2 & 858993459);
    return Math.imul(n + (n >>> 4) & 252645135, 16843009) >>> 24;
  }

  // build/dev/javascript/gleam_stdlib/gleam/option.mjs
  class Some extends CustomType {
    constructor($0) {
      super();
      this[0] = $0;
    }
  }
  class None extends CustomType {
  }
  function to_result(option, e) {
    if (option instanceof Some) {
      let a = option[0];
      return new Ok(a);
    } else {
      return new Error(e);
    }
  }
  function unwrap(option, default$) {
    if (option instanceof Some) {
      let x = option[0];
      return x;
    } else {
      return default$;
    }
  }

  // build/dev/javascript/gleam_stdlib/gleam/string.mjs
  function concat_loop(loop$strings, loop$accumulator) {
    while (true) {
      let strings = loop$strings;
      let accumulator = loop$accumulator;
      if (strings instanceof Empty) {
        return accumulator;
      } else {
        let string = strings.head;
        let strings$1 = strings.tail;
        loop$strings = strings$1;
        loop$accumulator = accumulator + string;
      }
    }
  }
  function concat2(strings) {
    return concat_loop(strings, "");
  }

  // build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs
  function to_string(term) {
    return term.toString();
  }
  function pop_codeunit(str) {
    return [str.charCodeAt(0) | 0, str.slice(1)];
  }
  function lowercase(string2) {
    return string2.toLowerCase();
  }
  function string_codeunit_slice(str, from2, length2) {
    return str.slice(from2, from2 + length2);
  }
  function starts_with(haystack, needle) {
    return haystack.startsWith(needle);
  }
  var unicode_whitespaces = [
    " ",
    "\t",
    `
`,
    "\v",
    "\f",
    "\r",
    "",
    "\u2028",
    "\u2029"
  ].join("");
  var trim_start_regex = /* @__PURE__ */ new RegExp(`^[${unicode_whitespaces}]*`);
  var trim_end_regex = /* @__PURE__ */ new RegExp(`[${unicode_whitespaces}]*$`);
  var MIN_I32 = -(2 ** 31);
  var MAX_I32 = 2 ** 31 - 1;
  var U32 = 2 ** 32;
  var MAX_SAFE = Number.MAX_SAFE_INTEGER;
  var MIN_SAFE = Number.MIN_SAFE_INTEGER;
  function float_to_string(float2) {
    const string2 = float2.toString().replace("+", "");
    if (string2.indexOf(".") >= 0) {
      return string2;
    } else {
      const index2 = string2.indexOf("e");
      if (index2 >= 0) {
        return string2.slice(0, index2) + ".0" + string2.slice(index2);
      } else {
        return string2 + ".0";
      }
    }
  }

  class Inspector {
    #references = new Set;
    inspect(v) {
      const t = typeof v;
      if (v === true)
        return "True";
      if (v === false)
        return "False";
      if (v === null)
        return "//js(null)";
      if (v === undefined)
        return "Nil";
      if (t === "string")
        return this.#string(v);
      if (t === "bigint" || Number.isInteger(v))
        return v.toString();
      if (t === "number")
        return float_to_string(v);
      if (v instanceof UtfCodepoint)
        return this.#utfCodepoint(v);
      if (v instanceof BitArray)
        return this.#bit_array(v);
      if (v instanceof RegExp)
        return `//js(${v})`;
      if (v instanceof Date)
        return `//js(Date("${v.toISOString()}"))`;
      if (v instanceof globalThis.Error)
        return `//js(${v.toString()})`;
      if (v instanceof Function) {
        const args = [];
        for (const i of Array(v.length).keys())
          args.push(String.fromCharCode(i + 97));
        return `//fn(${args.join(", ")}) { ... }`;
      }
      if (this.#references.size === this.#references.add(v).size) {
        return "//js(circular reference)";
      }
      let printed;
      if (Array.isArray(v)) {
        printed = `#(${v.map((v2) => this.inspect(v2)).join(", ")})`;
      } else if (isList(v)) {
        printed = this.#list(v);
      } else if (v instanceof CustomType) {
        printed = this.#customType(v);
      } else if (v instanceof Dict) {
        printed = this.#dict(v);
      } else if (v instanceof Set) {
        return `//js(Set(${[...v].map((v2) => this.inspect(v2)).join(", ")}))`;
      } else {
        printed = this.#object(v);
      }
      this.#references.delete(v);
      return printed;
    }
    #object(v) {
      const name = Object.getPrototypeOf(v)?.constructor?.name || "Object";
      const props = [];
      for (const k of Object.keys(v)) {
        props.push(`${this.inspect(k)}: ${this.inspect(v[k])}`);
      }
      const body = props.length ? " " + props.join(", ") + " " : "";
      const head = name === "Object" ? "" : name + " ";
      return `//js(${head}{${body}})`;
    }
    #dict(map3) {
      let body = "dict.from_list([";
      let first = true;
      body = fold(map3, body, (body2, key, value) => {
        if (!first)
          body2 = body2 + ", ";
        first = false;
        return body2 + "#(" + this.inspect(key) + ", " + this.inspect(value) + ")";
      });
      return body + "])";
    }
    #customType(record) {
      const props = Object.keys(record).map((label) => {
        const value = this.inspect(record[label]);
        return isNaN(parseInt(label)) ? `${label}: ${value}` : value;
      }).join(", ");
      return props ? `${record.constructor.name}(${props})` : record.constructor.name;
    }
    #list(list2) {
      if (List$isEmpty(list2)) {
        return "[]";
      }
      let char_out = 'charlist.from_string("';
      let list_out = "[";
      let current = list2;
      while (List$isNonEmpty(current)) {
        let element = current.head;
        current = current.tail;
        if (list_out !== "[") {
          list_out += ", ";
        }
        list_out += this.inspect(element);
        if (char_out) {
          if (Number.isInteger(element) && element >= 32 && element <= 126) {
            char_out += String.fromCharCode(element);
          } else {
            char_out = null;
          }
        }
      }
      if (char_out) {
        return char_out + '")';
      } else {
        return list_out + "]";
      }
    }
    #string(str) {
      let new_str = '"';
      for (let i = 0;i < str.length; i++) {
        const char = str[i];
        switch (char) {
          case `
`:
            new_str += "\\n";
            break;
          case "\r":
            new_str += "\\r";
            break;
          case "\t":
            new_str += "\\t";
            break;
          case "\f":
            new_str += "\\f";
            break;
          case "\\":
            new_str += "\\\\";
            break;
          case '"':
            new_str += "\\\"";
            break;
          default:
            if (char < " " || char > "~" && char < " ") {
              new_str += "\\u{" + char.charCodeAt(0).toString(16).toUpperCase().padStart(4, "0") + "}";
            } else {
              new_str += char;
            }
        }
      }
      new_str += '"';
      return new_str;
    }
    #utfCodepoint(codepoint2) {
      return `//utfcodepoint(${String.fromCodePoint(codepoint2.value)})`;
    }
    #bit_array(bits2) {
      if (bits2.bitSize === 0) {
        return "<<>>";
      }
      let acc = "<<";
      for (let i = 0;i < bits2.byteSize - 1; i++) {
        acc += bits2.byteAt(i).toString();
        acc += ", ";
      }
      if (bits2.byteSize * 8 === bits2.bitSize) {
        acc += bits2.byteAt(bits2.byteSize - 1).toString();
      } else {
        const trailingBitsCount = bits2.bitSize % 8;
        acc += bits2.byteAt(bits2.byteSize - 1) >> 8 - trailingBitsCount;
        acc += `:size(${trailingBitsCount})`;
      }
      acc += ">>";
      return acc;
    }
  }
  function isList(data2) {
    return List$isEmpty(data2) || List$isNonEmpty(data2);
  }

  // build/dev/javascript/gleam_stdlib/gleam/result.mjs
  function try$(result, fun) {
    if (result instanceof Ok) {
      let x = result[0];
      return fun(x);
    } else {
      return result;
    }
  }

  // build/dev/javascript/gleam_stdlib/gleam/uri.mjs
  class Uri extends CustomType {
    constructor(scheme, userinfo, host, port, path, query, fragment) {
      super();
      this.scheme = scheme;
      this.userinfo = userinfo;
      this.host = host;
      this.port = port;
      this.path = path;
      this.query = query;
      this.fragment = fragment;
    }
  }
  var empty = /* @__PURE__ */ new Uri(/* @__PURE__ */ new None, /* @__PURE__ */ new None, /* @__PURE__ */ new None, /* @__PURE__ */ new None, "", /* @__PURE__ */ new None, /* @__PURE__ */ new None);
  function is_valid_host_within_brackets_char(char) {
    return 48 >= char && char <= 57 || 65 >= char && char <= 90 || 97 >= char && char <= 122 || char === 58 || char === 46;
  }
  function parse_fragment(rest, pieces) {
    return new Ok(new Uri(pieces.scheme, pieces.userinfo, pieces.host, pieces.port, pieces.path, pieces.query, new Some(rest)));
  }
  function parse_query_with_question_mark_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
    while (true) {
      let original = loop$original;
      let uri_string = loop$uri_string;
      let pieces = loop$pieces;
      let size2 = loop$size;
      if (uri_string.startsWith("#")) {
        if (size2 === 0) {
          let rest = uri_string.slice(1);
          return parse_fragment(rest, pieces);
        } else {
          let rest = uri_string.slice(1);
          let query = string_codeunit_slice(original, 0, size2);
          let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, pieces.host, pieces.port, pieces.path, new Some(query), pieces.fragment);
          return parse_fragment(rest, pieces$1);
        }
      } else if (uri_string === "") {
        return new Ok(new Uri(pieces.scheme, pieces.userinfo, pieces.host, pieces.port, pieces.path, new Some(original), pieces.fragment));
      } else {
        let $ = pop_codeunit(uri_string);
        let rest;
        rest = $[1];
        loop$original = original;
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$size = size2 + 1;
      }
    }
  }
  function parse_query_with_question_mark(uri_string, pieces) {
    return parse_query_with_question_mark_loop(uri_string, uri_string, pieces, 0);
  }
  function parse_path_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
    while (true) {
      let original = loop$original;
      let uri_string = loop$uri_string;
      let pieces = loop$pieces;
      let size2 = loop$size;
      if (uri_string.startsWith("?")) {
        let rest = uri_string.slice(1);
        let path = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, pieces.host, pieces.port, path, pieces.query, pieces.fragment);
        return parse_query_with_question_mark(rest, pieces$1);
      } else if (uri_string.startsWith("#")) {
        let rest = uri_string.slice(1);
        let path = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, pieces.host, pieces.port, path, pieces.query, pieces.fragment);
        return parse_fragment(rest, pieces$1);
      } else if (uri_string === "") {
        return new Ok(new Uri(pieces.scheme, pieces.userinfo, pieces.host, pieces.port, original, pieces.query, pieces.fragment));
      } else {
        let $ = pop_codeunit(uri_string);
        let rest;
        rest = $[1];
        loop$original = original;
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$size = size2 + 1;
      }
    }
  }
  function parse_path(uri_string, pieces) {
    return parse_path_loop(uri_string, uri_string, pieces, 0);
  }
  function parse_port_loop(loop$uri_string, loop$pieces, loop$port) {
    while (true) {
      let uri_string = loop$uri_string;
      let pieces = loop$pieces;
      let port = loop$port;
      if (uri_string.startsWith("0")) {
        let rest = uri_string.slice(1);
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$port = port * 10;
      } else if (uri_string.startsWith("1")) {
        let rest = uri_string.slice(1);
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$port = port * 10 + 1;
      } else if (uri_string.startsWith("2")) {
        let rest = uri_string.slice(1);
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$port = port * 10 + 2;
      } else if (uri_string.startsWith("3")) {
        let rest = uri_string.slice(1);
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$port = port * 10 + 3;
      } else if (uri_string.startsWith("4")) {
        let rest = uri_string.slice(1);
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$port = port * 10 + 4;
      } else if (uri_string.startsWith("5")) {
        let rest = uri_string.slice(1);
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$port = port * 10 + 5;
      } else if (uri_string.startsWith("6")) {
        let rest = uri_string.slice(1);
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$port = port * 10 + 6;
      } else if (uri_string.startsWith("7")) {
        let rest = uri_string.slice(1);
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$port = port * 10 + 7;
      } else if (uri_string.startsWith("8")) {
        let rest = uri_string.slice(1);
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$port = port * 10 + 8;
      } else if (uri_string.startsWith("9")) {
        let rest = uri_string.slice(1);
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$port = port * 10 + 9;
      } else if (uri_string.startsWith("?")) {
        let rest = uri_string.slice(1);
        let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, pieces.host, new Some(port), pieces.path, pieces.query, pieces.fragment);
        return parse_query_with_question_mark(rest, pieces$1);
      } else if (uri_string.startsWith("#")) {
        let rest = uri_string.slice(1);
        let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, pieces.host, new Some(port), pieces.path, pieces.query, pieces.fragment);
        return parse_fragment(rest, pieces$1);
      } else if (uri_string.startsWith("/")) {
        let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, pieces.host, new Some(port), pieces.path, pieces.query, pieces.fragment);
        return parse_path(uri_string, pieces$1);
      } else if (uri_string === "") {
        return new Ok(new Uri(pieces.scheme, pieces.userinfo, pieces.host, new Some(port), pieces.path, pieces.query, pieces.fragment));
      } else {
        return new Error(undefined);
      }
    }
  }
  function parse_port(uri_string, pieces) {
    if (uri_string.startsWith(":0")) {
      let rest = uri_string.slice(2);
      return parse_port_loop(rest, pieces, 0);
    } else if (uri_string.startsWith(":1")) {
      let rest = uri_string.slice(2);
      return parse_port_loop(rest, pieces, 1);
    } else if (uri_string.startsWith(":2")) {
      let rest = uri_string.slice(2);
      return parse_port_loop(rest, pieces, 2);
    } else if (uri_string.startsWith(":3")) {
      let rest = uri_string.slice(2);
      return parse_port_loop(rest, pieces, 3);
    } else if (uri_string.startsWith(":4")) {
      let rest = uri_string.slice(2);
      return parse_port_loop(rest, pieces, 4);
    } else if (uri_string.startsWith(":5")) {
      let rest = uri_string.slice(2);
      return parse_port_loop(rest, pieces, 5);
    } else if (uri_string.startsWith(":6")) {
      let rest = uri_string.slice(2);
      return parse_port_loop(rest, pieces, 6);
    } else if (uri_string.startsWith(":7")) {
      let rest = uri_string.slice(2);
      return parse_port_loop(rest, pieces, 7);
    } else if (uri_string.startsWith(":8")) {
      let rest = uri_string.slice(2);
      return parse_port_loop(rest, pieces, 8);
    } else if (uri_string.startsWith(":9")) {
      let rest = uri_string.slice(2);
      return parse_port_loop(rest, pieces, 9);
    } else if (uri_string === ":") {
      return new Ok(pieces);
    } else if (uri_string === "") {
      return new Ok(pieces);
    } else if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      return parse_query_with_question_mark(rest, pieces);
    } else if (uri_string.startsWith(":?")) {
      let rest = uri_string.slice(2);
      return parse_query_with_question_mark(rest, pieces);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      return parse_fragment(rest, pieces);
    } else if (uri_string.startsWith(":#")) {
      let rest = uri_string.slice(2);
      return parse_fragment(rest, pieces);
    } else if (uri_string.startsWith("/")) {
      return parse_path(uri_string, pieces);
    } else if (uri_string.startsWith(":")) {
      let rest = uri_string.slice(1);
      if (rest.startsWith("/")) {
        return parse_path(rest, pieces);
      } else {
        return new Error(undefined);
      }
    } else {
      return new Error(undefined);
    }
  }
  function parse_host_outside_of_brackets_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
    while (true) {
      let original = loop$original;
      let uri_string = loop$uri_string;
      let pieces = loop$pieces;
      let size2 = loop$size;
      if (uri_string === "") {
        return new Ok(new Uri(pieces.scheme, pieces.userinfo, new Some(original), pieces.port, pieces.path, pieces.query, pieces.fragment));
      } else if (uri_string.startsWith(":")) {
        let host = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, new Some(host), pieces.port, pieces.path, pieces.query, pieces.fragment);
        return parse_port(uri_string, pieces$1);
      } else if (uri_string.startsWith("/")) {
        let host = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, new Some(host), pieces.port, pieces.path, pieces.query, pieces.fragment);
        return parse_path(uri_string, pieces$1);
      } else if (uri_string.startsWith("?")) {
        let rest = uri_string.slice(1);
        let host = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, new Some(host), pieces.port, pieces.path, pieces.query, pieces.fragment);
        return parse_query_with_question_mark(rest, pieces$1);
      } else if (uri_string.startsWith("#")) {
        let rest = uri_string.slice(1);
        let host = string_codeunit_slice(original, 0, size2);
        let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, new Some(host), pieces.port, pieces.path, pieces.query, pieces.fragment);
        return parse_fragment(rest, pieces$1);
      } else {
        let $ = pop_codeunit(uri_string);
        let rest;
        rest = $[1];
        loop$original = original;
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$size = size2 + 1;
      }
    }
  }
  function parse_host_within_brackets_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
    while (true) {
      let original = loop$original;
      let uri_string = loop$uri_string;
      let pieces = loop$pieces;
      let size2 = loop$size;
      if (uri_string === "") {
        return new Ok(new Uri(pieces.scheme, pieces.userinfo, new Some(uri_string), pieces.port, pieces.path, pieces.query, pieces.fragment));
      } else if (uri_string.startsWith("]")) {
        if (size2 === 0) {
          let rest = uri_string.slice(1);
          return parse_port(rest, pieces);
        } else {
          let rest = uri_string.slice(1);
          let host = string_codeunit_slice(original, 0, size2 + 1);
          let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, new Some(host), pieces.port, pieces.path, pieces.query, pieces.fragment);
          return parse_port(rest, pieces$1);
        }
      } else if (uri_string.startsWith("/")) {
        if (size2 === 0) {
          return parse_path(uri_string, pieces);
        } else {
          let host = string_codeunit_slice(original, 0, size2);
          let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, new Some(host), pieces.port, pieces.path, pieces.query, pieces.fragment);
          return parse_path(uri_string, pieces$1);
        }
      } else if (uri_string.startsWith("?")) {
        if (size2 === 0) {
          let rest = uri_string.slice(1);
          return parse_query_with_question_mark(rest, pieces);
        } else {
          let rest = uri_string.slice(1);
          let host = string_codeunit_slice(original, 0, size2);
          let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, new Some(host), pieces.port, pieces.path, pieces.query, pieces.fragment);
          return parse_query_with_question_mark(rest, pieces$1);
        }
      } else if (uri_string.startsWith("#")) {
        if (size2 === 0) {
          let rest = uri_string.slice(1);
          return parse_fragment(rest, pieces);
        } else {
          let rest = uri_string.slice(1);
          let host = string_codeunit_slice(original, 0, size2);
          let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, new Some(host), pieces.port, pieces.path, pieces.query, pieces.fragment);
          return parse_fragment(rest, pieces$1);
        }
      } else {
        let $ = pop_codeunit(uri_string);
        let char;
        let rest;
        char = $[0];
        rest = $[1];
        let $1 = is_valid_host_within_brackets_char(char);
        if ($1) {
          loop$original = original;
          loop$uri_string = rest;
          loop$pieces = pieces;
          loop$size = size2 + 1;
        } else {
          return parse_host_outside_of_brackets_loop(original, original, pieces, 0);
        }
      }
    }
  }
  function parse_host_within_brackets(uri_string, pieces) {
    return parse_host_within_brackets_loop(uri_string, uri_string, pieces, 0);
  }
  function parse_host_outside_of_brackets(uri_string, pieces) {
    return parse_host_outside_of_brackets_loop(uri_string, uri_string, pieces, 0);
  }
  function parse_host(uri_string, pieces) {
    if (uri_string.startsWith("[")) {
      return parse_host_within_brackets(uri_string, pieces);
    } else if (uri_string.startsWith(":")) {
      let pieces$1 = new Uri(pieces.scheme, pieces.userinfo, new Some(""), pieces.port, pieces.path, pieces.query, pieces.fragment);
      return parse_port(uri_string, pieces$1);
    } else if (uri_string === "") {
      return new Ok(new Uri(pieces.scheme, pieces.userinfo, new Some(""), pieces.port, pieces.path, pieces.query, pieces.fragment));
    } else {
      return parse_host_outside_of_brackets(uri_string, pieces);
    }
  }
  function parse_userinfo_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
    while (true) {
      let original = loop$original;
      let uri_string = loop$uri_string;
      let pieces = loop$pieces;
      let size2 = loop$size;
      if (uri_string.startsWith("@")) {
        if (size2 === 0) {
          let rest = uri_string.slice(1);
          return parse_host(rest, pieces);
        } else {
          let rest = uri_string.slice(1);
          let userinfo = string_codeunit_slice(original, 0, size2);
          let pieces$1 = new Uri(pieces.scheme, new Some(userinfo), pieces.host, pieces.port, pieces.path, pieces.query, pieces.fragment);
          return parse_host(rest, pieces$1);
        }
      } else if (uri_string === "") {
        return parse_host(original, pieces);
      } else if (uri_string.startsWith("/")) {
        return parse_host(original, pieces);
      } else if (uri_string.startsWith("?")) {
        return parse_host(original, pieces);
      } else if (uri_string.startsWith("#")) {
        return parse_host(original, pieces);
      } else {
        let $ = pop_codeunit(uri_string);
        let rest;
        rest = $[1];
        loop$original = original;
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$size = size2 + 1;
      }
    }
  }
  function parse_authority_pieces(string2, pieces) {
    return parse_userinfo_loop(string2, string2, pieces, 0);
  }
  function parse_authority_with_slashes(uri_string, pieces) {
    if (uri_string === "//") {
      return new Ok(new Uri(pieces.scheme, pieces.userinfo, new Some(""), pieces.port, pieces.path, pieces.query, pieces.fragment));
    } else if (uri_string.startsWith("//")) {
      let rest = uri_string.slice(2);
      return parse_authority_pieces(rest, pieces);
    } else {
      return parse_path(uri_string, pieces);
    }
  }
  function parse_scheme_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
    while (true) {
      let original = loop$original;
      let uri_string = loop$uri_string;
      let pieces = loop$pieces;
      let size2 = loop$size;
      if (uri_string.startsWith("/")) {
        if (size2 === 0) {
          return parse_authority_with_slashes(uri_string, pieces);
        } else {
          let scheme = string_codeunit_slice(original, 0, size2);
          let pieces$1 = new Uri(new Some(lowercase(scheme)), pieces.userinfo, pieces.host, pieces.port, pieces.path, pieces.query, pieces.fragment);
          return parse_authority_with_slashes(uri_string, pieces$1);
        }
      } else if (uri_string.startsWith("?")) {
        if (size2 === 0) {
          let rest = uri_string.slice(1);
          return parse_query_with_question_mark(rest, pieces);
        } else {
          let rest = uri_string.slice(1);
          let scheme = string_codeunit_slice(original, 0, size2);
          let pieces$1 = new Uri(new Some(lowercase(scheme)), pieces.userinfo, pieces.host, pieces.port, pieces.path, pieces.query, pieces.fragment);
          return parse_query_with_question_mark(rest, pieces$1);
        }
      } else if (uri_string.startsWith("#")) {
        if (size2 === 0) {
          let rest = uri_string.slice(1);
          return parse_fragment(rest, pieces);
        } else {
          let rest = uri_string.slice(1);
          let scheme = string_codeunit_slice(original, 0, size2);
          let pieces$1 = new Uri(new Some(lowercase(scheme)), pieces.userinfo, pieces.host, pieces.port, pieces.path, pieces.query, pieces.fragment);
          return parse_fragment(rest, pieces$1);
        }
      } else if (uri_string.startsWith(":")) {
        if (size2 === 0) {
          return new Error(undefined);
        } else {
          let rest = uri_string.slice(1);
          let scheme = string_codeunit_slice(original, 0, size2);
          let pieces$1 = new Uri(new Some(lowercase(scheme)), pieces.userinfo, pieces.host, pieces.port, pieces.path, pieces.query, pieces.fragment);
          return parse_authority_with_slashes(rest, pieces$1);
        }
      } else if (uri_string === "") {
        return new Ok(new Uri(pieces.scheme, pieces.userinfo, pieces.host, pieces.port, original, pieces.query, pieces.fragment));
      } else {
        let $ = pop_codeunit(uri_string);
        let rest;
        rest = $[1];
        loop$original = original;
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$size = size2 + 1;
      }
    }
  }
  function to_string2(uri) {
    let _block;
    let $ = uri.fragment;
    if ($ instanceof Some) {
      let fragment = $[0];
      _block = toList(["#", fragment]);
    } else {
      _block = toList([]);
    }
    let parts = _block;
    let _block$1;
    let $1 = uri.query;
    if ($1 instanceof Some) {
      let query = $1[0];
      _block$1 = prepend("?", prepend(query, parts));
    } else {
      _block$1 = parts;
    }
    let parts$1 = _block$1;
    let parts$2 = prepend(uri.path, parts$1);
    let _block$2;
    let $2 = uri.host;
    let $3 = starts_with(uri.path, "/");
    if ($2 instanceof Some && !$3) {
      let host = $2[0];
      if (host !== "") {
        _block$2 = prepend("/", parts$2);
      } else {
        _block$2 = parts$2;
      }
    } else {
      _block$2 = parts$2;
    }
    let parts$3 = _block$2;
    let _block$3;
    let $4 = uri.host;
    let $5 = uri.port;
    if ($4 instanceof Some && $5 instanceof Some) {
      let port = $5[0];
      _block$3 = prepend(":", prepend(to_string(port), parts$3));
    } else {
      _block$3 = parts$3;
    }
    let parts$4 = _block$3;
    let _block$4;
    let $6 = uri.scheme;
    let $7 = uri.userinfo;
    let $8 = uri.host;
    if ($6 instanceof Some) {
      if ($7 instanceof Some) {
        if ($8 instanceof Some) {
          let s = $6[0];
          let u = $7[0];
          let h = $8[0];
          _block$4 = prepend(s, prepend("://", prepend(u, prepend("@", prepend(h, parts$4)))));
        } else {
          let s = $6[0];
          _block$4 = prepend(s, prepend(":", parts$4));
        }
      } else if ($8 instanceof Some) {
        let s = $6[0];
        let h = $8[0];
        _block$4 = prepend(s, prepend("://", prepend(h, parts$4)));
      } else {
        let s = $6[0];
        _block$4 = prepend(s, prepend(":", parts$4));
      }
    } else if ($7 instanceof None && $8 instanceof Some) {
      let h = $8[0];
      _block$4 = prepend("//", prepend(h, parts$4));
    } else {
      _block$4 = parts$4;
    }
    let parts$5 = _block$4;
    return concat2(parts$5);
  }
  function parse(uri_string) {
    return parse_scheme_loop(uri_string, uri_string, empty, 0);
  }
  // build/dev/javascript/gleam_http/gleam/http.mjs
  class Get extends CustomType {
  }
  class Post extends CustomType {
  }
  class Head extends CustomType {
  }
  class Put extends CustomType {
  }
  class Delete extends CustomType {
  }
  class Trace extends CustomType {
  }
  class Connect extends CustomType {
  }
  class Options extends CustomType {
  }
  class Patch extends CustomType {
  }
  class Http extends CustomType {
  }
  class Https extends CustomType {
  }
  function method_to_string(method) {
    if (method instanceof Get) {
      return "GET";
    } else if (method instanceof Post) {
      return "POST";
    } else if (method instanceof Head) {
      return "HEAD";
    } else if (method instanceof Put) {
      return "PUT";
    } else if (method instanceof Delete) {
      return "DELETE";
    } else if (method instanceof Trace) {
      return "TRACE";
    } else if (method instanceof Connect) {
      return "CONNECT";
    } else if (method instanceof Options) {
      return "OPTIONS";
    } else if (method instanceof Patch) {
      return "PATCH";
    } else {
      let method$1 = method[0];
      return method$1;
    }
  }
  function scheme_to_string(scheme) {
    if (scheme instanceof Http) {
      return "http";
    } else {
      return "https";
    }
  }
  function scheme_from_string(scheme) {
    let $ = lowercase(scheme);
    if ($ === "http") {
      return new Ok(new Http);
    } else if ($ === "https") {
      return new Ok(new Https);
    } else {
      return new Error(undefined);
    }
  }

  // build/dev/javascript/gleam_http/gleam/http/request.mjs
  class Request extends CustomType {
    constructor(method, headers, body, scheme, host, port, path, query) {
      super();
      this.method = method;
      this.headers = headers;
      this.body = body;
      this.scheme = scheme;
      this.host = host;
      this.port = port;
      this.path = path;
      this.query = query;
    }
  }
  function to_uri(request) {
    return new Uri(new Some(scheme_to_string(request.scheme)), new None, new Some(request.host), request.port, request.path, request.query, new None);
  }
  function from_uri(uri) {
    return try$((() => {
      let _pipe = uri.scheme;
      let _pipe$1 = unwrap(_pipe, "");
      return scheme_from_string(_pipe$1);
    })(), (scheme) => {
      return try$((() => {
        let _pipe = uri.host;
        return to_result(_pipe, undefined);
      })(), (host) => {
        let req = new Request(new Get, toList([]), "", scheme, host, uri.port, uri.path, uri.query);
        return new Ok(req);
      });
    });
  }
  function prepend_header(request, key, value) {
    let headers = prepend([lowercase(key), value], request.headers);
    return new Request(request.method, headers, request.body, request.scheme, request.host, request.port, request.path, request.query);
  }
  function set_body(req, body) {
    return new Request(req.method, req.headers, body, req.scheme, req.host, req.port, req.path, req.query);
  }
  function set_method(req, method) {
    return new Request(method, req.headers, req.body, req.scheme, req.host, req.port, req.path, req.query);
  }
  function to(url) {
    let _pipe = url;
    let _pipe$1 = parse(_pipe);
    return try$(_pipe$1, from_uri);
  }

  // build/dev/javascript/gleam_http/gleam/http/response.mjs
  class Response extends CustomType {
    constructor(status, headers, body) {
      super();
      this.status = status;
      this.headers = headers;
      this.body = body;
    }
  }
  var Response$Response = (status, headers, body) => new Response(status, headers, body);
  // build/dev/javascript/gleam_javascript/gleam_javascript_ffi.mjs
  class PromiseLayer {
    constructor(promise) {
      this.promise = promise;
    }
    static wrap(value) {
      return value instanceof Promise ? new PromiseLayer(value) : value;
    }
    static unwrap(value) {
      return value instanceof PromiseLayer ? value.promise : value;
    }
  }
  function resolve(value) {
    return Promise.resolve(PromiseLayer.wrap(value));
  }
  function then_await(promise, fn) {
    return promise.then((value) => fn(PromiseLayer.unwrap(value)));
  }
  function map_promise(promise, fn) {
    return promise.then((value) => PromiseLayer.wrap(fn(PromiseLayer.unwrap(value))));
  }

  // build/dev/javascript/gleam_javascript/gleam/javascript/promise.mjs
  function try_await(promise, callback) {
    let _pipe = promise;
    return then_await(_pipe, (result) => {
      if (result instanceof Ok) {
        let a = result[0];
        return callback(a);
      } else {
        let e = result[0];
        return resolve(new Error(e));
      }
    });
  }
  // build/dev/javascript/gleam_fetch/gleam_fetch_ffi.mjs
  async function raw_send(request) {
    try {
      return Result$Ok(await fetch(request));
    } catch (error) {
      return Result$Error(FetchError$NetworkError(error.toString()));
    }
  }
  function from_fetch_response(response) {
    let headers = [...response.headers].reverse();
    return Response$Response(response.status, arrayToList(headers), response);
  }
  function request_common(request) {
    let url = to_string2(to_uri(request));
    let method = method_to_string(request.method).toUpperCase();
    let options = {
      headers: make_headers(request.headers),
      method
    };
    return [url, options];
  }
  function to_fetch_request(request) {
    let [url, options] = request_common(request);
    if (options.method !== "GET" && options.method !== "HEAD")
      options.body = request.body;
    return new globalThis.Request(url, options);
  }
  function make_headers(headersList) {
    let headers = new globalThis.Headers;
    for (let [k, v] of headersList)
      headers.append(k.toLowerCase(), v);
    return headers;
  }
  function arrayToList(array) {
    let list2 = List$Empty();
    for (const element of array) {
      list2 = List$NonEmpty(element, list2);
    }
    return list2;
  }

  // build/dev/javascript/gleam_fetch/gleam/fetch.mjs
  class NetworkError extends CustomType {
    constructor($0) {
      super();
      this[0] = $0;
    }
  }
  var FetchError$NetworkError = ($0) => new NetworkError($0);
  class UnableToReadBody extends CustomType {
  }
  function send(request) {
    let _pipe = request;
    let _pipe$1 = to_fetch_request(_pipe);
    let _pipe$2 = raw_send(_pipe$1);
    return try_await(_pipe$2, (resp) => {
      return resolve(new Ok(from_fetch_response(resp)));
    });
  }
  // build/dev/javascript/gleam_json/gleam_json_ffi.mjs
  function json_to_string(json) {
    return JSON.stringify(json);
  }
  function object(entries) {
    return Object.fromEntries(entries);
  }
  function identity2(x) {
    return x;
  }

  // build/dev/javascript/gleam_json/gleam/json.mjs
  function to_string3(json) {
    return json_to_string(json);
  }
  function string2(input) {
    return identity2(input);
  }
  function int2(input) {
    return identity2(input);
  }
  function object2(entries) {
    return object(entries);
  }
  // build/dev/javascript/shared/shared/extension.mjs
  class ErrorReport extends CustomType {
    constructor(error, extension_version, timestamp_seconds, timestamp_nanoseconds) {
      super();
      this.error = error;
      this.extension_version = extension_version;
      this.timestamp_seconds = timestamp_seconds;
      this.timestamp_nanoseconds = timestamp_nanoseconds;
    }
  }
  function error_report_to_json(report) {
    let error;
    let extension_version;
    let timestamp_seconds;
    let timestamp_nanoseconds;
    error = report.error;
    extension_version = report.extension_version;
    timestamp_seconds = report.timestamp_seconds;
    timestamp_nanoseconds = report.timestamp_nanoseconds;
    return object2(toList([
      ["error", string2(error)],
      ["extension_version", string2(extension_version)],
      ["timestamp_seconds", int2(timestamp_seconds)],
      ["timestamp_nanoseconds", int2(timestamp_nanoseconds)]
    ]));
  }
  // build/dev/javascript/extension/bridge.mjs
  class ForwardReview extends CustomType {
    constructor(forward_url, error_url, body, timestamp_seconds, timestamp_nanoseconds) {
      super();
      this.forward_url = forward_url;
      this.error_url = error_url;
      this.body = body;
      this.timestamp_seconds = timestamp_seconds;
      this.timestamp_nanoseconds = timestamp_nanoseconds;
    }
  }
  var BackgroundMessage$ForwardReview = (forward_url, error_url, body, timestamp_seconds, timestamp_nanoseconds) => new ForwardReview(forward_url, error_url, body, timestamp_seconds, timestamp_nanoseconds);
  class ReportError extends CustomType {
    constructor(error_url, error, timestamp_seconds, timestamp_nanoseconds) {
      super();
      this.error_url = error_url;
      this.error = error;
      this.timestamp_seconds = timestamp_seconds;
      this.timestamp_nanoseconds = timestamp_nanoseconds;
    }
  }
  var BackgroundMessage$ReportError = (error_url, error, timestamp_seconds, timestamp_nanoseconds) => new ReportError(error_url, error, timestamp_seconds, timestamp_nanoseconds);
  class BackgroundRuntimeUnavailable extends CustomType {
  }
  var BackgroundListenerError$BackgroundRuntimeUnavailable = () => new BackgroundRuntimeUnavailable;
  class InvalidMessage extends CustomType {
    constructor($0) {
      super();
      this[0] = $0;
    }
  }
  var BackgroundListenerError$InvalidMessage = ($0) => new InvalidMessage($0);

  // build/dev/javascript/extension/background_ffi.mjs
  function runtime() {
    return globalThis.chrome?.runtime ?? globalThis.browser?.runtime ?? null;
  }
  function invalid_message(detail) {
    return new Error(BackgroundListenerError$InvalidMessage(detail));
  }
  function parse_forward_evaluation(message) {
    if (typeof message.forward_url !== "string") {
      return invalid_message("forward_evaluation.forward_url_was_not_string");
    }
    if (typeof message.error_url !== "string") {
      return invalid_message("forward_evaluation.error_url_was_not_string");
    }
    if (typeof message.body !== "string") {
      return invalid_message("forward_evaluation.body_was_not_string");
    }
    if (!Number.isInteger(message.timestamp_seconds)) {
      return invalid_message("forward_evaluation.timestamp_seconds_was_not_int");
    }
    if (!Number.isInteger(message.timestamp_nanoseconds)) {
      return invalid_message("forward_evaluation.timestamp_nanoseconds_was_not_int");
    }
    return new Ok(BackgroundMessage$ForwardReview(message.forward_url, message.error_url, message.body, message.timestamp_seconds, message.timestamp_nanoseconds));
  }
  function parse_report_error(message) {
    if (typeof message.error_url !== "string") {
      return invalid_message("report_error.error_url_was_not_string");
    }
    if (typeof message.error !== "string") {
      return invalid_message("report_error.error_was_not_string");
    }
    if (!Number.isInteger(message.timestamp_seconds)) {
      return invalid_message("report_error.timestamp_seconds_was_not_int");
    }
    if (!Number.isInteger(message.timestamp_nanoseconds)) {
      return invalid_message("report_error.timestamp_nanoseconds_was_not_int");
    }
    return new Ok(BackgroundMessage$ReportError(message.error_url, message.error, message.timestamp_seconds, message.timestamp_nanoseconds));
  }
  function install_listener(callback) {
    const ext_runtime = runtime();
    if (ext_runtime === null) {
      return new Error(BackgroundListenerError$BackgroundRuntimeUnavailable());
    }
    ext_runtime.onMessage.addListener((message) => {
      if (message === null || typeof message !== "object") {
        callback(invalid_message("message_was_not_object"));
        return;
      }
      switch (message.type) {
        case "forward_evaluation":
          callback(parse_forward_evaluation(message));
          break;
        case "report_error":
          callback(parse_report_error(message));
          break;
        default:
          callback(invalid_message(`unknown_message_type:${String(message.type)}`));
          break;
      }
    });
    return new Ok(undefined);
  }
  function extension_version() {
    return runtime()?.getManifest?.().version ?? "unknown";
  }
  function log_error(message) {
    console.error(message);
  }

  // build/dev/javascript/extension/error.mjs
  class SubmitEventTargetWasNotForm extends CustomType {
  }
  class ContentRuntimeUnavailable extends CustomType {
  }
  class ContentMessageDispatchRejected extends CustomType {
    constructor($0) {
      super();
      this[0] = $0;
    }
  }
  class BackgroundRuntimeUnavailable2 extends CustomType {
  }
  class BackgroundInvalidMessage extends CustomType {
    constructor($0) {
      super();
      this[0] = $0;
    }
  }
  class ForwardRequestBuildError extends CustomType {
  }
  class ForwardNon2xx extends CustomType {
    constructor($0) {
      super();
      this[0] = $0;
    }
  }
  class ForwardFetchError extends CustomType {
    constructor($0) {
      super();
      this[0] = $0;
    }
  }
  class ErrorReportRequestBuildError extends CustomType {
  }
  class ErrorReportNon2xx extends CustomType {
    constructor($0) {
      super();
      this[0] = $0;
    }
  }
  class ErrorReportFetchError extends CustomType {
    constructor($0) {
      super();
      this[0] = $0;
    }
  }
  function from_background_listener_error(error) {
    if (error instanceof BackgroundRuntimeUnavailable) {
      return new BackgroundRuntimeUnavailable2;
    } else {
      let message = error[0];
      return new BackgroundInvalidMessage(message);
    }
  }
  function to_string4(error) {
    if (error instanceof SubmitEventTargetWasNotForm) {
      return "submit_event_target_was_not_form";
    } else if (error instanceof ContentRuntimeUnavailable) {
      return "content_runtime_unavailable";
    } else if (error instanceof ContentMessageDispatchRejected) {
      let message = error[0];
      return "content_message_dispatch_rejected:" + message;
    } else if (error instanceof BackgroundRuntimeUnavailable2) {
      return "background_runtime_unavailable";
    } else if (error instanceof BackgroundInvalidMessage) {
      let message = error[0];
      return "background_invalid_message:" + message;
    } else if (error instanceof ForwardRequestBuildError) {
      return "forward_request_build_error";
    } else if (error instanceof ForwardNon2xx) {
      let status = error[0];
      return "forward_non_2xx:" + to_string(status);
    } else if (error instanceof ForwardFetchError) {
      let $ = error[0];
      if ($ instanceof NetworkError) {
        let message = $[0];
        return "forward_network_error:" + message;
      } else if ($ instanceof UnableToReadBody) {
        return "forward_unable_to_read_body";
      } else {
        return "forward_invalid_json_body";
      }
    } else if (error instanceof ErrorReportRequestBuildError) {
      return "error_report_request_build_error";
    } else if (error instanceof ErrorReportNon2xx) {
      let status = error[0];
      return "error_report_non_2xx:" + to_string(status);
    } else {
      let $ = error[0];
      if ($ instanceof NetworkError) {
        let message = $[0];
        return "error_report_network_error:" + message;
      } else if ($ instanceof UnableToReadBody) {
        return "error_report_unable_to_read_body";
      } else {
        return "error_report_invalid_json_body";
      }
    }
  }

  // build/dev/javascript/extension/background.mjs
  function build_json_post_request(url, body) {
    let $ = to(url);
    if ($ instanceof Ok) {
      let request = $[0];
      return new Ok((() => {
        let _pipe = request;
        let _pipe$1 = set_method(_pipe, new Post);
        let _pipe$2 = set_body(_pipe$1, body);
        return prepend_header(_pipe$2, "content-type", "application/json");
      })());
    } else {
      return new Error(undefined);
    }
  }
  function build_forward_request(forward_url, body) {
    let $ = build_json_post_request(forward_url, body);
    if ($ instanceof Ok) {
      return $;
    } else {
      return new Error(new ForwardRequestBuildError);
    }
  }
  function build_error_report_request(error_url, body) {
    let $ = build_json_post_request(error_url, body);
    if ($ instanceof Ok) {
      return $;
    } else {
      return new Error(new ErrorReportRequestBuildError);
    }
  }
  function send_error_report(error_url, client_error, timestamp_seconds, timestamp_nanoseconds) {
    let current_extension_version = extension_version();
    let $ = build_error_report_request(error_url, (() => {
      let _pipe = new ErrorReport(client_error, current_extension_version, timestamp_seconds, timestamp_nanoseconds);
      let _pipe$1 = error_report_to_json(_pipe);
      return to_string3(_pipe$1);
    })());
    if ($ instanceof Ok) {
      let request = $[0];
      let _pipe = request;
      let _pipe$1 = send(_pipe);
      return map_promise(_pipe$1, (result) => {
        if (result instanceof Ok) {
          let response = result[0];
          let $1 = response.status >= 200 && response.status < 300;
          if ($1) {
            return new Ok(undefined);
          } else {
            return new Error(new ErrorReportNon2xx(response.status));
          }
        } else {
          let fetch_error = result[0];
          return new Error(new ErrorReportFetchError(fetch_error));
        }
      });
    } else {
      let client_error$1 = $[0];
      return resolve(new Error(client_error$1));
    }
  }
  function process_report_error(error_url, client_error, timestamp_seconds, timestamp_nanoseconds) {
    let _pipe = send_error_report(error_url, client_error, timestamp_seconds, timestamp_nanoseconds);
    return map_promise(_pipe, (result) => {
      if (result instanceof Ok) {
        return;
      } else {
        let report_error = result[0];
        return log_error(to_string4(report_error));
      }
    });
  }
  function report_client_error(error_url, client_error, timestamp_seconds, timestamp_nanoseconds) {
    let _pipe = send_error_report(error_url, to_string4(client_error), timestamp_seconds, timestamp_nanoseconds);
    return map_promise(_pipe, (result) => {
      if (result instanceof Ok) {
        return;
      } else {
        let report_error = result[0];
        return log_error(to_string4(report_error));
      }
    });
  }
  function process_forward_evaluation(forward_url, error_url, body, timestamp_seconds, timestamp_nanoseconds) {
    let $ = build_forward_request(forward_url, body);
    if ($ instanceof Ok) {
      let request = $[0];
      let _pipe = request;
      let _pipe$1 = send(_pipe);
      return then_await(_pipe$1, (result) => {
        if (result instanceof Ok) {
          let response = result[0];
          let $1 = response.status >= 200 && response.status < 300;
          if ($1) {
            return resolve(undefined);
          } else {
            return report_client_error(error_url, new ForwardNon2xx(response.status), timestamp_seconds, timestamp_nanoseconds);
          }
        } else {
          let fetch_error = result[0];
          return report_client_error(error_url, new ForwardFetchError(fetch_error), timestamp_seconds, timestamp_nanoseconds);
        }
      });
    } else {
      let client_error = $[0];
      return report_client_error(error_url, client_error, timestamp_seconds, timestamp_nanoseconds);
    }
  }
  function handle_message(result) {
    if (result instanceof Ok) {
      let message = result[0];
      let _block;
      if (message instanceof ForwardReview) {
        let forward_url = message.forward_url;
        let error_url = message.error_url;
        let body = message.body;
        let timestamp_seconds = message.timestamp_seconds;
        let timestamp_nanoseconds = message.timestamp_nanoseconds;
        _block = process_forward_evaluation(forward_url, error_url, body, timestamp_seconds, timestamp_nanoseconds);
      } else {
        let error_url = message.error_url;
        let error = message.error;
        let timestamp_seconds = message.timestamp_seconds;
        let timestamp_nanoseconds = message.timestamp_nanoseconds;
        _block = process_report_error(error_url, error, timestamp_seconds, timestamp_nanoseconds);
      }
      let $ = _block;
      return;
    } else {
      let listener_error = result[0];
      log_error(to_string4(from_background_listener_error(listener_error)));
      return;
    }
  }
  function main() {
    let $ = install_listener(handle_message);
    if ($ instanceof Ok) {
      return;
    } else {
      let listener_error = $[0];
      return log_error(to_string4(from_background_listener_error(listener_error)));
    }
  }

  // src/background_entry.mjs
  main();
})();
