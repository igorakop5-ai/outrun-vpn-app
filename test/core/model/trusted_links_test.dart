import 'package:flutter_test/flutter_test.dart';
import 'package:Outrun VPN/core/model/trusted_links.dart';

void main() {
  // Seed under test: Outrun VPN.com, github.com/Outrun VPN, t.me/Outrun VPN

  group("TrustedLinks.isTrusted - trusted (exact match, normalized)", () {
    test("exact telegram handle", () {
      expect(TrustedLinks.isTrusted("https://t.me/Outrun VPN"), isTrue);
    });

    test("trailing slash is ignored", () {
      expect(TrustedLinks.isTrusted("https://t.me/Outrun VPN/"), isTrue);
    });

    test("scheme is ignored (http)", () {
      expect(TrustedLinks.isTrusted("http://t.me/Outrun VPN"), isTrue);
    });

    test("no scheme", () {
      expect(TrustedLinks.isTrusted("t.me/Outrun VPN"), isTrue);
    });

    test("www prefix is stripped", () {
      expect(TrustedLinks.isTrusted("https://www.Outrun VPN.com"), isTrue);
    });

    test("host is case-insensitive", () {
      expect(TrustedLinks.isTrusted("https://Outrun VPN.COM"), isTrue);
    });

    test("fragment is ignored", () {
      expect(TrustedLinks.isTrusted("https://t.me/Outrun VPN#Outrun VPN"), isTrue);
    });

    test("domain root with and without trailing slash", () {
      expect(TrustedLinks.isTrusted("https://Outrun VPN.com"), isTrue);
      expect(TrustedLinks.isTrusted("https://Outrun VPN.com/"), isTrue);
    });

    test("github org", () {
      expect(TrustedLinks.isTrusted("https://github.com/Outrun VPN"), isTrue);
    });
  });

  group("TrustedLinks.isTrusted - untrusted (must warn)", () {
    test("look-alike handle (extra letter)", () {
      expect(TrustedLinks.isTrusted("https://t.me/Hiddiify"), isFalse);
    });

    test("missing letter", () {
      expect(TrustedLinks.isTrusted("https://t.me/hiddïfy"), isFalse);
    });

    test("sub-path is not covered by an exact handle entry", () {
      expect(TrustedLinks.isTrusted("https://t.me/Outrun VPN/123"), isFalse);
    });

    test("extra query means not exact", () {
      expect(TrustedLinks.isTrusted("https://t.me/Outrun VPN?x=1"), isFalse);
    });

    test("path is case-sensitive (exact match)", () {
      expect(TrustedLinks.isTrusted("https://t.me/Outrun VPN"), isFalse);
    });

    test("sub-path on a domain entry", () {
      expect(TrustedLinks.isTrusted("https://Outrun VPN.com/donate"), isFalse);
    });

    test("telegram.me alias is not the same host", () {
      expect(TrustedLinks.isTrusted("https://telegram.me/Outrun VPN"), isFalse);
    });

    test("look-alike domain", () {
      expect(TrustedLinks.isTrusted("https://evil-Outrun VPN.com"), isFalse);
    });

    test("suffix-attack domain", () {
      expect(TrustedLinks.isTrusted("https://Outrun VPN.com.evil.com"), isFalse);
    });

    test("different github org", () {
      expect(TrustedLinks.isTrusted("https://github.com/hiddiify"), isFalse);
    });

    test("empty and garbage input", () {
      expect(TrustedLinks.isTrusted(""), isFalse);
      expect(TrustedLinks.isTrusted("   "), isFalse);
      expect(TrustedLinks.isTrusted("not a url"), isFalse);
    });
  });
}
