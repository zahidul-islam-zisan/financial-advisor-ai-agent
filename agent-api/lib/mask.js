/**
 * PII Masking Utility
 * Redacts sensitive personal and financial identifiers before text is sent to LLMs.
 */

const EMAIL_REGEX = /[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+/g;

// 1. Phone numbers with '+' country code (e.g. +8801712345678, +1 555-0199) or local phone dashes (e.g. 01711-123456)
const PHONE_REGEX = /(?:\+\d{1,4}[-.\s]?(?:\(?\d{2,4}\)?[-.\s]?)?\d{3,4}[-.\s]?\d{3,6}\b)|(?:\b01\d{1}[-.\s]?\d{4}[-.\s]?\d{4}\b)|(?:\b(?:\(?\d{3}\)?[-.\s])\d{3}[-.\s]\d{4}\b)/g;

// 2. Credit card numbers (4x4 digits) and bank account numbers (13 to 19 raw digits)
const CARD_GROUP_REGEX = /\b(?:\d{4}[-\s]){3}\d{4}\b/g;
const ACCOUNT_REGEX = /\b\d{13,19}\b/g;

function maskPii(input) {
  if (typeof input !== "string") {
    return input;
  }

  let sanitized = input;

  // 1. Redact Emails
  sanitized = sanitized.replace(EMAIL_REGEX, "[EMAIL_REDACTED]");

  // 2. Redact Phone Numbers (international prefix or formatted phone)
  sanitized = sanitized.replace(PHONE_REGEX, "[PHONE_REDACTED]");

  // 3. Redact Credit Card Numbers (4x4 digits)
  sanitized = sanitized.replace(CARD_GROUP_REGEX, "[ACCOUNT_REDACTED]");

  // 4. Redact Long Account Numbers (13 to 19 digits)
  sanitized = sanitized.replace(ACCOUNT_REGEX, "[ACCOUNT_REDACTED]");

  return sanitized;
}

module.exports = {
  maskPii,
};
