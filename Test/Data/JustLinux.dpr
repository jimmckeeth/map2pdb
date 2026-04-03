program JustLinux;

{$APPTYPE CONSOLE}

uses
  System.SysUtils;

begin
  try
    Writeln('Hello, Linux from Delphi!');
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
