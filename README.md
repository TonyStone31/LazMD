# LazMD

### A small Markdown viewer and editor.

Double-click a `.md` file and read it the way it was written to be read —
headings, tables, images, code — instead of a wall of asterisks in a text
editor. One document, one window, three ways to look at it:

- **View** — the rendered page. Links work: web links open in the browser,
  links to other Markdown files open in LazMD.
- **Edit** — type into the rendered page itself. Ctrl+B/I/U, and toolbar
  buttons for headings, lists, quotes, code and tables.
- **Raw** — the Markdown source, lightly colored.

The raw source is the document: the file on disk is only ever written from
it, so opening a file and just reading it never reformats a byte. Edits made
in the rendered view are folded back into the source when you switch away
or save.

Built with [LazInk](../LazInk), which draws the formatted text, and
[FileAss](../FileAss), which registers the file association.

## Build

Needs the LazInk and FileAss repositories checked out beside this one.

```sh
lazbuild lazmd.lpi
```

## Use it for Markdown files

**File → Open Markdown files with LazMD** registers the application and,
on Linux, makes it the default handler for `text/markdown`. The same from
a terminal:

```sh
./lazmd --register
./lazmd --unregister
```

Command line: `lazmd FILE` opens a file; each launch is its own window.

## License

[0BSD](LICENSE).
