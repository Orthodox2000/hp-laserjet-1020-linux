# Contributing

Thanks for helping the next person avoid the "job completed but nothing printed" trap.

## Ways to help

- **Found a printer that behaves the same way?** Open an issue with your `usb_printerid`
  output (with/without `FWVER`) and whether `firmware/` fixed it.
- **A firmware download source is dead?** Say so — this repo bundles `sihp1020.dl`, but the
  upstream `getweb` mirror situation changes. See
  [OpenPrinting/foo2zjs#33](https://github.com/OpenPrinting/foo2zjs/issues/33).
- **Another distro tested?** Add a row/notes to `docs/10-other-distros.md`.
- **Another client OS tested?** Update the matrix in `docs/06-cross-platform.md`.
- **Typo / broken link?** Just send a PR.

## Guidelines

- Keep changes factual and reproducible: include the exact command and its output.
- Prefer documenting a verified workaround over guessing.
- Do **not** commit additional proprietary firmware beyond what is already here, and never
  commit HP's Windows driver package.
- Keep scripts POSIX-ish `bash`, runnable with `sudo bash scripts/<name>.sh`, and idempotent.
- Update the relevant doc and, if you change behaviour, `CHANGELOG.md`.

## Before you push

```bash
bash -n scripts/*.sh                # syntax
shellcheck -S warning scripts/*.sh  # lint (if shellcheck is installed)
markdownlint '**/*.md'              # docs (if markdownlint is installed)
md5sum firmware/sihp1020.dl         # must stay 0cd1ac3a4f6cb7995e99deffff840927
```

CI runs the same checks (see `.github/workflows/lint.yml`).

## License

By contributing you agree your changes are licensed under the project's [MIT license](LICENSE).
