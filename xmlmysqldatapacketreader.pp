unit XMLMySQLDatapacketReader;

{$MODE objfpc}{$H+}
{_$codepage UTF8}

interface

uses
  Classes, SysUtils, Bufdataset, dom, DB, Dialogs, XMLMySQLhelpers;

type
  TChangeLogEntry = record
    UpdateKind: TUpdateKind;
    OrigEntry: integer;
    NewEntry: integer;
  end;
  TChangeLogEntryArr = array of TChangeLogEntry;


type
  { TXMLMySQLDatapacketReader }

  TXMLMySQLDatapacketReader = class(TDataPacketReader)
    XMLDocument: TXMLDocument;
    DataPacketNode: TDOMElement;
    MetaDataNode: TDOMNode;
    FieldsNode: TDOMNode;
    FChangeLogNode, FParamsNode, FRowDataNode, FRecordNode: TDOMNode;
    FChangeLog: TChangeLogEntryArr;
    FEntryNr: integer;
    FLastChange: integer;
  public
    destructor Destroy; override;
    procedure LoadFieldDefs(var AnAutoIncValue: integer); override;
    procedure InitLoadRecords; override;
    function GetCurrentRecord: boolean; override;
    function GetRecordRowState(out AUpdOrder: integer): TRowState; override;
    procedure RestoreRecord; override;
    procedure GotoNextRecord; override;
    class function RecognizeStream(AStream: TStream): boolean; override;
  end;

implementation

uses xmlread;

resourcestring
  sUnknownXMLDatasetFormat = 'Unknown XML Dataset format';

{ TXMLMySQLDatapacketReader }

destructor TXMLMySQLDatapacketReader.Destroy;
begin
  FieldsNode.Free;
  MetaDataNode.Free;
  DataPacketNode.Free;
  XMLDocument.Free;
  inherited Destroy;
end;

procedure TXMLMySQLDatapacketReader.LoadFieldDefs(var AnAutoIncValue: integer);

  function GetNodeAttribute(const aNode: TDOMNode; AttName: string): string;
  var
    AnAttr: TDomNode;
  begin
    AnAttr := ANode.Attributes.GetNamedItem(UTF8DEcode(AttName));
    if assigned(AnAttr) then Result := UTF8Encode(AnAttr.NodeValue)
    else
      Result := '';
  end;

var
  i, s: integer;
  AFieldDef: TFieldDef;
  FTAString: string;
  SubFTString: string;
  SQLType: enum_field_types;
  AFieldNode: TDOMNode;
  AnAutoIncNode: TDomNode;
  lSize, lDeci: integer;
  lNewType: TFieldType;
  lNewSize: integer;
begin
  ReadXMLFile(XMLDocument, Stream);
  DataPacketNode := XMLDocument.FindNode('DATAPACKET') as TDOMElement;
  if not assigned(DataPacketNode) then DatabaseError(sUnknownXMLDatasetFormat);

  MetaDataNode := DataPacketNode.FindNode('METADATA');
  if not assigned(MetaDataNode) then DatabaseError(sUnknownXMLDatasetFormat);

  FieldsNode := MetaDataNode.FindNode('FIELDS');
  if not assigned(FieldsNode) then DatabaseError(sUnknownXMLDatasetFormat);

  with FieldsNode.ChildNodes do for i := 0 to Count - 1 do
    begin
      AFieldNode := item[i];
      if AFieldNode.CompareName('FIELD') = 0 then
      begin
        AFieldDef := Dataset.FieldDefs.AddFieldDef;
        //AFieldDef:=TFieldDefClass.Create(Dataset.FieldDefs,'',ftUnknown,0,False,i+1,CP_UTF8);
        AFieldDef.DisplayName := GetNodeAttribute(AFieldNode, 'fieldname');
        AFieldDef.Name := GetNodeAttribute(AFieldNode, 'attrname');
        // Difference in casing between CDS and bufdataset...
        S := StrToIntDef(GetNodeAttribute(AFieldNode, 'width'), -1);
        if (S = -1) then
          S := StrToIntDef(GetNodeAttribute(AFieldNode, 'WIDTH'), 0);
        AFieldDef.Size := S;
        FTAString := GetNodeAttribute(AFieldNode, 'fieldtype');
        SubFTString := GetNodeAttribute(AFieldNode, 'subtype');
        if SubFTString <> '' then
          FTAString := FTAString + ':' + SubFTString;

        if GetNodeAttribute(AFieldNode, 'key') = 'PRI' then
        begin
          if Dataset.IndexDefs.IndexOf('PRI') < 0 then
          begin
            Dataset.MaxIndexesCount := Dataset.MaxIndexesCount + 1;
            Dataset.AddIndex('PRI', AFieldDef.Name, [ixPrimary]);
          end;
        end;

        AFieldDef.DataType := ftUnknown;

        SQLType := MYSQLTypeFromString(FTAString);
        SplitNums(GetNodeAttribute(AFieldNode, 'width'), ',', lSize, lDeci);
        MySQLDataType(SQLType, lSize, lDeci, lNewType, lNewSize);
        AFieldDef.DataType := lNewType;
        AFieldDef.Precision := lDeci;

        if lNewSize = 0 then
          case lNewType of
            ftFloat:
            begin
              LNewSize := 12;
              AFieldDef.Precision := 4;
            end;
            ftBCD:
            begin
              LNewSize := 4;
              AFieldDef.Precision := 4;
            end;
          end;

        if (lNewType = ftString) and (lNewsize = 0) then AFieldDef.Size := $FF
        else
          AFieldDef.Size := lNewSize;
        //if (lNewType = ftString) then AFieldDef.Size := AFieldDef.Size Div 4;  //Utf-8 vs Bytes Was tun ?
      end;
    end;

  FParamsNode := MetaDataNode.FindNode('PARAMS');
  if assigned(FParamsNode) then
  begin
    FChangeLogNode := FParamsNode.Attributes.GetNamedItem('CHANGE_LOG');
    AnAutoIncNode := FParamsNode.Attributes.GetNamedItem('AUTOINCVALUE');
    if assigned(AnAutoIncNode) then
      AnAutoIncValue := StrToIntDef(UTF8Encode(AnAutoIncNode.NodeValue), -1);
  end;

  FRowDataNode := DataPacketNode.FindNode('ROWDATA');
  FRecordNode := nil;
end;


function TXMLMySQLDatapacketReader.GetCurrentRecord: boolean;
begin
  Result := assigned(FRecordNode);
end;

function TXMLMySQLDatapacketReader.GetRecordRowState(
  out AUpdOrder: integer): TRowState;
var
  ARowStateNode: TDOmNode;
  i: integer;
begin
  ARowStateNode := FRecordNode.Attributes.GetNamedItem('RowState');
  if ARowStateNode = nil then // This item is not edited
    Result := []
  else
  begin
    Result := ByteToRowState(StrToIntDef(UTF8Encode(ARowStateNode.NodeValue), 0));
    if Result = [rsvOriginal] then
    begin
      for i := 0 to length(FChangeLog) - 1 do
        if FChangeLog[i].NewEntry = FEntryNr then break;
      assert(FChangeLog[i].NewEntry = FEntryNr);
    end
    else
    begin
      for i := 0 to length(FChangeLog) - 1 do
        if FChangeLog[i].OrigEntry = FEntryNr then break;
      assert(FChangeLog[i].OrigEntry = FEntryNr);
    end;
    AUpdOrder := i;
  end;
end;

procedure TXMLMySQLDatapacketReader.InitLoadRecords;

var
  ChangeLogStr: string;
  i, cp: integer;
  ps: string;

begin
  FRecordNode := FRowDataNode.FirstChild;
  FEntryNr := 1;
  setlength(FChangeLog, 0);
  if assigned(FChangeLogNode) then
    ChangeLogStr := UTF8Encode(FChangeLogNode.NodeValue)
  else
    ChangeLogStr := '';
  ps := '';
  cp := 0;
  if ChangeLogStr <> '' then for i := 1 to length(ChangeLogStr) + 1 do
    begin
      if not (ChangeLogStr[i] in [' ', #0]) then
        ps := ps + ChangeLogStr[i]
      else
      begin
        case (cp mod 3) of
          0: begin
            SetLength(FChangeLog, length(FChangeLog) + 1);
            FChangeLog[cp div 3].OrigEntry := StrToIntDef(ps, 0);
          end;
          1: FChangeLog[cp div 3].NewEntry := StrToIntDef(ps, 0);
          2: begin
            if ps = '2' then
              FChangeLog[cp div 3].UpdateKind := ukDelete
            else if ps = '4' then
              FChangeLog[cp div 3].UpdateKind := ukInsert
            else if ps = '8' then
              FChangeLog[cp div 3].UpdateKind := ukModify;
          end;
        end; {case}
        ps := '';
        Inc(cp);
      end;
    end;
end;



procedure TXMLMySQLDatapacketReader.RestoreRecord;
var
  FieldNr: integer;
  AFieldNode: TDomNode;
begin
  with Dataset do for FieldNr := 0 to FieldCount - 1 do
    begin
      AFieldNode := FRecordNode.ChildNodes[FieldNr].FirstChild;
      if assigned(AFieldNode) then
      begin
        if AFieldNode.NodeValue <> '' then
          case Fields[FieldNr].DataType of
            ftDateTime: Fields[FieldNr].AsDateTime :=
                InternalStrToDateTime(UTF8Encode(AFieldNode.NodeValue));
            ftDate: Fields[FieldNr].AsDateTime :=
                InternalStrToDate(UTF8Encode(AFieldNode.NodeValue));
            ftTime: Fields[FieldNr].AsDateTime :=
                InternalStrToTime(UTF8Encode(AFieldNode.NodeValue));
            ftTimeStamp: Fields[FieldNr].AsDateTime :=
                InternalStrToTimeStamp(UTF8Encode(AFieldNode.NodeValue));
            else
              Fields[FieldNr].AsString := UTF8Encode(AFieldNode.NodeValue);
              // set it to the filterbuffer
          end
        else
          Fields[FieldNr].AsString := '';
      end;
    end;
end;



class function TXMLMySQLDatapacketReader.RecognizeStream(AStream: TStream): boolean;
const
  XmlStart = '<?xml';
var
  s: string;
  len: integer;
begin
  s:='';
  Len := length(XmlStart);
  setlength(s, len);
  if (AStream.Read(s[1], len) = len) and (s = XmlStart) then
    Result := True
  else
    Result := False;
end;

procedure TXMLMySQLDatapacketReader.GotoNextRecord;
begin
  FRecordNode := FRecordNode.NextSibling;
  Inc(FEntryNr);
  while assigned(FRecordNode) and (FRecordNode.CompareName('ROW') <> 0) do
    FRecordNode := FRecordNode.NextSibling;
end;

initialization
  RegisterDatapacketReader(TXMLMySQLDatapacketReader, dfXML);
end.
