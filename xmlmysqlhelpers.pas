unit XMLMySQLhelpers;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DB;

type
  enum_field_types = (MYSQL_TYPE_DECIMAL, MYSQL_TYPE_TINY,
    MYSQL_TYPE_SHORT, MYSQL_TYPE_LONG, MYSQL_TYPE_FLOAT,
    MYSQL_TYPE_DOUBLE, MYSQL_TYPE_NULL,
    MYSQL_TYPE_TIMESTAMP, MYSQL_TYPE_LONGLONG,
    MYSQL_TYPE_INT24, MYSQL_TYPE_DATE, MYSQL_TYPE_TIME,
    MYSQL_TYPE_DATETIME, MYSQL_TYPE_YEAR,
    MYSQL_TYPE_NEWDATE,
    MYSQL_TYPE_VARCHAR, MYSQL_TYPE_BIT, MYSQL_TYPE_NEWDECIMAL = 246,
    MYSQL_TYPE_ENUM := 247,
    MYSQL_TYPE_SET := 248, MYSQL_TYPE_TINY_BLOB := 249,
    MYSQL_TYPE_MEDIUM_BLOB := 250, MYSQL_TYPE_LONG_BLOB := 251,
    MYSQL_TYPE_BLOB := 252, MYSQL_TYPE_VAR_STRING := 253,
    MYSQL_TYPE_STRING := 254, MYSQL_TYPE_GEOMETRY := 255,
    MYSQL_TYPE_UNKNOWN
    );

const
  FIELD_TYPE_DECIMAL = MYSQL_TYPE_DECIMAL;
  FIELD_TYPE_NEWDECIMAL = MYSQL_TYPE_NEWDECIMAL;
  FIELD_TYPE_TINY = MYSQL_TYPE_TINY;
  FIELD_TYPE_SHORT = MYSQL_TYPE_SHORT;
  FIELD_TYPE_LONG = MYSQL_TYPE_LONG;
  FIELD_TYPE_FLOAT = MYSQL_TYPE_FLOAT;
  FIELD_TYPE_DOUBLE = MYSQL_TYPE_DOUBLE;
  FIELD_TYPE_NULL = MYSQL_TYPE_NULL;
  FIELD_TYPE_TIMESTAMP = MYSQL_TYPE_TIMESTAMP;
  FIELD_TYPE_LONGLONG = MYSQL_TYPE_LONGLONG;
  FIELD_TYPE_INT24 = MYSQL_TYPE_INT24;
  FIELD_TYPE_DATE = MYSQL_TYPE_DATE;
  FIELD_TYPE_TIME = MYSQL_TYPE_TIME;
  FIELD_TYPE_DATETIME = MYSQL_TYPE_DATETIME;
  FIELD_TYPE_YEAR = MYSQL_TYPE_YEAR;
  FIELD_TYPE_NEWDATE = MYSQL_TYPE_NEWDATE;
  FIELD_TYPE_ENUM = MYSQL_TYPE_ENUM;
  FIELD_TYPE_SET = MYSQL_TYPE_SET;
  FIELD_TYPE_TINY_BLOB = MYSQL_TYPE_TINY_BLOB;
  FIELD_TYPE_MEDIUM_BLOB = MYSQL_TYPE_MEDIUM_BLOB;
  FIELD_TYPE_LONG_BLOB = MYSQL_TYPE_LONG_BLOB;
  FIELD_TYPE_BLOB = MYSQL_TYPE_BLOB;
  FIELD_TYPE_VAR_STRING = MYSQL_TYPE_VAR_STRING;
  FIELD_TYPE_STRING = MYSQL_TYPE_STRING;
  FIELD_TYPE_CHAR = MYSQL_TYPE_TINY;
  FIELD_TYPE_INTERVAL = MYSQL_TYPE_ENUM;
  FIELD_TYPE_GEOMETRY = MYSQL_TYPE_GEOMETRY;
  FIELD_TYPE_BIT = MYSQL_TYPE_BIT;

type
  TMySQLTypeStringRec = record
    STP: string[20];
    TID: enum_field_types;
  end;

const
  MySQLTypeStrings: array[0..18] of TMySQLTypeStringRec = (
    (STP: 'decimal'; TID: FIELD_TYPE_DECIMAL),
    (STP: 'newdecimal'; TID: FIELD_TYPE_NEWDECIMAL),
    (STP: 'string'; TID: FIELD_TYPE_STRING),
    (STP: 'text'; TID: FIELD_TYPE_BLOB),
    (STP: 'varchar'; TID: FIELD_TYPE_STRING),
    (STP: 'datetime'; TID: FIELD_TYPE_DATETIME),
    (STP: 'time'; TID: FIELD_TYPE_TIME),
    (STP: 'date'; TID: FIELD_TYPE_DATE),
    (STP: 'blob'; TID: FIELD_TYPE_BLOB),
    (STP: 'longblob'; TID: FIELD_TYPE_LONG_BLOB),
    (STP: 'bigint'; TID: FIELD_TYPE_INT24),
    (STP: 'smallint'; TID: FIELD_TYPE_SHORT),
    (STP: 'char'; TID: FIELD_TYPE_STRING),
    (STP: 'float'; TID: FIELD_TYPE_FLOAT),
    (STP: 'real'; TID: FIELD_TYPE_FLOAT),
    (STP: 'int'; TID: FIELD_TYPE_INT24),
    (STP: 'mediumint'; TID: FIELD_TYPE_INT24),
    (STP: 'tinyint'; TID: FIELD_TYPE_TINY),
    (STP: 'timestamp'; TID: FIELD_TYPE_TIMESTAMP)
    );

function MYSQLTypeFromString(Value: string): enum_field_types;
function MySQLDataType(AType: enum_field_types; ASize, ADecimals: integer;
  out NewType: TFieldType; out NewSize: integer): boolean;
procedure SplitNums(Value: string; SplitChar: char; out a, b: integer);
function InternalStrToTime(S: string): TDateTime;
function InternalStrToDate(S: string): TDateTime;
function InternalStrToDateTime(S: string): TDateTime;
function InternalStrToTimeStamp(S: string): TDateTime;
function InternalSeparateLeft(const Value, Delimiter: string): string;
function InternalSeparateRight(const Value, Delimiter: string): string;

implementation

function MySQLDataType(AType: enum_field_types; ASize, ADecimals: integer;
  out NewType: TFieldType; out NewSize: integer): boolean;
begin
  Result := True;
  case AType of
    FIELD_TYPE_LONGLONG:
    begin
      NewType := ftLargeint;
      NewSize := 0;
    end;
    FIELD_TYPE_TINY, FIELD_TYPE_SHORT:
    begin
      NewType := ftSmallint;
      NewSize := 0;
    end;
    FIELD_TYPE_LONG, FIELD_TYPE_INT24:
    begin
      NewType := ftInteger;
      NewSize := 0;
    end;

    FIELD_TYPE_NEWDECIMAL,
    FIELD_TYPE_DECIMAL: if ADecimals < 5 then
      begin
        NewType := ftBCD;
        NewSize := ADecimals;
      end
      else
      begin
        NewType := ftFloat;
        NewSize := 0;
      end;
    FIELD_TYPE_FLOAT, FIELD_TYPE_DOUBLE:
    begin
      NewType := ftFloat;
      NewSize := 0;
    end;
    FIELD_TYPE_TIMESTAMP, FIELD_TYPE_DATETIME:
    begin
      NewType := ftDateTime;
      NewSize := 0;
    end;
    FIELD_TYPE_DATE:
    begin
      NewType := ftDate;
      NewSize := 0;
    end;
    FIELD_TYPE_TIME:
    begin
      NewType := ftTime;
      NewSize := 0;
    end;
    FIELD_TYPE_VAR_STRING, FIELD_TYPE_STRING, FIELD_TYPE_ENUM, FIELD_TYPE_SET:
    begin
      // Since mysql server version 5.0.3 string-fields with a length of more
      // then 256 characters are suported
      if ASize > dsMaxStringSize then
      begin
        NewType := ftMemo;
        NewSize := 0;
      end
      else
      begin
        NewType := ftString;
        NewSize := ASize;
      end;
    end;
    FIELD_TYPE_BLOB, FIELD_TYPE_LONG_BLOB:
    begin
      NewType := ftBlob;
      NewSize := 0;
    end
    else
      Result := False;
  end;
end;

procedure SplitNums(Value: string; SplitChar: char; out a, b: integer);
var
  p: integer;
begin
  b := 0;
  a := 0;
  p := Pos(SplitChar, Value);
  if p > 0 then
  begin
    a := StrToIntDef(Copy(Value, 1, p - 1), 0);
    b := StrToIntDef(Copy(Value, p + 1, Length(Value)), 0);
  end
  else
    a := StrToIntDef(Value, 0);
end;



function MYSQLTypeFromString(Value: string): enum_field_types;
var
  i: integer;
begin
  Value := LowerCase(Value);
  Result := MYSQL_TYPE_UNKNOWN;
  for i := 0 to High(MySQLTypeStrings) do
    if MySQLTypeStrings[i].STP = Value then Result := MySQLTypeStrings[i].TID;
end;

function DateTimeForSQL(const dateTime: TDateTime): string;
begin
  Result := FormatDateTime('#yyyy-mm-dd hh.nn.ss#', dateTime);
end;

function InternalStrToDate(S: string): TDateTime;

var
  EY, EM, ED: word;

begin
  Result := 0;
  if Trim(S) = '' then exit;
  EY := StrToInt(Copy(S, 1, 4));
  EM := StrToInt(Copy(S, 6, 2));
  ED := StrToInt(Copy(S, 9, 2));
  if (EY = 0) or (EM = 0) or (ED = 0) then
    Result := 0
  else
    Result := EncodeDate(EY, EM, ED);
end;

function InternalStrToDateTime(S: string): TDateTime;

var
  EY, EM, ED: word;
  EH, EN, ES: word;

begin
  Result := 0;
  if Trim(S) = '' then exit;
  EY := StrToInt(Copy(S, 1, 4));
  EM := StrToInt(Copy(S, 6, 2));
  ED := StrToInt(Copy(S, 9, 2));
  EH := StrToInt(Copy(S, 12, 2));
  EN := StrToInt(Copy(S, 15, 2));
  ES := StrToInt(Copy(S, 18, 2));
  if (EY = 0) or (EM = 0) or (ED = 0) then
    Result := 0
  else
    Result := EncodeDate(EY, EM, ED);
  Result := Result + EncodeTime(EH, EN, ES, 0);
end;

function InternalStrToTime(S: string): TDateTime;

var
  EH, EM, ES: word;

begin
  Result := 0;
  if Trim(S) = '' then exit;
  EH := StrToInt(Copy(S, 1, 2));
  EM := StrToInt(Copy(S, 4, 2));
  ES := StrToInt(Copy(S, 7, 2));
  Result := EncodeTime(EH, EM, ES, 0);
end;

function InternalStrToTimeStamp(S: string): TDateTime;

var
  EY, EM, ED: word;
  EH, EN, ES: word;

begin
  EY := StrToInt(Copy(S, 1, 4));
  EM := StrToInt(Copy(S, 6, 2));
  ED := StrToInt(Copy(S, 9, 2));
  EH := StrToInt(Copy(S, 12, 2));
  EN := StrToInt(Copy(S, 15, 2));
  ES := StrToInt(Copy(S, 18, 2));
  if (EY = 0) or (EM = 0) or (ED = 0) then
    Result := 0
  else
    Result := EncodeDate(EY, EM, ED);
  Result := Result + EncodeTime(EH, EN, ES, 0);
end;

function InternalSeparateLeft(const Value, Delimiter: string): string;
var
  x: Integer;
begin
  x := Pos(Delimiter, Value);
  if x < 1 then
    Result := Value
  else
    Result := Copy(Value, 1, x - 1);
end;

{==============================================================================}

function InternalSeparateRight(const Value, Delimiter: string): string;
var
  x: Integer;
begin
  x := Pos(Delimiter, Value);
  if x > 0 then
    x := x + Length(Delimiter) - 1;
  Result := Copy(Value, x + 1, Length(Value) - x);
end;


end.
