unit XMLMySQLDataSet;

{$MODE objfpc}{$H+}
{_$codepage UTF8}

interface

uses
  Classes, SysUtils, Controls, BufDataset, DB, fphttpclient, opensslsockets;

type

  { TXMLMySQLDataSet }

  TXMLMySQLDataSet = class(TCustomBufDataset)
  private
    FKey: string;
    FSQL: string;
    fUpdateLock: integer;
    FURL: string;
    fLocal: boolean;
    fStrm: TMemoryStream;
    function GetResponse: string;
    function HttpPostURL(URLData: string; const Data: TStream): boolean;
    procedure SetURL(const AValue: string);
  protected
    procedure ApplyRecUpdate(UpdateKind: TUpdateKind); override;
    procedure LoadBlobIntoBuffer(FieldDef: TFieldDef; ABlobBuf: PBufBlobField); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure ExecSQL;
    property UpdateLock: integer read fUpdateLock write fUpdateLock;
    property XML: string read GetResponse;
  published
    property FieldDefs;
    property URL: string read FURL write SetURL;
    property SQL: string read FSQL write FSQL;
    property Key: string read FKey write FKey;
  end;

implementation

uses Variants, Dialogs, XMLMySQLDatapacketReader, XMLMySQLhelpers;

{ TXMLMySQLDataSet }

constructor TXMLMySQLDataSet.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fUpdateLock := 0;
  fStrm := TMemoryStream.Create;
  fKey := 'lazsql_392';
end;

destructor TXMLMySQLDataSet.Destroy;
begin
  fStrm.Free;
  inherited Destroy;
end;

procedure TXMLMySQLDataSet.ApplyRecUpdate(UpdateKind: TUpdateKind);
var
  i: integer;
  KeyFieldPos: integer;
  KeyFieldName: string;
begin
  if fUpdateLock = 0 then
  begin
    if UpdateStatus <> usUnmodified then
    begin
      case UpdateKind of
        ukModify:
        begin
          KeyFieldPos := IndexDefs.IndexOf('PRI');
          if KeyFieldPos < 0 then raise Exception.Create('Primary Key not found!')
          else
            KeyFieldName := IndexDefs.Items[KeyFieldPos].Fields;
          fSQL := 'UPDATE ' + InternalSeparateLeft(Fields[0].FieldName, '.') + ' SET ';
          for i := 1 to FieldCount - 1 do
          begin
            if Fields[i].OldValue <> Fields[i].NewValue then
              case Fields[i].DataType of
                ftString, ftBlob: SQL :=
                    SQL + InternalSeparateRight(Fields[i].FieldName, '.') +
                    '=' + QuotedStr(Fields[i].AsString) + ', ';
                ftInteger, ftSmallint, ftBCD, ftFloat: SQL :=
                    SQL + InternalSeparateRight(Fields[i].FieldName, '.') +
                    '=' + Fields[i].AsString + ', ';
                ftDateTime, ftDate, ftTime: begin
                  SQL := SQL + InternalSeparateRight(Fields[i].FieldName, '.') +
                    '=' + QuotedStr(FormatDateTime('yyyy-mm-dd hh.nn.ss',
                    Fields[i].AsDateTime)) + ', ';
                end;
              end;
          end;
          SQL := Copy(SQL, 1, Length(SQL) - 2);
          SQL := SQL + ' WHERE ' + InternalSeparateRight(KeyFieldName, '.') +
            '=' + FieldByName(KeyFieldName).AsString;
          ExecSQL;
        end;
        ukInsert:
        begin
          SQL := 'INSERT INTO ' + InternalSeparateLeft(Fields[0].FieldName, '.') + ' (';
          for i := 1 to FieldCount - 1 do
          begin
            SQL := SQL + InternalSeparateRight(Fields[i].FieldName, '.');
            if (i < FieldCount - 1) then SQL := SQL + ',';
          end;
          SQL := SQL + ') VALUES (';
          for i := 1 to FieldCount - 1 do
          begin
            case Fields[i].DataType of
              ftString, ftBlob: SQL := SQL + QuotedStr(Fields[i].AsString);
              ftInteger, ftSmallint, ftBCD, ftFloat: SQL := SQL + Fields[i].AsString;
              ftDateTime, ftDate, ftTime:
                SQL := SQL + QuotedStr(FormatDateTime('yyyy-mm-dd hh.nn.ss',
                  Fields[i].AsDateTime));
            end;
            if (i < FieldCount - 1) then SQL := SQL + ',';
          end;
          SQL := SQL + ')';
         // writeln(SQL);
         // ShowMessage(SQL);
          ExecSQL;
        end;
        ukDelete:
        begin
          KeyFieldPos := IndexDefs.IndexOf('PRI');
          if KeyFieldPos < 0 then raise Exception.Create('Primary Key not found!')
          else
            KeyFieldName := IndexDefs.Items[KeyFieldPos].Fields;
          SQL := 'DELETE FROM ' + InternalSeparateLeft(Fields[0].FieldName,
            '.') + ' WHERE ' + InternalSeparateRight(KeyFieldName, '.') +
            '=' + FieldByName(KeyFieldName).AsString;
          ExecSQL;
        end
        else
          ShowMessage('Upate me ' + Fields[0].AsString);
      end;
    end;
  end;
end;

procedure TXMLMySQLDataSet.LoadBlobIntoBuffer(FieldDef: TFieldDef;
  ABlobBuf: PBufBlobField);
begin
  //Todo:
  //inherited LoadBlobIntoBuffer(FieldDef, ABlobBuf);
  // ShowMessage(inttostr(FieldDef.FieldNo));
end;

procedure TXMLMySQLDataSet.BeginUpdate;
begin
  Inc(fUpdateLock);
end;

procedure TXMLMySQLDataSet.EndUpdate;
begin
  Dec(fUpdateLock);
end;

procedure TXMLMySQLDataSet.ExecSQL;
begin
  fStrm.Clear;
  if fLocal then fStrm.LoadFromFile(URL)
  else
  begin
    if HttpPostURL('key=' + EncodeURLElement(fKey) + '&sql=' +
      EncodeURLElement(SQL), fStrm) then
    begin
      fStrm.Position := 0;
      try
        if fStrm.Size > 0 then
        begin
          if TXMLMySQLDatapacketReader.RecognizeStream(fStrm) then
          begin
            Close;
            Fields.Clear; //Wie löscht man alles?
            FieldDefs.Clear;
            IndexDefs.Clear;
            fStrm.Position := 0;
            LoadFromStream(fStrm, dfXML);
            fStrm.Position := 0;
          end
          else
            raise EDatabaseError.Create(GetResponse);
        end;
      except
        if fStrm.Size > 0 then
        begin
          fStrm.Position := 0;
          if MessageDlg('MySQL Error', GetResponse, mtError, [mbAbort], 0) = mrAbort then;
          //raise EDatabaseError.Create(GetResponse);
        end;
      end;
    end;
  end;
end;


function TXMLMySQLDataSet.HttpPostURL(URLData: string; const Data: TStream): boolean;
var
  Client: TFPHttpClient;
begin
  Result := False;
  Client := TFPHttpClient.Create(nil);
  Client.AddHeader('User-Agent', 'Mozilla/5.0 (compatible; fpweb)');
  Client.AddHeader('Content-Type', 'application/x-www-form-urlencoded');
  Client.AllowRedirect := True;
  //Client.UserName := USER_STRING;
  //Client.Password := PASSW_STRING;
  Client.RequestBody := TRawByteStringStream.Create(URLData);
  try
    try
      Data.Position := 0;
      Client.Post(URL, Data);
      //Writeln('Response Code: ' + IntToStr(Client.ResponseStatusCode)); // better be 200
      Result := True;
    except
      on E: Exception do
       if MessageDlg('TFPHttpClient Error', E.Message, mtError, [mbAbort], 0) = mrAbort then;
    end;
  finally
    Client.RequestBody.Free;
    Client.Free;
  end;
end;

function TXMLMySQLDataSet.GetResponse: string;
begin
  if fStrm.Size > 0 then
  begin
    fStrm.Position := 0;
    SetString(Result, pansichar(fStrm.Memory), fStrm.Size);
    fStrm.Position := 0;
  end else
    Result := '';
end;

procedure TXMLMySQLDataSet.SetURL(const AValue: string);
begin
  fURL := AValue;
  fLocal := not Pos('http', Lowercase(AValue)) = 1;
end;

end.
