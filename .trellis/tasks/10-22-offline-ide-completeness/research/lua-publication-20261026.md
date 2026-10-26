# Lua source publication — October 26, 2026

Foundation commit: `4ca62dd7746601c7e835c576413c03781e576867`.
Subject: `feat(lua): integrate offline tools, diagnostics and audit workflows`.
Tree: `1baab38c54b4cbc93bd2504164dc61395730742b`.
The commit contains the independently reviewed216-path candidate and preserves
unrelated icons, signing configuration, deviceTypes expansion and local metadata.
The actual index was empty before staging; its staged tree matched the candidate.

## Ordinary pushes and actual remote refs

All five remotes' `main` refs were read back at the exact foundation commit:

| Remote | Push result | Read-back |
| --- | --- | --- |
| cnb | ordinary push succeeded | exact foundation commit |
| gitcode | ordinary push succeeded | exact foundation commit |
| gitee | ordinary push succeeded | exact foundation commit |
| github | ordinary push succeeded | exact foundation commit |
| origin / GitLab | ordinary SSH retry succeeded | exact foundation commit |

GitLab's initial SSH attempt failed. A same-repository HTTPS retry timed out and
was not treated as success. The subsequent explicit noninteractive SSH retry
completed naturally: original tool `a4509d`, session45790, terminal poll481788,
exit0, remote update327b7c5..4ca62dd. Fresh read-back tool240e67 returned the full
foundation OID. No force push, remote rewriting or credential change occurred.
The other four exact remote refs were independently read in the finalRefs query.

## Verified publication boundary

All379 tested source snapshot files matched current bytes before staging.
Independent publication review confirmed README parity and local links,
exclusions, the index-only deviceTypes overlay and the exact receipt hash chain.
A discovered CRLF normalization issue was fixed with four exact-file Git
attributes. Original receipt bytes also survive a core.autocrlf=true checkout.
The published run receipt retains SHA256
`9d37831d385075df82c0ed820b8bd2e7fb22078b3835339e597cb73ded1a1572`,
matching its observer. No production source changed after the tested snapshot.
Both Chinese READMEs again passed the requested mechanical check with zero
findings. Conventional commit/publication closes this foundation batch only.

Host evidence and its limits remain in
[lua-host-gate-20261026.md](lua-host-gate-20261026.md):373passed/1skipped suite,
20defined full1282 assertions passed,800historical strict-byte LF differences,
OHOS native probe not_evaluated and failed355967ms complete handoff timing.
No new SDK, native build, HAP, device action or old-grant replay occurred during
publication. The R1-R14 umbrella stays in_progress. See
[lua-acceptance-next-20261026.md](lua-acceptance-next-20261026.md) for remaining
qualification and explicit device defer. Shared core and sibling work remain
with their owners.
