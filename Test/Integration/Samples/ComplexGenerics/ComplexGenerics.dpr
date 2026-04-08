program ComplexGenerics;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TDeepGeneric<T> = class
  type
    TInner<U> = class
      FData: TDictionary<string, TList<TArray<U>>>;
      procedure Process(const Key: string; const Value: U);
    end;
  end;

{ TDeepGeneric<T>.TInner<U> }

procedure TDeepGeneric<T>.TInner<U>.Process(const Key: string; const Value: U);
begin
  if not FData.ContainsKey(Key) then
    FData.Add(Key, TList<TArray<U>>.Create);
  var Arr: TArray<U>;
  SetLength(Arr, 1);
  Arr[0] := Value;
  FData[Key].Add(Arr);
end;

var
  Tester: TDeepGeneric<Integer>.TInner<Double>;
begin
  try
    Writeln('Testing deeply nested generics symbols...');
    Tester := TDeepGeneric<Integer>.TInner<Double>.Create;
    Tester.FData := TDictionary<string, TList<TArray<Double>>>.Create;
    Tester.Process('Test', 1.234);
    Writeln('Success.');
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
