program MinimalConsole;

{$APPTYPE CONSOLE}

uses
  System.SysUtils;

begin
  try
    Writeln('map2pdb Integration Test: MinimalConsole');
    Writeln('Platform: ' + {$IFDEF WIN32}'Win32'{$ENDIF}{$IFDEF WIN64}'Win64'{$ENDIF}{$IFDEF LINUX64}'Linux64'{$ENDIF});
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
