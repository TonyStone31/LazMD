program SourceTests;
{$mode objfpc}{$H+}
uses
  SysUtils,
  MDSource;

var
  Source, Text: string;
  Checks: integer;

  procedure Equal(const Name, Actual, Expected: string);
  begin
    Inc(Checks);
    if Actual <> Expected then raise Exception.Create(Name);
  end;

begin
  for Source in ['', 'hello', 'hello' + #13#10, #$EF#$BB#$BF + 'hello' + #13#10, 'a' + #10 + 'b' + #13#10 + 'c' + #13] do
  begin
    Text := MarkdownEditorText(Source);
    Equal('no-op source update', UpdateMarkdownSource(Source, Text), Source);
    Equal('append keeps original bytes', UpdateMarkdownSource(Source, Text + 'x'), Source + 'x');
  end;
  Source := #$EF#$BB#$BF + 'one' + #13#10 + 'two' + #10 + 'three';
  Equal('local replacement keeps mixed line endings',
    UpdateMarkdownSource(Source, 'one' + LineEnding + 'changed' + LineEnding + 'three'),
    #$EF#$BB#$BF + 'one' + #13#10 + 'changed' + #10 + 'three');
  Equal('new line follows file convention', UpdateMarkdownSource('a' + #13#10 + 'b', 'a' + LineEnding + 'b' + LineEnding + 'c'),
    'a' + #13#10 + 'b' + #13#10 + 'c');
  Source := 'caf' + #$C3#$A9 + #13#10 + 'other';
  Equal('UTF-8 replacement uses byte ranges', UpdateMarkdownSource(Source, 'cafes' + LineEnding + 'other'), 'cafes' + #13#10 + 'other');
  WriteLn(Checks, ' source checks passed.');
end.
