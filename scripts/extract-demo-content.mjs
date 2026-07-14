import vm from "node:vm";

export function extractConstExpression(source, name) {
  const match = new RegExp(`\\bconst\\s+${name}\\s*=`).exec(source);
  if (!match) throw new Error(`Missing const ${name}`);

  const start = match.index + match[0].length;
  const stack = [];
  let quote = null;
  let escaped = false;
  let lineComment = false;
  let blockComment = false;

  for (let index = start; index < source.length; index += 1) {
    const char = source[index];
    const next = source[index + 1];
    if (lineComment) {
      if (char === "\n") lineComment = false;
      continue;
    }
    if (blockComment) {
      if (char === "*" && next === "/") {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote) {
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === quote) quote = null;
      continue;
    }
    if (char === "/" && next === "/") {
      lineComment = true;
      index += 1;
      continue;
    }
    if (char === "/" && next === "*") {
      blockComment = true;
      index += 1;
      continue;
    }
    if (char === '"' || char === "'" || char === "`") {
      quote = char;
      continue;
    }
    if (char === "{" || char === "[" || char === "(") stack.push(char);
    else if (char === "}" || char === "]" || char === ")") stack.pop();
    else if (char === ";" && stack.length === 0) return source.slice(start, index).trim();
  }
  throw new Error(`Unterminated const ${name}`);
}

export function evaluateConst(source, name, context = {}) {
  return vm.runInNewContext(`(${extractConstExpression(source, name)})`, context);
}
