library LibrarySample;

uses
  System.SysUtils;

function AddIntegers(A, B: Integer): Integer; stdcall;
begin
  Result := A + B;
end;

function GetLibraryVersion: PChar; stdcall;
begin
  Result := '1.0.0-test';
end;

exports
  AddIntegers,
  GetLibraryVersion;

begin
end.
