/// Compares two byte lists without leaking timing information about where
/// they first differ. Length is checked as a non-secret pre-check: lengths of
/// authentication tags (e.g. a 32-byte HMAC) are public knowledge, so an
/// early-exit on length mismatch reveals nothing about either value's content.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }

  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }
  return result == 0;
}
