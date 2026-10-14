# LazMD

### A small Markdown viewer and editor, for Linux, Windows and macOS.

Double-click a `.md` file and read it the way it was written to be read —
headings, tables, images, code — instead of a wall of asterisks in a text
editor. One document, one window, three ways to look at it:

- **View** — the rendered page. Links work: web links open in the browser,
  links to other Markdown files open in LazMD.
- **Edit** — type into the rendered page itself. Ctrl+B/I/U, and toolbar
  buttons for headings, lists, quotes, code and tables.
- **Raw** — the Markdown source, lightly colored.

![LazMD showing its own README on Linux](images/lazmd-linux.png)

The raw source is the document: the file on disk is only ever written from
it, so opening a file and just reading it never reformats a byte. Edits made
in the rendered view are folded back into the source when you switch away
or save.

Built with [LazInk](https://github.com/TonyStone31/LazInk), which draws the
formatted text, and [FileAss](https://github.com/TonyStone31/FileAss), which
registers the file association.

## Install

Download the file for your system from the
[latest release](https://github.com/TonyStone31/LazMD/releases/latest).
No installer, no dependencies to fetch.

- **Linux** — `lazmd-linux-x86_64.zip`. Unzip and run `./lazmd`. Built on
  GTK3, which every current desktop has.
- **Windows** — `lazmd-windows-x86_64.zip`. Unzip and run `lazmd.exe`.
- **macOS** — `lazmd-macos.zip`. Unzip, drag `LazMD.app` to Applications.
  The first time, right-click it and choose Open: it is not signed with
  Apple, so Gatekeeper wants to be told once.

## Use it for Markdown files

**File → Open Markdown files with LazMD** registers the application and,
on Linux, makes it the default handler for `text/markdown`. The same from
a terminal:

```sh
./lazmd --register
./lazmd --unregister
```

Command line: `lazmd FILE` opens a file; each launch is its own window.

## Build

Free Pascal and Lazarus, with the [LazInk](https://github.com/TonyStone31/LazInk)
and [FileAss](https://github.com/TonyStone31/FileAss) repositories checked
out beside this one:

```sh
./build.sh            # Linux, zipped into dist/
./build.sh windows    # Windows, cross-built from Linux
./build-macos.sh app  # on a Mac: LazMD.app and its zip
```

or open `lazmd.lpi` in Lazarus. The release builds were made with
Lazarus 4.8 / FPC 3.2.4 on the Mac and Lazarus trunk on Linux, where
Windows is cross-built; the source builds on either.

## Tested on

Linux Mint with GTK3, and Windows 10 in a virtual machine.

## License

[0BSD](LICENSE).
