# php74-el7-patched

Unofficial **PHP 7.4.33 RPMs for CentOS 7 / EL7 (x86_64) with the upstream PHP2Shell mitigation**
(CVE-2026-109618, CVE-2026-109619), rebuilt from Remi Collet's `php-7.4.33-31` source RPM.

> **Read this first**
> - This is a *stopgap*, not a fix you can live on. CentOS 7 and PHP 7.4 are both end-of-life. The real answer is to move to a supported OS and a supported PHP (8.2+ is the fixed line upstream).
> - It is **not** affiliated with, endorsed by or supported by the PHP project or Remi Collet.
> - The patch is upstream's own **"minimal mitigation for EOL version"**. PHP's advisory says mitigations *reduce exposure* and that updating to a fixed release is the only complete fix.
> - Provided **as is, no warranty**. Test before you put it on a production box, and keep a rollback.

## Why this exists

- PHP's advisory of 21 Oct 2026 ([php.net/archive/2026.php#2026-10-21-5](https://www.php.net/archive/2026.php#2026-10-21-5), [GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w), [GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)) fixes two critical flaws in PHP core in 8.5.12, 8.4.27, 8.3.36 and 8.2.35.
- PHP 7.4 and older get **no official release**. The PHP security team published *minimal source backports* instead (for 7.4: [`712e60f`](https://github.com/php/php-src/commit/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2)).
- Remi's `php-7.4.33-31` SRPM contains that backport (as Patch 243, on top of Patch 242, a cumulative backport from 8.2.34), but his **EL7 repositories were closed on 2026-08-12** ([his configuration page](https://blog.remirepo.net/pages/Config-en)), and the last EL7 binary build is `7.4.33-15`, which does not have the fix.
- This repo rebuilds that SRPM on CentOS 7 so people stuck on EL7 and PHP 7 can get the same mitigation while they migrate.

## What you get (GitHub Releases)

`php-7.4.33-31.el7.x86_64` and 34 sibling subpackages (`php-cli`, `php-fpm`, `php-common`, `php-gd`, `php-mbstring`, `php-mysqlnd`, `php-pdo`, `php-xml`, `php-opcache`, `php-intl`, `php-json`, `php-sodium`, ... the full list is in `SHA256SUMS`), plus the **source RPM** `php-7.4.33-31.el7.src.rpm`, `SHA256SUMS` and its detached signature `SHA256SUMS.asc`.

## What differs from Remi's SRPM

Only two small changes, both so it builds on EL7. See [`patches/`](patches/).

1. **`0001`: spec.** `BuildRequires: pkgconfig(icu-*) >= 74` relaxed to `>= 73`. The newest ICU available for EL7 is 73.2 (Remi's `libicu73-devel`); 74 does not exist for EL7.
2. **`0002`: `php-7.4.33-icu.patch`.** Upstream's `ext/intl/config.m4` test `test "$PKG_CONFIG icu-uc --atleast-version=74"` is quoted, so it is always true and *every* ICU demands C++17, which EL7's GCC 4.8.5 cannot provide. Removing the quotes makes ICU 73 use the intended C++11 branch.

Everything else, including Patches 242 and 243, is untouched. I compared Patch 243 with the upstream 7.4 commit: same 17 files, and the added lines match except 10 lines about `max_multipart_body_parts`, which Patch 242 already provides (it is present in the built tree and in `php -i`).

## Known side effects (from the upstream mitigation)

- **Session upload progress is disabled completely**, regardless of `php.ini` (`session.upload_progress.*` stops working).
- **Out-of-memory fatals** are printed to stderr and the process exits via `_exit(1)`; they no longer go through the normal error handler/log path.
- The PHP test suite runs during the build: 15,901 tests, **9,158 passed, 9 failed**, 6,700 skipped, 33 expected-fail. The 9 failures are 8 × `ext/session/tests/rfc1867*.phpt` (upload progress, see above) and `tests/lang/bug45392.phpt` (OOM message), both caused by the mitigation. See `build/` if you want to run it yourself.

## What was tested, and what was not

- Built on CentOS 7.9 in Docker; installed into a clean `centos:7` container; `php -v`, `php -m`, a PHP-FPM request, `intl`, `gd` and `mbstring` checked.
- **Not tested:** exploitability. I did not run a proof-of-concept; I rely on upstream's patch. No third-party security audit. No testing beyond the setup above, so test with your own application.

## Verify what you download

```sh
gpg --import PUBLIC-KEY.asc
gpg --fingerprint CA0986107910D598A3EF28DBEFCFD009B4137B36   # must match exactly
gpg --verify SHA256SUMS.asc SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing
```

Signing key: `VPS Gems RPM signing`, RSA-4096, fingerprint `CA09 8610 7910 D598 A3EF  28DB EFCF D009 B413 7B36`. The fingerprint is also published at <https://vpsgems.com/> (check it there too, not only here). **The individual RPMs are not signed**; trust comes from the signed `SHA256SUMS`, or better, from rebuilding (below).

## Rebuild it yourself (recommended)

```sh
./build/build.sh
```

Needs Docker (linux/amd64), about 15 GB free disk and 30-60 minutes. It downloads Remi's SRPM, checks its SHA-256 (`89aed65a…f8ee`), verifies its GPG signature against Remi's 2026 key with the fingerprint pinned in the script (`2E37 5FE2 4EDF F0F2 E0D8  E165 ED5B 58C5 BEFA 00E2`, [published by Remi](https://blog.remirepo.net/pages/Config-en)), applies the two patches, and builds in a clean `centos:7` container. Results go to `out-rebuild/`. I rebuilt the release from scratch with this script and compared: the same 36 files (35 binary RPMs plus the SRPM), identical file lists in 34 of the 35 binary packages (`php-debuginfo` differs only in per-build `/usr/lib/debug/.build-id/` paths), identical dependency (`Requires`) lists in all 35, and identical test-suite totals (9,158 passed, 9 failed, 6,700 skipped, 33 expected-fail). The binaries are not bit-for-bit identical, because build timestamps are embedded (a few bytes' difference in `php-cli`, `php-fpm` and `php-mbstring`).

Note: the build (and installing the RPMs) pulls dependencies from Remi's and EPEL's EL7 repositories, which are closed/archived. They are reachable today; they may not be forever.

## Installing on an existing Remi PHP 7.3/7.4 box (outline)

Take a full backup and have a rollback first. Details and a worked example are in the write-up on vpsgems.com.

1. Download the RPMs, verify them (above), and put them in a directory, e.g. `/root/php74-patched/`.
2. `php-common` and `php` require **`php-sodium`** (same version), and `php-sodium` needs `libsodium` (EPEL). Copy `php-sodium` too. Extensions from Remi must be **PHP 7.4 builds** (ABI 20190902); 7.3 builds will not load. `gd` needs `gd3php`, `mbstring` needs `oniguruma5php`, `intl` needs `libicu73`, all from Remi's `[remi]` repo.
3. **Stop PHP-FPM first**: the `php-fpm` RPM restarts the service on upgrade. Then
   `yum --disablerepo=<broken repos> localinstall /root/php74-patched/*.rpm`, fix `php.ini` (below), and start PHP-FPM. Run `php -v`, `php -m` and `php-fpm -t` before starting.
4. **ionCube / other zend_extensions:** you need a loader built for 7.4. This repo does not ship it; get it from ionCube. It **must be the first `zend_extension`** in `php.ini`, before OPcache.
5. Disable `remi-php73`/`remi-php74` afterwards so a routine `yum update` cannot swap PHP back.

## Licence and credits

- PHP is under the [PHP License 3.01](https://www.php.net/license/3_01.txt). These are unofficial rebuilds; the packages keep the `php-*` names that Remi's packaging uses.
- All real packaging work is Remi Collet's. The upstream fix is by the PHP security team (Arnaud Le Blanc, Ilija Tovilo and others).
- The scripts, documentation and patches in this repository are under the [MIT licence](LICENSE), which also disclaims all warranty and liability. This matches Remi's spec file, which is itself `License: MIT` ("adapted from" the Fedora spec for php), so the two small patches to it stay under MIT.
- The *compiled packages* are PHP, and carry the licences declared in the spec's `License:` tags (`PHP and Zend and BSD and MIT and ASL 1.0 and NCSA` for the main package). The MIT licence of this repository does not replace those.

## Issues

Please open a GitHub issue. Include `php -v`, your OS and what you installed from where.
