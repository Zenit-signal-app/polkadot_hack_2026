const RESET  = "\x1b[0m";
const DIM    = "\x1b[2m";
const GREEN  = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED    = "\x1b[31m";
const CYAN   = "\x1b[36m";
const MAGENTA = "\x1b[35m";

function ts(): string {
  return new Date().toISOString();
}

function fmt(level: string, color: string, tag: string, msg: string, meta?: Record<string, unknown>): string {
  const metaStr = meta ? ` ${DIM}${JSON.stringify(meta)}${RESET}` : "";
  return `${DIM}${ts()}${RESET} ${color}${level}${RESET} [${CYAN}${tag}${RESET}] ${msg}${metaStr}`;
}

export const log = {
  info(tag: string, msg: string, meta?: Record<string, unknown>) {
    console.log(fmt("INFO ", GREEN, tag, msg, meta));
  },
  warn(tag: string, msg: string, meta?: Record<string, unknown>) {
    console.warn(fmt("WARN ", YELLOW, tag, msg, meta));
  },
  error(tag: string, msg: string, meta?: Record<string, unknown>) {
    console.error(fmt("ERROR", RED, tag, msg, meta));
  },
  action(tag: string, msg: string, meta?: Record<string, unknown>) {
    console.log(fmt("EXEC ", MAGENTA, tag, msg, meta));
  },
};
