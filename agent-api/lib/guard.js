/**
 * Prompt Injection Guard & Input Sanitizer
 * Wraps untrusted user content in <data> tags and neutralizes control characters.
 */

// Matches ASCII control characters except \t and \n
const CONTROL_CHARS_REGEX = /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g;

function sanitizeString(input, maxLength = 200) {
  if (typeof input !== "string") {
    return "";
  }

  // Strip control characters
  let clean = input.replace(CONTROL_CHARS_REGEX, "");

  // Prevent closing tag breakout inside data block
  clean = clean.replace(/<\/data>/gi, "[DATA_TAG]");

  // Truncate length
  if (clean.length > maxLength) {
    clean = clean.substring(0, maxLength);
  }

  return clean.trim();
}

/**
 * Wraps user-originated text in <data>...</data> tags to instruct the LLM
 * to treat it strictly as inert financial data, not instructions.
 */
function wrapUntrustedData(input, maxLength = 200) {
  const clean = sanitizeString(input, maxLength);
  return `<data>${clean}</data>`;
}

module.exports = {
  sanitizeString,
  wrapUntrustedData,
};
