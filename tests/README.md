# LazMD editing checks

`run.sh` builds in a temporary directory and runs the source-byte checks,
LazInk's Markdown round-trip checks, and LazMD's form-level editing checks.
Set `FPC` to the Free Pascal compiler and `LAZARUS_DIR` to the Lazarus source
directory. The Linux harness uses GTK3; run it on an isolated X display.

```sh
DISPLAY=:9 GDK_BACKEND=x11 ./tests/run.sh
```

The form checks exercise the real resources, formatting actions, mode switching,
optional split layout, narrow toolbar layout, saved Markdown, undo after save,
and repeated external-change questions. They use temporary documents and do
not register file associations. An optional first argument saves a form image;
a second selects a Markdown document to display after the checks.

Set `MARKDOWN_SPEC` to a downloaded CommonMark `spec.json` to check every input
for an unchanged source round trip as well. Parser conformance is measured
separately by LazInk's `tests/check_markdown_spec.py`.

The design, manual fixture, remaining limitations and conformance baseline are
in [LazInk's round-trip document](../../LazInk/docs/MARKDOWN_ROUNDTRIP.md).
