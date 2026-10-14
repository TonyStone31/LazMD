{ LazMD - a small Markdown viewer and editor built on LazInk.

  One document, three ways to look at it:

    View - the page as a browser would show it (TInkPage): images, tables,
           code highlighting, links that work.
    Edit - the rendered text, edited in place (TInkRichEdit): type into the
           page itself, Ctrl+B/I/U, the toolbar's paragraph buttons.
    Raw  - the Markdown source, lightly colored (TInkCodeMemo).

  The raw source is the document. View renders it; Edit projects it into
  the WYSIWYG editor and folds changes back when you leave or save. The
  file on disk is only ever written from the source text, so opening a
  file and just reading it never reformats a byte.

  lazmd FILE          opens FILE.
  lazmd --register    registers .md with the desktop and exits.
  lazmd --unregister  removes that registration and exits.

  SPDX-License-Identifier: 0BSD; see LICENSE.
}
unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, Buttons,
  ExtCtrls, StdCtrls, LCLIntf, LCLType, LazUTF8,
  InkPage, InkRichEdit, InkCodeMemo, InkLabel,
  FileAssMan, FATypes;

type
  TLazMDMode = (lmView, lmEdit, lmRaw);

  TTablePickEvent = procedure(ACols, ARows: integer) of object;

  { The table-size picker: a little grid under the Table button. Moving
    the mouse stretches the blue area - and the grid itself grows as the
    pointer nears its edge - and the click on the bottom-right cell is
    the size. Borderless, closes on Escape or on losing focus. }
  TfrmTablePick = class(TForm)
  private
    FCols, FRows: integer;    // the hovered size, 0 before the mouse arrives
    FGridC, FGridR: integer;  // how many cells are shown
    FOnPick: TTablePickEvent;
    procedure FitToGrid;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
    procedure KeyDown(var Key: word; Shift: TShiftState); override;
    procedure Deactivate; override;
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    constructor CreateNew(AOwner: TComponent; Num: integer = 0); override;
    procedure SetHover(ACols, ARows: integer);
    procedure PickNow;
    property OnPick: TTablePickEvent read FOnPick write FOnPick;
  end;

  { TfrmMain }

  TfrmMain = class(TForm)
    mnuMain: TMainMenu;
    mnuFile: TMenuItem;
    miNew, miOpen, miSave, miSaveAs, miSep1, miRegister, miUnregister, miSep2, miQuit: TMenuItem;
    mnuView: TMenuItem;
    miModeView, miModeEdit, miModeRaw: TMenuItem;

    pnlTools: TPanel;
    btnOpen, btnSave: TButton;
    sbView, sbEdit, sbRaw: TSpeedButton;
    btnKindH1, btnKindH2, btnKindBullet, btnKindNumber, btnKindQuote, btnKindCode, btnTable: TSpeedButton;
    lblFile: TInkLabel;

    pageView: TInkPage;
    reDoc: TInkRichEdit;
    memRaw: TInkCodeMemo;

    dlgOpen: TOpenDialog;
    dlgSave: TSaveDialog;
    FileAss: TFileAssMan;

    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of string);
    procedure FileNewClick(Sender: TObject);
    procedure FileOpenClick(Sender: TObject);
    procedure FileSaveClick(Sender: TObject);
    procedure FileSaveAsClick(Sender: TObject);
    procedure FileQuitClick(Sender: TObject);
    procedure RegisterClick(Sender: TObject);
    procedure UnregisterClick(Sender: TObject);
    procedure ModeClick(Sender: TObject);
    procedure PageLinkClick(Sender: TObject; const URL: string);
    procedure RawChanged(Sender: TObject);
    procedure DocChanged(Sender: TObject);
    procedure DocSelectionChange(Sender: TObject);
    procedure btnKindClick(Sender: TObject);
    procedure btnTableClick(Sender: TObject);
    procedure MdCharAttrs(Sender: TObject; AIndex: integer; const AChar: string; var AColor: TColor; var AStyle: TFontStyles);
  private
    FFile: string;
    FMode: TLazMDMode;
    FDirty: boolean;      // the document differs from the file on disk
    FSyncing: boolean;    // a change of our own making, not the user's
    FViewFresh: boolean;  // pageView shows the current source
    FEditFresh: boolean;  // reDoc holds the current source
    { the raw view's colors: whole lines classified once per change,
      the per-character event only reads the map }
    FMdColor: array of TColor;
    FMdStyle: array of TFontStyles;
    procedure SetMode(AMode: TLazMDMode);
    procedure TableSizePicked(ACols, ARows: integer);
    procedure PullFromEditor;
    procedure RenderView;
    procedure MdRecolor;
    procedure ShowTitle;
    procedure UpdateKindButtons;
    function BaseURI: string;
    function DisplayName: string;
    function ConfirmClose: boolean;
    function SaveFile: boolean;
    function SaveFileAs: boolean;
  public
    procedure LoadFile(const AFileName: string);
    { used by the --register / --unregister command line too }
    function RegisterWithSystem(AInstall: boolean): string;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

uses
  Math, LazFileUtils, URIParser, Process, InkDraw;

  { ------------------------------------------------------------------ startup }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FMode := lmView;
  FFile := '';
  ShowTitle;
  UpdateKindButtons;
  { an empty start still greets; the greeting is view-only and vanishes
    the moment anything real is loaded or typed }
  pageView.LoadMarkdown('# LazMD' + LineEnding + LineEnding + 'A Markdown file, shown the way it was written to be read.' + LineEnding +
    LineEnding + '- **Open** a file (Ctrl+O) or drop one on the window' + LineEnding + '- **View** is the rendered page; links work' +
    LineEnding + '- **Edit** types into the rendered page itself' + LineEnding + '- **Raw** is the source' + LineEnding, '');
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  CanClose := ConfirmClose;
end;

procedure TfrmMain.FormDropFiles(Sender: TObject; const FileNames: array of string);
begin
  if Length(FileNames) = 0 then Exit;
  if ConfirmClose then LoadFile(FileNames[0]);
end;

{ ----------------------------------------------------------------- document }

function TfrmMain.DisplayName: string;
begin
  if FFile = '' then Result := 'untitled'
  else
    Result := ExtractFileName(FFile);
end;

function TfrmMain.BaseURI: string;
begin
  { relative images and links are found beside the file }
  if FFile <> '' then Result := FilenameToURI(FFile)
  else
    Result := '';
end;

procedure TfrmMain.ShowTitle;
begin
  if FDirty then
  begin
    Caption := DisplayName + ' (changed) - LazMD';
    lblFile.Caption := '<b>' + HTMLEscape(DisplayName) + '</b> <font color="#C0392B">(changed)</font>';
  end
  else
  begin
    Caption := DisplayName + ' - LazMD';
    lblFile.Caption := '<b>' + HTMLEscape(DisplayName) + '</b>';
  end;
end;

procedure TfrmMain.LoadFile(const AFileName: string);
begin
  FSyncing := True;
  try
    try
      memRaw.Lines.LoadFromFile(AFileName);
    except
      on E: Exception do
      begin
        MessageDlg('LazMD', 'Could not open ' + AFileName + LineEnding + E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
  finally
    FSyncing := False;
  end;
  FFile := AFileName;
  FDirty := False;
  FViewFresh := False;
  FEditFresh := False;
  reDoc.Modified := False;
  MdRecolor;
  SetMode(lmView);
  pageView.ScrollTo(0);
  ShowTitle;
end;

function TfrmMain.SaveFile: boolean;
begin
  PullFromEditor;
  if FFile = '' then Exit(SaveFileAs);
  try
    memRaw.Lines.SaveToFile(FFile);
  except
    on E: Exception do
    begin
      MessageDlg('LazMD', 'Could not save ' + FFile + LineEnding + E.Message, mtError, [mbOK], 0);
      Exit(False);
    end;
  end;
  FDirty := False;
  ShowTitle;
  Result := True;
end;

function TfrmMain.SaveFileAs: boolean;
begin
  if FFile <> '' then dlgSave.FileName := FFile
  else
    dlgSave.FileName := 'untitled.md';
  if not dlgSave.Execute then Exit(False);
  FFile := dlgSave.FileName;
  Result := SaveFile;
end;

function TfrmMain.ConfirmClose: boolean;
begin
  PullFromEditor;
  if not FDirty then Exit(True);
  case MessageDlg('LazMD', 'Save changes to ' + DisplayName + '?', mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes: Result := SaveFile;
    mrNo: Result := True;
    else
      Result := False;
  end;
end;

{ -------------------------------------------------------------------- modes }

{ What leaving the WYSIWYG editor means: its edits become the source.
  Safe to call any time - it only acts when the editor is current and
  actually touched. }
procedure TfrmMain.PullFromEditor;
begin
  if (FMode <> lmEdit) or not reDoc.Modified then Exit;
  FSyncing := True;
  try
    memRaw.Text := reDoc.AsMarkdown;
  finally
    FSyncing := False;
  end;
  reDoc.Modified := False;
  MdRecolor;
  FDirty := True;
  FEditFresh := True;
  FViewFresh := False;
  ShowTitle;
end;

procedure TfrmMain.RenderView;
var
  Y: integer;
begin
  Y := pageView.ScrollY;
  pageView.LoadMarkdown(memRaw.Text, BaseURI);
  pageView.ScrollTo(Y);
  FViewFresh := True;
end;

procedure TfrmMain.SetMode(AMode: TLazMDMode);
begin
  PullFromEditor;
  FMode := AMode;
  case AMode of
    lmView:
      if not FViewFresh then RenderView;
    lmEdit:
      if not FEditFresh then
      begin
        FSyncing := True;
        try
          reDoc.LoadMarkdown(memRaw.Text);
        finally
          FSyncing := False;
        end;
        reDoc.Modified := False;
        FEditFresh := True;
      end;
    lmRaw: ;  // the source memo is always current
  end;
  pageView.Visible := AMode = lmView;
  reDoc.Visible := AMode = lmEdit;
  memRaw.Visible := AMode = lmRaw;
  sbView.Down := AMode = lmView;
  sbEdit.Down := AMode = lmEdit;
  sbRaw.Down := AMode = lmRaw;
  btnKindH1.Visible := AMode = lmEdit;
  btnKindH2.Visible := AMode = lmEdit;
  btnKindBullet.Visible := AMode = lmEdit;
  btnKindNumber.Visible := AMode = lmEdit;
  btnKindQuote.Visible := AMode = lmEdit;
  btnKindCode.Visible := AMode = lmEdit;
  btnTable.Visible := AMode = lmEdit;
  if Showing then
    case AMode of
      lmView: if pageView.CanFocus then pageView.SetFocus;
      lmEdit: if reDoc.CanFocus then reDoc.SetFocus;
      lmRaw: if memRaw.CanFocus then memRaw.SetFocus;
    end;
  UpdateKindButtons;
end;

{ one handler for the three speed buttons and the three menu items;
  the mode rides in the Tag }
procedure TfrmMain.ModeClick(Sender: TObject);
begin
  SetMode(TLazMDMode((Sender as TComponent).Tag));
end;

{ ------------------------------------------------------------------- events }

procedure TfrmMain.RawChanged(Sender: TObject);
begin
  if FSyncing then Exit;
  FDirty := True;
  FViewFresh := False;
  FEditFresh := False;
  MdRecolor;
  ShowTitle;
end;

procedure TfrmMain.DocChanged(Sender: TObject);
begin
  if FSyncing then Exit;
  FDirty := True;
  FViewFresh := False;
  ShowTitle;
  UpdateKindButtons;
end;

procedure TfrmMain.DocSelectionChange(Sender: TObject);
begin
  UpdateKindButtons;
end;

procedure TfrmMain.UpdateKindButtons;
begin
  btnKindH1.Down := reDoc.SelParaKind = ipkH1;
  btnKindH2.Down := reDoc.SelParaKind = ipkH2;
  btnKindBullet.Down := reDoc.SelParaKind = ipkBullet;
  btnKindNumber.Down := reDoc.SelParaKind = ipkNumber;
  btnKindQuote.Down := reDoc.SelParaKind = ipkQuote;
  btnKindCode.Down := reDoc.SelParaKind = ipkCode;
end;

procedure TfrmMain.btnKindClick(Sender: TObject);
begin
  if (Sender as TSpeedButton).Down then
    reDoc.ApplyParaKind(TInkParaKind((Sender as TSpeedButton).Tag))
  else
    reDoc.ApplyParaKind(ipkText);
  reDoc.SetFocus;
  UpdateKindButtons;
end;

procedure TfrmMain.btnTableClick(Sender: TObject);
var
  Pick: TfrmTablePick;
  P: TPoint;
begin
  Pick := TfrmTablePick.CreateNew(Self);
  Pick.OnPick := @TableSizePicked;
  P := btnTable.ClientToScreen(Point(0, btnTable.Height));
  Pick.Left := P.X;
  Pick.Top := P.Y;
  Pick.Show;
end;

procedure TfrmMain.TableSizePicked(ACols, ARows: integer);
begin
  reDoc.InsertTable(ACols, ARows);
  reDoc.SetFocus;
end;

procedure TfrmMain.PageLinkClick(Sender: TObject; const URL: string);
var
  Abs, FileName, Anchor, Ext: string;
  P: integer;
begin
  if Pos('#', URL) = 1 then
  begin
    pageView.JumpToAnchor(Copy(URL, 2, MaxInt));
    Exit;
  end;
  Abs := pageView.ResolveURL(URL);
  if (Pos('http://', Abs) = 1) or (Pos('https://', Abs) = 1) or (Pos('mailto:', Abs) = 1) then
  begin
    OpenURL(Abs);
    Exit;
  end;
  Anchor := '';
  P := Pos('#', Abs);
  if P > 0 then
  begin
    Anchor := Copy(Abs, P + 1, MaxInt);
    Delete(Abs, P, MaxInt);
  end;
  FileName := '';
  if Pos('file://', Abs) = 1 then URIToFilename(Abs, FileName)
  else if FilenameIsAbsolute(Abs) then FileName := Abs;
  Ext := LowerCase(ExtractFileExt(FileName));
  if (FileName <> '') and FileExists(FileName) and ((Ext = '.md') or (Ext = '.markdown')) then
  begin
    { a linked Markdown file becomes the document, like following a link }
    if not ConfirmClose then Exit;
    LoadFile(FileName);
    if Anchor <> '' then pageView.JumpToAnchor(Anchor);
  end
  else if FileName <> '' then
    OpenDocument(FileName)
  else
    OpenURL(Abs);
end;

{ --------------------------------------------------------------- file menu }

procedure TfrmMain.FileNewClick(Sender: TObject);
begin
  if not ConfirmClose then Exit;
  FSyncing := True;
  try
    memRaw.Text := '';
  finally
    FSyncing := False;
  end;
  FFile := '';
  FDirty := False;
  FViewFresh := False;
  FEditFresh := False;
  reDoc.Modified := False;
  MdRecolor;
  SetMode(lmEdit);
  ShowTitle;
end;

procedure TfrmMain.FileOpenClick(Sender: TObject);
begin
  if not ConfirmClose then Exit;
  if FFile <> '' then dlgOpen.InitialDir := ExtractFileDir(FFile);
  if dlgOpen.Execute then LoadFile(dlgOpen.FileName);
end;

procedure TfrmMain.FileSaveClick(Sender: TObject);
begin
  SaveFile;
end;

procedure TfrmMain.FileSaveAsClick(Sender: TObject);
begin
  PullFromEditor;
  SaveFileAs;
end;

procedure TfrmMain.FileQuitClick(Sender: TObject);
begin
  Close;
end;

{ -------------------------------------------------------- file association }

function TfrmMain.RegisterWithSystem(AInstall: boolean): string;
var
  R: TFileAssResult;
  {$IFDEF LINUX}
  CmdOut: string;
  {$ENDIF}
begin
  FileAss.ExecutablePath := ExpandFileName(ParamStr(0));
  if AInstall then R := FileAss.RegisterAll
  else
    R := FileAss.UnregisterAll;
  if not R.Succeeded then Exit(R.Message);
  if not AInstall then
    Exit('LazMD is no longer registered for Markdown files.');
  Result := 'Registered. Use your file manager''s Open With to make ' + 'LazMD the default.';
  {$IFDEF LINUX}
  { FileAss registers without stealing defaults; being made the default is
    exactly what this menu item asks for, so ask the desktop directly }
  if RunCommand('/usr/bin/xdg-mime', ['default',
    FileAss.ApplicationID + '.desktop', 'text/markdown'], CmdOut) then
    Result := 'Markdown files now open with LazMD.';
  {$ENDIF}
end;

procedure TfrmMain.RegisterClick(Sender: TObject);
begin
  ShowMessage(RegisterWithSystem(True));
end;

procedure TfrmMain.UnregisterClick(Sender: TObject);
begin
  ShowMessage(RegisterWithSystem(False));
end;

{ ---------------------------------------------------------- the raw colors }

{ The source colored as Markdown: headings blue, markers and fences orange,
  code teal, quotes gray - wrong here and there, like any small highlighter,
  and still a world better than plain. }
procedure TfrmMain.MdRecolor;
const
  cHead = $00DE862E;    // blue   (TColor is BGR)
  cMark = $001980E6;    // orange
  cCode = $00847016;    // teal
  cDim = $008D8C7F;    // gray
var
  i, j, CP, N, LineStart: integer;
  L: string;
  InFence, Table: boolean;

  procedure Put(AAt: integer; AColor: TColor; AStyle: TFontStyles);
  begin
    if (AAt >= 0) and (AAt < N) then
    begin
      FMdColor[AAt] := AColor;
      FMdStyle[AAt] := AStyle;
    end;
  end;

  procedure PutRun(AFrom, ATo: integer; AColor: TColor; AStyle: TFontStyles);
  var
    K: integer;
  begin
    for K := AFrom to ATo do
      Put(K, AColor, AStyle);
  end;

begin
  N := 0;
  for i := 0 to memRaw.Lines.Count - 1 do
    Inc(N, UTF8Length(memRaw.Lines[i]) + 1);
  SetLength(FMdColor, N);
  SetLength(FMdStyle, N);
  for i := 0 to N - 1 do
  begin
    FMdColor[i] := clDefault;
    FMdStyle[i] := [];
  end;
  InFence := False;
  LineStart := 0;
  for i := 0 to memRaw.Lines.Count - 1 do
  begin
    L := memRaw.Lines[i];
    if Copy(TrimLeft(L), 1, 3) = '```' then
    begin
      InFence := not InFence;
      PutRun(LineStart, LineStart + UTF8Length(L) - 1, cMark, []);
    end
    else if InFence then
      PutRun(LineStart, LineStart + UTF8Length(L) - 1, cCode, [])
    else if (L <> '') and (L[1] = '#') then
      PutRun(LineStart, LineStart + UTF8Length(L) - 1, cHead, [fsBold])
    else if Copy(TrimLeft(L), 1, 1) = '>' then
      PutRun(LineStart, LineStart + UTF8Length(L) - 1, cDim, [fsItalic])
    else
    begin
      j := 1;
      while (j <= Length(L)) and (L[j] = ' ') do Inc(j);
      { a list marker: -, *, + or 1. at the line's start }
      if (j <= Length(L)) and (L[j] in ['-', '*', '+']) and (j < Length(L)) and (L[j + 1] = ' ') then
        PutRun(LineStart + j - 1, LineStart + j - 1, cMark, [fsBold])
      else if (j <= Length(L)) and (L[j] in ['0'..'9']) then
      begin
        while (j <= Length(L)) and (L[j] in ['0'..'9']) do Inc(j);
        if (j <= Length(L)) and (L[j] = '.') then
          PutRun(LineStart, LineStart + j - 1, cMark, [fsBold]);
      end;
      { inline: markers dimmed, code spans teal, pipes orange.  The map is
        per codepoint, so the walk is too - an em-dash before a marker must
        not shift its color onto a neighbor }
      Table := (Pos('|', L) > 0);
      j := 1;
      CP := 0;
      while j <= Length(L) do
      begin
        case L[j] of
          '`':
          begin
            Put(LineStart + CP, cMark, []);
            Inc(j);
            Inc(CP);
            while (j <= Length(L)) and (L[j] <> '`') do
            begin
              Put(LineStart + CP, cCode, []);
              Inc(j, UTF8CodepointSize(@L[j]));
              Inc(CP);
            end;
            if j <= Length(L) then Put(LineStart + CP, cMark, []);
          end;
          '*', '_', '~':
            Put(LineStart + CP, cMark, []);
          '[', ']', '(', ')':
            if Pos('](', L) > 0 then Put(LineStart + CP, cMark, []);
          '|':
            if Table then Put(LineStart + CP, cMark, [fsBold]);
        end;
        if j <= Length(L) then
        begin
          Inc(j, UTF8CodepointSize(@L[j]));
          Inc(CP);
        end;
      end;
    end;
    Inc(LineStart, UTF8Length(L) + 1);
  end;
end;

procedure TfrmMain.MdCharAttrs(Sender: TObject; AIndex: integer; const AChar: string; var AColor: TColor; var AStyle: TFontStyles);
begin
  if (AIndex >= 1) and (AIndex <= Length(FMdColor)) then
  begin
    if FMdColor[AIndex - 1] <> clDefault then AColor := FMdColor[AIndex - 1];
    AStyle := AStyle + FMdStyle[AIndex - 1];
  end;
end;

{ ---------------------------------------------------- the table-size picker }

const
  PK_CELL = 22;   // one cell's pitch; the box inside is PK_CELL - 4
  PK_MARG = 8;
  PK_LABELH = 22;
  PK_MINC = 5;
  PK_MINR = 4;
  PK_MAXC = 12;
  PK_MAXR = 10;

constructor TfrmTablePick.CreateNew(AOwner: TComponent; Num: integer);
begin
  inherited CreateNew(AOwner, Num);
  BorderStyle := bsNone;
  ShowInTaskBar := stNever;
  PopupMode := pmAuto;
  Color := clWindow;
  FCols := 0;
  FRows := 0;
  FGridC := PK_MINC;
  FGridR := PK_MINR;
  FitToGrid;
end;

procedure TfrmTablePick.FitToGrid;
begin
  SetBounds(Left, Top, PK_MARG * 2 + FGridC * PK_CELL,
    PK_MARG * 2 + FGridR * PK_CELL + PK_LABELH);
end;

procedure TfrmTablePick.Paint;
var
  C, R, X, Y: integer;
  Hot: boolean;
  S: string;
begin
  Canvas.Brush.Color := clWindow;
  Canvas.FillRect(ClientRect);
  for R := 0 to FGridR - 1 do
    for C := 0 to FGridC - 1 do
    begin
      X := PK_MARG + C * PK_CELL;
      Y := PK_MARG + R * PK_CELL;
      Hot := (C < FCols) and (R < FRows);
      if Hot then
      begin
        Canvas.Brush.Color := $00FEEADB;  // a light blue wash (BGR)
        Canvas.Pen.Color := $00F48542;    // and its stronger edge
      end
      else
      begin
        Canvas.Brush.Color := clWhite;
        Canvas.Pen.Color := $00C8C8C8;
      end;
      Canvas.Rectangle(X, Y, X + PK_CELL - 4, Y + PK_CELL - 4);
    end;
  if FCols > 0 then
    S := Format('%d ' + #$C3#$97 + ' %d', [FCols, FRows])
  else
    S := 'Table size';
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := clWindowText;
  Canvas.TextOut(PK_MARG, PK_MARG + FGridR * PK_CELL + 2, S);
  Canvas.Brush.Style := bsSolid;
  { the popup's own outline, since there is no window border }
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := $00A0A0A0;
  Canvas.Rectangle(0, 0, ClientWidth, ClientHeight);
  Canvas.Brush.Style := bsSolid;
end;

procedure TfrmTablePick.SetHover(ACols, ARows: integer);
begin
  FCols := Max(1, Min(PK_MAXC, ACols));
  FRows := Max(1, Min(PK_MAXR, ARows));
  { the grid keeps one spare row and column in reach, so dragging toward
    the corner keeps growing it }
  FGridC := Max(PK_MINC, Min(PK_MAXC, FCols + 1));
  FGridR := Max(PK_MINR, Min(PK_MAXR, FRows + 1));
  FitToGrid;
  Invalidate;
end;

procedure TfrmTablePick.MouseMove(Shift: TShiftState; X, Y: integer);
begin
  inherited MouseMove(Shift, X, Y);
  SetHover((X - PK_MARG) div PK_CELL + 1, (Y - PK_MARG) div PK_CELL + 1);
end;

procedure TfrmTablePick.PickNow;
begin
  if (FCols > 0) and Assigned(FOnPick) then FOnPick(FCols, FRows);
  Close;
end;

procedure TfrmTablePick.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button = mbLeft then PickNow;
end;

procedure TfrmTablePick.KeyDown(var Key: word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    Close;
  end
  else
    inherited KeyDown(Key, Shift);
end;

procedure TfrmTablePick.Deactivate;
begin
  inherited Deactivate;
  Close;
end;

procedure TfrmTablePick.DoClose(var CloseAction: TCloseAction);
begin
  inherited DoClose(CloseAction);
  CloseAction := caFree;
end;

initialization
  RegisterClass(TFileAssMan);

end.
