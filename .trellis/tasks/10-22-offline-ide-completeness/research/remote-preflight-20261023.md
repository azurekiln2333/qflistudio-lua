# Remote publication preflight — 2026-10-23

Read-only `git ls-remote --exit-code <remote> refs/heads/main` completed
successfully for github, gitee, gitcode, cnb and origin. All five currently
advertise `327b7c54d04bc184e03171f52da942c2157083b1`, matching local HEAD.
No remote divergence was observed. No fetch, commit or push was performed.

This proves current read access only; it does not establish future push
authorization, successful publication of the dirty source, or any test/device
gate. Ordinary push and fresh exact-OID verification remain required after
the intended source passes its serialized checks and staged review.
