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
  var List$isEmpty = (value) => value instanceof Empty;

  class NonEmpty extends List {
    constructor(head, tail) {
      super();
      this.head = head;
      this.tail = tail;
    }
  }
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
  class Error extends Result {
    constructor(detail) {
      super();
      this[0] = detail;
    }
    isOk() {
      return false;
    }
  }
  function remainderInt(a, b) {
    if (b === 0) {
      return 0;
    } else {
      return a % b;
    }
  }
  function divideInt(a, b) {
    return Math.trunc(divideFloat(a, b));
  }
  function divideFloat(a, b) {
    if (b === 0) {
      return 0;
    } else {
      return a / b;
    }
  }
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

  // build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs
  function to_string(term) {
    return term.toString();
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
  function map_promise(promise, fn) {
    return promise.then((value) => PromiseLayer.wrap(fn(PromiseLayer.unwrap(value))));
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
  function to_string2(json) {
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
  // build/dev/javascript/gleam_time/gleam_time_ffi.mjs
  function system_time() {
    const now = Date.now();
    const milliseconds = now % 1000;
    const nanoseconds = milliseconds * 1e6;
    const seconds = (now - milliseconds) / 1000;
    return [seconds, nanoseconds];
  }

  // build/dev/javascript/gleam_time/gleam/time/timestamp.mjs
  class Timestamp extends CustomType {
    constructor(seconds2, nanoseconds2) {
      super();
      this.seconds = seconds2;
      this.nanoseconds = nanoseconds2;
    }
  }
  function normalise(timestamp) {
    let multiplier = 1e9;
    let nanoseconds2 = remainderInt(timestamp.nanoseconds, multiplier);
    let overflow = timestamp.nanoseconds - nanoseconds2;
    let seconds2 = timestamp.seconds + divideInt(overflow, multiplier);
    let $ = nanoseconds2 >= 0;
    if ($) {
      return new Timestamp(seconds2, nanoseconds2);
    } else {
      return new Timestamp(seconds2 - 1, multiplier + nanoseconds2);
    }
  }
  function system_time2() {
    let $ = system_time();
    let seconds2;
    let nanoseconds2;
    seconds2 = $[0];
    nanoseconds2 = $[1];
    return normalise(new Timestamp(seconds2, nanoseconds2));
  }
  function to_unix_seconds_and_nanoseconds(timestamp) {
    return [timestamp.seconds, timestamp.nanoseconds];
  }
  // build/dev/javascript/extension/bridge.mjs
  class SubmitInfo extends CustomType {
    constructor(action, method, page_url, form_id, class_name) {
      super();
      this.action = action;
      this.method = method;
      this.page_url = page_url;
      this.form_id = form_id;
      this.class_name = class_name;
    }
  }
  var SubmitInfo$SubmitInfo = (action, method, page_url, form_id, class_name) => new SubmitInfo(action, method, page_url, form_id, class_name);
  class EventTargetWasNotForm extends CustomType {
  }
  var SubmitListenerError$EventTargetWasNotForm = () => new EventTargetWasNotForm;
  class RuntimeUnavailable extends CustomType {
  }
  var RuntimeMessageError$RuntimeUnavailable = () => new RuntimeUnavailable;
  class MessageDispatchRejected extends CustomType {
    constructor($0) {
      super();
      this[0] = $0;
    }
  }
  var RuntimeMessageError$MessageDispatchRejected = ($0) => new MessageDispatchRejected($0);
  // build/dev/javascript/gleam_fetch/gleam/fetch.mjs
  class NetworkError extends CustomType {
    constructor($0) {
      super();
      this[0] = $0;
    }
  }
  class UnableToReadBody extends CustomType {
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
  function from_submit_listener_error(error) {
    return new SubmitEventTargetWasNotForm;
  }
  function from_content_runtime_message_error(error) {
    if (error instanceof RuntimeUnavailable) {
      return new ContentRuntimeUnavailable;
    } else {
      let message = error[0];
      return new ContentMessageDispatchRejected(message);
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

  // build/dev/javascript/extension/extension_ffi.mjs
  function chrome_runtime() {
    return globalThis.chrome?.runtime ?? null;
  }
  function browser_runtime() {
    return globalThis.browser?.runtime ?? null;
  }
  function runtime_unavailable_error() {
    return new Error(RuntimeMessageError$RuntimeUnavailable());
  }
  function message_dispatch_rejected_error(error) {
    return new Error(RuntimeMessageError$MessageDispatchRejected(String(error)));
  }
  function install_submit_listener(callback) {
    document.addEventListener("submit", (event) => {
      const form = event?.target;
      if (!(form instanceof HTMLFormElement)) {
        callback(new Error(SubmitListenerError$EventTargetWasNotForm()));
        return;
      }
      callback(new Ok(SubmitInfo$SubmitInfo(form.action || "", (form.method || "get").toUpperCase(), window.location.href, form.id || "", typeof form.className === "string" ? form.className : "")));
    }, true);
  }
  function extension_version() {
    const ext_runtime = chrome_runtime() ?? browser_runtime();
    return ext_runtime?.getManifest?.().version ?? "unknown";
  }
  function chrome_send_message(payload) {
    return new Promise((resolve2) => {
      const ext_runtime = chrome_runtime();
      if (ext_runtime === null) {
        resolve2(runtime_unavailable_error());
        return;
      }
      try {
        ext_runtime.sendMessage(payload, () => {
          const last_error = ext_runtime.lastError;
          if (last_error === undefined) {
            resolve2(new Ok(undefined));
            return;
          }
          const message = last_error.message ?? last_error;
          resolve2(message_dispatch_rejected_error(message));
        });
      } catch (error) {
        resolve2(message_dispatch_rejected_error(error));
      }
    });
  }
  function browser_send_message(payload) {
    const ext_runtime = browser_runtime();
    if (ext_runtime === null) {
      return Promise.resolve(runtime_unavailable_error());
    }
    try {
      return ext_runtime.sendMessage(payload).then(() => new Ok(undefined)).catch((error) => message_dispatch_rejected_error(error));
    } catch (error) {
      return Promise.resolve(message_dispatch_rejected_error(error));
    }
  }
  function send_message(payload) {
    if (chrome_runtime() !== null) {
      return chrome_send_message(payload);
    }
    if (browser_runtime() !== null) {
      return browser_send_message(payload);
    }
    return Promise.resolve(runtime_unavailable_error());
  }
  function send_forward_evaluation(forward_url, error_url, body, timestamp_seconds, timestamp_nanoseconds) {
    return send_message({
      type: "forward_evaluation",
      forward_url,
      error_url,
      body,
      timestamp_seconds,
      timestamp_nanoseconds
    });
  }
  function send_report_error(error_url, error, timestamp_seconds, timestamp_nanoseconds) {
    return send_message({
      type: "report_error",
      error_url,
      error,
      timestamp_seconds,
      timestamp_nanoseconds
    });
  }

  // build/dev/javascript/extension/extension.mjs
  var target_form_id = "__REPLACE_FORM_ID__";
  var target_form_action = "__REPLACE_FORM_ACTION__";
  var forward_url = "https://YOUR_HOSTNAME_HERE/api/evaluation/ingest";
  var error_url = "https://YOUR_HOSTNAME_HERE/api/ingest/error";
  function evaluation_body(info, current_extension_version, timestamp_seconds, timestamp_nanoseconds) {
    let action;
    let method;
    let page_url;
    let form_id;
    let class_name;
    action = info.action;
    method = info.method;
    page_url = info.page_url;
    form_id = info.form_id;
    class_name = info.class_name;
    let _pipe = object2(toList([
      ["action", string2(action)],
      ["method", string2(method)],
      ["page_url", string2(page_url)],
      ["form_id", string2(form_id)],
      ["class_name", string2(class_name)],
      ["extension_version", string2(current_extension_version)],
      ["timestamp_seconds", int2(timestamp_seconds)],
      ["timestamp_nanoseconds", int2(timestamp_nanoseconds)]
    ]));
    return to_string2(_pipe);
  }
  function now() {
    let _pipe = system_time2();
    return to_unix_seconds_and_nanoseconds(_pipe);
  }
  function should_forward(info) {
    let action;
    let form_id;
    action = info.action;
    form_id = info.form_id;
    return form_id === target_form_id || action === target_form_action;
  }
  function report_client_error(client_error, timestamp_seconds, timestamp_nanoseconds) {
    let _pipe = send_report_error(error_url, to_string4(client_error), timestamp_seconds, timestamp_nanoseconds);
    return map_promise(_pipe, (_) => {
      return;
    });
  }
  function handle_submit(result) {
    let $ = now();
    let timestamp_seconds;
    let timestamp_nanoseconds;
    timestamp_seconds = $[0];
    timestamp_nanoseconds = $[1];
    let current_extension_version = extension_version();
    if (result instanceof Ok) {
      let info = result[0];
      let $1 = should_forward(info);
      if ($1) {
        let _block;
        let _pipe = send_forward_evaluation(forward_url, error_url, evaluation_body(info, current_extension_version, timestamp_seconds, timestamp_nanoseconds), timestamp_seconds, timestamp_nanoseconds);
        _block = map_promise(_pipe, (result2) => {
          if (result2 instanceof Ok) {
            return;
          } else {
            let runtime_error = result2[0];
            let $3 = report_client_error(from_content_runtime_message_error(runtime_error), timestamp_seconds, timestamp_nanoseconds);
            return;
          }
        });
        let $2 = _block;
        return;
      } else {
        return;
      }
    } else {
      let submit_error = result[0];
      let $1 = report_client_error(from_submit_listener_error(submit_error), timestamp_seconds, timestamp_nanoseconds);
      return;
    }
  }
  function main() {
    return install_submit_listener(handle_submit);
  }

  // src/extension_entry.mjs
  main();
})();
