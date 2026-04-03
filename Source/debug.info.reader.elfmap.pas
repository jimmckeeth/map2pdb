unit debug.info.reader.elfmap;

(*
 * Copyright (c) 2021 Anders Melander
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *)

interface

{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

uses
  System.Classes,
  debug.info,
  debug.info.reader,
  debug.info.reader.map,
  debug.info.log;

type
  // -----------------------------------------------------------------------------
  //
  //      TDebugInfoElfMapReader
  //
  // -----------------------------------------------------------------------------
  // Reader for GNU/ELF map files (as produced by dcclinux64)
  // -----------------------------------------------------------------------------
  TDebugInfoElfMapReader = class(TDebugInfoMapReader)
  protected
    function HexToOffset(const s: string; var Offset: integer): TDebugInfoOffset;
  public
    procedure LoadFromStream(Stream: TStream; DebugInfo: TDebugInfo); override;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Math,
  Winapi.Windows;

// -----------------------------------------------------------------------------

function TDebugInfoElfMapReader.HexToOffset(const s: string; var Offset: integer): TDebugInfoOffset;
begin
  Result := 0;
  // Skip leading spaces
  while (Offset <= Length(s)) and (s[Offset] = ' ') do
    Inc(Offset);

  // Skip "0x" prefix
  if (Offset < Length(s)) and (s[Offset] = '0') and (s[Offset+1] = 'x') then
    Inc(Offset, 2);

  var FirstOffset := Offset;
  while (Offset <= Length(s)) do
  begin
    var Nibble := HexToNibble(s[Offset]);
    if (Nibble = $FF) then
      break;

    Result := (Result SHL 4) or Nibble;
    Inc(Offset);
  end;

  if (Offset = FirstOffset) then
    Result := 0;
end;

{ TDebugInfoElfMapReader }

procedure TDebugInfoElfMapReader.LoadFromStream(Stream: TStream; DebugInfo: TDebugInfo);
begin
  Logger.Info('Reading ELF MAP file');

  var Reader := TLineReader.Create(Stream);
  try
    FLineLogger := TDebugInfoLineModuleLogger.Create(Logger, Reader);
    try

      (*
      ** Find "Memory map" section
      *)
      while (Reader.HasData) and (Reader.CurrentLine(True, True).ToLower <> 'memory map') do
        Reader.NextLine(True, True);

      if (not Reader.HasData) then
      begin
        LineLogger.Warning('Memory map not found');
        Exit;
      end;

      Reader.NextLine(True, True); // Skip "Memory map" header

      while (Reader.HasData) do
      begin
        var Line := Reader.CurrentLine(False, False); 
        
        if (Line.Trim = '') or (Line.Trim = 'Discarded input sections') then
        begin
           Reader.NextLine(False, False);
           continue;
        end;

        var SpaceCount := 0;
        while (SpaceCount < Line.Length) and (Line[SpaceCount+1] = ' ') do
          Inc(SpaceCount);

        if (SpaceCount = 0) then
        begin
          // Segment line: ".text           0x00000000004135e0    0x4702b"
          var n := 1;
          var SectionName := GetSectionName(Line.Trim, n);
          n := Pos('0x', Line);
          if (n > 0) then
          begin
            var Address := HexToOffset(Line, n);
            var Size := HexToOffset(Line, n);
            
            if (Size > 0) and (Address <> 0) then
            begin
              var SegmentClass := TDebugInfoSegment.GuessClassType(SectionName.Substring(1).ToUpper);
              var Segment := DebugInfo.Segments.Add(DebugInfo.Segments.Count + 1, SectionName, SegmentClass);
              Segment.Offset := Address;
              Segment.Size := Size;
              
              if (DebugInfo.Architecture = IMAGE_FILE_MACHINE_UNKNOWN) then
                DebugInfo.Architecture := IMAGE_FILE_MACHINE_AMD64;
            end;
          end;
        end else
        if (SpaceCount = 1) then
        begin
          // Input section: " .text._ZN7Sysinit8__mallocEy"
          if (Line.TrimLeft.StartsWith('.')) then
          begin
            // Peak at next line for address and path
            var NextLine := Reader.PeekLine(False, False);
            var n := 1;
            while (n <= NextLine.Length) and (NextLine[n] = ' ') do Inc(n);
            
            if (n > 10) and (NextLine.Substring(n-1).StartsWith('0x')) then
            begin
              Reader.NextLine(False, False); // Consume the peeked line
              var Address := HexToOffset(NextLine, n);
              var Size := HexToOffset(NextLine, n);
              var ModulePath := NextLine.Substring(n-1).Trim;
              
              if (not ModulePath.IsEmpty) and (Address <> 0) then
              begin
                var ModuleName := TPath.GetFileNameWithoutExtension(ModulePath);
                var Segment := DebugInfo.Segments.FindByOffset(Address);
                if (Segment <> nil) then
                begin
                  var Module := DebugInfo.Modules.FindOverlap(Segment, Address - Segment.Offset, Size);
                  if (Module = nil) then
                    DebugInfo.Modules.Add(ModuleName, Segment, Address - Segment.Offset, Size);
                end;
              end;
            end;
          end;
        end else
        if (SpaceCount >= 16) then
        begin
          // Symbol line or Address line
          var TrimmedLine := Line.Trim;
          if (TrimmedLine.StartsWith('0x')) then
          begin
            var n := 1;
            var Address := HexToOffset(TrimmedLine, n);
            var SymbolName := TrimmedLine.Substring(n+10).Trim; // Heuristic padding skip
            
            if (not SymbolName.IsEmpty) and (Address <> 0) and (not SymbolName.StartsWith('0x')) then
            begin
              var Segment := DebugInfo.Segments.FindByOffset(Address);
              if (Segment <> nil) then
              begin
                var Module := DebugInfo.Modules.FindByOffset(Segment, Address - Segment.Offset);
                if (Module <> nil) then
                begin
                  var RelativeOffset := Address - Segment.Offset - Module.Offset;
                  Module.Symbols.Add(SymbolName, RelativeOffset);
                end;
              end;
            end;
          end;
        end;

        Reader.NextLine(False, False);
      end;

      for var Module in DebugInfo.Modules do
        Module.Symbols.CalculateSizes;

    finally
      FLineLogger := nil;
    end;
  finally
    Reader.Free;
  end;
end;

end.
