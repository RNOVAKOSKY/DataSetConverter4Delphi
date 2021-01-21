unit DataSetConverter4D.Impl;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.DateUtils,
  System.NetEncoding,
  System.TypInfo,
  Data.SqlTimSt,
  Data.FmtBcd,
  Data.DB,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  DataSetConverter4D,
  DataSetConverter4D.Util;

type

  TDataSetConverter = class(TInterfacedObject, IDataSetConverter)
  private
    fDataSet: TDataSet;
    fOwns: Boolean;
    procedure ClearDataSet;
    function DataSetToDeltaJSONObject(dataSetDelta: TDataSet): TJSONObject; //Roberto
  protected
    function GetDataSet: TDataSet;

    function DataSetToJSONObject(dataSet: TDataSet): TJSONObject; overload;
    function DataSetToJSONObject(dataSet: TDataSet; fieldList :array of string): TJSONObject; overload;  //Roberto com opcao de escolher fieldList
    function DataSetToJSONArray(dataSet: TDataSet): TJSONArray;
    function DataSetToDeltaJSONArray(dataSet: TDataSet): TJSONArray; //Roberto
    function DataSetToDeltaJSONArrayV2(delta: IFDDataSetReference): TJSONArray; //Roberto
    function StructureToJSON(dataSet: TDataSet): TJSONArray;

    function Source(dataSet: TDataSet): IDataSetConverter; overload;
    function Source(dataSet: TDataSet; const owns: Boolean): IDataSetConverter; overload;

    function AsJSONObject: TJSONObject; overload;
    function AsJSONObject(fieldList :array of string): TJSONObject; overload;  //Roberto com opcao de escolher fieldList
    function AsJSONArray: TJSONArray;
    function AsJSONStructure: TJSONArray;

    function AsDeltaJSONArray: TJSONArray; //Roberto
  public
    constructor Create;
    destructor Destroy; override;

    class function New: IDataSetConverter; static;
  end;

  TFDDeltaConverter = class(TInterfacedObject, IFDDeltaConverter)
  private
    fDelta: IFDDataSetReference;
    fFieldList :array of string;
    function DeltaToJSONObject(deltaDataSet: TFDMemTable): TJSONObject;
    function DataSetToJSONObject(dataSet: TFDMemTable): TJSONObject;
    function CurrentRecordHasModifiedFieldToDelta(dataSet: TFDDataSet): Boolean;
  protected

    function Source(delta: IFDDataSetReference): IFDDeltaConverter;
    function DeltaToJSONArray(delta: IFDDataSetReference): TJSONArray;


    function AsJSONArray: TJSONArray; overload;
    function AsJSONArray(const fieldList :array of string): TJSONArray; overload;
  public
    constructor Create;
    destructor Destroy; override;

    class function New: IFDDeltaConverter; static;
  end;



  TJSONConverter = class(TInterfacedObject, IJSONConverter)
  private
    fJSONObject: TJSONObject;
    fJSONArray: TJSONArray;
    fOwns: Boolean;
    fIsRecord: Boolean;
    //
    fFieldsPresenceMandatory :TFields;
    // FieldName: string
    // DataType: TFieldType
    // Size: integer
    // Required: boolean (mesmo que notNull)
    fMinRecords :integer;
    fMaxRecords :integer;
    //
    procedure ClearJSONs;
  protected
    procedure JSONObjectToDataSet(json: TJSONObject; dataSet: TDataSet; const recNo: Integer; const isRecord: Boolean);
    procedure JSONArrayToDataSet(json: TJSONArray; dataSet: TDataSet; const isRecord: Boolean);
    procedure JSONArrayToDeltaDataSet(json: TJSONArray; dataSet: TDataSet; const isRecord: Boolean);
    procedure JSONToStructure(json: TJSONArray; dataSet: TDataSet);

    function Source(json: TJSONObject): IJSONConverter; overload;
    function Source(json: TJSONObject; const owns: Boolean): IJSONConverter; overload;

    function Source(json: TJSONArray): IJSONConverter; overload;
    function Source(json: TJSONArray; const owns: Boolean): IJSONConverter; overload;

    procedure ToDataSet(dataSet: TDataSet);
    procedure ToRecord(dataSet: TDataSet);
    procedure ToStructure(dataSet: TDataSet);
    procedure ToDeltaDataSet(dataSet: TDataSet);
  public
    constructor Create;
    destructor Destroy; override;

    class function New: IJSONConverter; static;
  end;

  TConverter = class(TInterfacedObject, IConverter)
  private
    { private declarations }
  protected
    function DataSet: IDataSetConverter; overload;
    function DataSet(dataSet: TDataSet): IDataSetConverter; overload;
    function DataSet(dataSet: TDataSet; const owns: Boolean): IDataSetConverter; overload;

    function Delta: IFDDeltaConverter; overload;
    function Delta(delta: IFDDataSetReference): IFDDeltaConverter; overload;

    function JSON: IJSONConverter; overload;
    function JSON(json: TJSONObject): IJSONConverter; overload;
    function JSON(json: TJSONObject; const owns: Boolean): IJSONConverter; overload;

    function JSON(json: TJSONArray): IJSONConverter; overload;
    function JSON(json: TJSONArray; const owns: Boolean): IJSONConverter; overload;
  public
    class function New: IConverter; static;
  end;

implementation

{ TDataSetConverter }

function TDataSetConverter.AsJSONArray: TJSONArray;
begin
  Result := DataSetToJSONArray(GetDataSet);
end;

function TDataSetConverter.AsJSONObject: TJSONObject;
begin
  Result := DataSetToJSONObject(GetDataSet);
end;


function TDataSetConverter.AsJSONObject(fieldList :array of string): TJSONObject;
begin
  Result := DataSetToJSONObject(GetDataSet, fieldList);
end;

constructor TDataSetConverter.Create;
begin
  inherited Create;
  fDataSet := nil;
  fOwns := False;
end;

function TDataSetConverter.DataSetToDeltaJSONArray(
  dataSet: TDataSet): TJSONArray;
var
  //bookMark: TBookmark;
  deltaDataSet :TFDMemTable;
begin
  Result := nil;
  if (not Assigned(dataSet)) or (dataSet.IsEmpty) then Exit;

  if (dataSet.ClassName = 'TFDMemTable') then
    begin

    if (not (dataSet AS TFDMemTable).UpdatesPending) then Exit;

    deltaDataSet := TFDMemTable.Create(nil);
    deltaDataSet.FilterChanges := [rtUnmodified, rtModified, rtInserted, rtDeleted];
    deltaDataSet.Data := (dataSet AS TFDMemTable).Delta;

    end
  else
    begin
    //tipo de TDataSet Nao suportado neste código
    Exit;
    end;




  //if Assigned(dataSet) and (not dataSet.IsEmpty) then
    try
      Result := TJSONArray.Create;
      //bookMark := dataSet.Bookmark;
      deltaDataSet.First;
      while not deltaDataSet.Eof do
      begin
        if (deltaDataSet.UpdateStatus = usModified) then
        begin
        Result.AddElement(DataSetToDeltaJSONObject(deltaDataSet));
        //deltaDataSet
        deltaDataSet.Next;
        end;
      end;
    finally
      //if dataSet.BookmarkValid(bookMark) then
      //  dataSet.GotoBookmark(bookMark);
      //dataSet.FreeBookmark(bookMark);
      deltaDataSet.Free;
    end;

end;

function TDataSetConverter.DataSetToDeltaJSONArrayV2(
  delta: IFDDataSetReference): TJSONArray;
var
  deltaDataSet :TFDMemTable;
begin
  Result := nil;
  if (not Assigned(delta)) then Exit;

  try
    deltaDataSet := TFDMemTable.Create(nil);
    deltaDataSet.FilterChanges := [rtUnmodified, rtModified, rtInserted, rtDeleted];
    deltaDataSet.Data := Delta;

    Result := TJSONArray.Create;
    deltaDataSet.First;
    while not deltaDataSet.Eof do
      begin
      if (deltaDataSet.UpdateStatus = usModified) then
        begin
        Result.AddElement(DataSetToDeltaJSONObject(deltaDataSet));
        deltaDataSet.Next;
        end;
      end;
  finally

      deltaDataSet.Free;
  end;

end;

function TDataSetConverter.DataSetToDeltaJSONObject(
  dataSetDelta: TDataSet): TJSONObject;
var
  i: Integer;
  key: string;
  timeStamp: TSQLTimeStamp;
  nestedDataSet: TDataSet;
  dft: TDataSetFieldType;
  bft: TBooleanFieldType;
  ms: TMemoryStream;
  ss: TStringStream;
  deltaDataSet : TFDMemTable;

begin
  Result := nil;
  deltaDataSet := dataSetDelta AS TFDMemTable;
  if Assigned(dataSetDelta) and (not dataSetDelta.IsEmpty) then
  if deltaDataSet.UpdateStatus <> usUnmodified then
  begin
    Result := TJSONObject.Create;
    if deltaDataSet.UpdateStatus = usModified then
      begin
      Result.AddPair('ClassName', dataSetDelta.ClassName);
      Result.AddPair('RecNo', TJSONNumber.Create(deltaDataSet.RecNo) );
      Result.AddPair('RowState', 'Modified');
      //Result.AddPair('Original', DataSetToJSONObjectOldValue(dataSet));
      Result.AddPair('Current', DataSetToJSONObject(deltaDataSet));
      deltaDataSet.RevertRecord;
      Result.AddPair('Original', DataSetToJSONObject(deltaDataSet));
      end
    else
    if deltaDataSet.UpdateStatus = usInserted then
      begin
      Result.AddPair('RowState', 'Inserted');
      Result.AddPair('Current', DataSetToJSONObject(deltaDataSet));
      end;
  end;

end;

function TDataSetConverter.DataSetToJSONArray(dataSet: TDataSet): TJSONArray;
var
  bookMark: TBookmark;
begin
  Result := nil;
  if Assigned(dataSet) and (not dataSet.IsEmpty) then
    try
      Result := TJSONArray.Create;
      bookMark := dataSet.Bookmark;
      dataSet.First;
      while not dataSet.Eof do
      begin
        Result.AddElement(DataSetToJSONObject(dataSet));
        dataSet.Next;
      end;
    finally
      if dataSet.BookmarkValid(bookMark) then
        dataSet.GotoBookmark(bookMark);
      dataSet.FreeBookmark(bookMark);
    end;
end;

function TDataSetConverter.DataSetToJSONObject(dataSet: TDataSet): TJSONObject;
var
  i: Integer;
  key: string;
  timeStamp: TSQLTimeStamp;
  nestedDataSet: TDataSet;
  dft: TDataSetFieldType;
  bft: TBooleanFieldType;
  ms: TMemoryStream;
  ss: TStringStream;
begin
  Result := nil;
  if Assigned(dataSet) and (not dataSet.IsEmpty) then
  begin
    Result := TJSONObject.Create;
    for i := 0 to Pred(dataSet.FieldCount) do
    begin
      if dataSet.Fields[i].Visible then
      begin
        key := dataSet.Fields[i].FieldName;
        case dataSet.Fields[i].DataType of
          TFieldType.ftBoolean:
            begin
              bft := BooleanFieldToType(TBooleanField(dataSet.Fields[i]));
              case bft of
                bfUnknown, bfBoolean: Result.AddPair(key, BooleanToJSON(dataSet.Fields[i].AsBoolean));
                bfInteger: Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[i].AsInteger));
              end;
            end;
          TFieldType.ftInteger, TFieldType.ftSmallint, TFieldType.ftShortint:
            Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[i].AsInteger));
          TFieldType.ftLongWord, TFieldType.ftAutoInc:
            begin
              if not dataSet.Fields[i].IsNull then
                Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[i].AsWideString))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftLargeint:
            Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[i].AsLargeInt));
          TFieldType.ftSingle, TFieldType.ftFloat:
            Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[i].AsFloat));
          ftString, ftWideString, ftMemo, ftWideMemo:
            begin
              if not dataSet.Fields[i].IsNull then
                Result.AddPair(key, TJSONString.Create(dataSet.Fields[i].AsWideString))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftDate:
            begin
              if not dataSet.Fields[i].IsNull then
                Result.AddPair(key, TJSONString.Create(DateToISODate(dataSet.Fields[i].AsDateTime)))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftTimeStamp, TFieldType.ftDateTime:
            begin
              if not dataSet.Fields[i].IsNull then
                Result.AddPair(key, TJSONString.Create(DateTimeToISOTimeStamp(dataSet.Fields[i].AsDateTime)))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftTime:
            begin
              if not dataSet.Fields[i].IsNull then
              begin
                timeStamp := dataSet.Fields[i].AsSQLTimeStamp;
                Result.AddPair(key, TJSONString.Create(SQLTimeStampToStr('hh:nn:ss', timeStamp)));
              end
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftCurrency:
            begin
              if not dataSet.Fields[i].IsNull then
                Result.AddPair(key, TJSONString.Create(FormatCurr('0.00##', dataSet.Fields[i].AsCurrency)))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftFMTBcd, TFieldType.ftBCD:
            begin
              if not dataSet.Fields[i].IsNull then
                Result.AddPair(key, TJSONNumber.Create(BcdToDouble(dataSet.Fields[i].AsBcd)))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftDataSet:
            begin
              dft := DataSetFieldToType(TDataSetField(dataSet.Fields[i]));
              nestedDataSet := TDataSetField(dataSet.Fields[i]).NestedDataSet;
              case dft of
                dfJSONObject:
                  Result.AddPair(key, DataSetToJSONObject(nestedDataSet));
                dfJSONArray:
                  Result.AddPair(key, DataSetToJSONArray(nestedDataSet));
              end;
            end;
          TFieldType.ftGraphic, TFieldType.ftBlob, TFieldType.ftStream:
            begin
              ms := TMemoryStream.Create;
              try
                TBlobField(dataSet.Fields[I]).SaveToStream(ms);
                ms.Position := 0;
                ss := TStringStream.Create;
                try
                  TNetEncoding.Base64.Encode(ms, ss);
                  Result.AddPair(key, TJSONString.Create(ss.DataString));
                finally
                  ss.Free;
                end;
              finally
                ms.Free;
              end;
            end;
        else
          raise EDataSetConverterException.CreateFmt('Cannot find type for field "%s"', [key]);
        end;
      end;
    end;
  end;
end;

function TDataSetConverter.DataSetToJSONObject(dataSet: TDataSet;
  fieldList: array of string): TJSONObject;
var
  j: Integer;
  key: string;
  timeStamp: TSQLTimeStamp;
  nestedDataSet: TDataSet;
  dft: TDataSetFieldType;
  bft: TBooleanFieldType;
  ms: TMemoryStream;
  ss: TStringStream;
  f :TField;
  idx :integer;
begin
  Result := nil;
  if Assigned(dataSet) and (not dataSet.IsEmpty) and (Length(fieldList)>0) then
  begin
    Result := TJSONObject.Create;
    for j := 0 to Pred( Length(fieldList) ) do
    begin
        key := fieldList[j];
        f := dataset.FieldByName(key);
      if (f <> nil) then
      begin
        idx := f.Index;
        case dataSet.Fields[idx].DataType of
          TFieldType.ftBoolean:
            begin
              bft := BooleanFieldToType(TBooleanField(dataSet.Fields[idx]));
              case bft of
                bfUnknown, bfBoolean: Result.AddPair(key, BooleanToJSON(dataSet.Fields[idx].AsBoolean));
                bfInteger: Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[idx].AsInteger));
              end;
            end;
          TFieldType.ftInteger, TFieldType.ftSmallint, TFieldType.ftShortint:
            Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[idx].AsInteger));
          TFieldType.ftLongWord, TFieldType.ftAutoInc:
            begin
              if not dataSet.Fields[idx].IsNull then
                Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[idx].AsWideString))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftLargeint:
            Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[idx].AsLargeInt));
          TFieldType.ftSingle, TFieldType.ftFloat:
            Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[idx].AsFloat));
          ftString, ftWideString, ftMemo, ftWideMemo:
            begin
              if not dataSet.Fields[idx].IsNull then
                Result.AddPair(key, TJSONString.Create(dataSet.Fields[idx].AsWideString))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftDate:
            begin
              if not dataSet.Fields[idx].IsNull then
                Result.AddPair(key, TJSONString.Create(DateToISODate(dataSet.Fields[idx].AsDateTime)))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftTimeStamp, TFieldType.ftDateTime:
            begin
              if not dataSet.Fields[idx].IsNull then
                Result.AddPair(key, TJSONString.Create(DateTimeToISOTimeStamp(dataSet.Fields[idx].AsDateTime)))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftTime:
            begin
              if not dataSet.Fields[idx].IsNull then
              begin
                timeStamp := dataSet.Fields[idx].AsSQLTimeStamp;
                Result.AddPair(key, TJSONString.Create(SQLTimeStampToStr('hh:nn:ss', timeStamp)));
              end
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftCurrency:
            begin
              if not dataSet.Fields[idx].IsNull then
                Result.AddPair(key, TJSONString.Create(FormatCurr('0.00##', dataSet.Fields[idx].AsCurrency)))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftFMTBcd, TFieldType.ftBCD:
            begin
              if not dataSet.Fields[idx].IsNull then
                Result.AddPair(key, TJSONNumber.Create(BcdToDouble(dataSet.Fields[idx].AsBcd)))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftDataSet:
            begin
              dft := DataSetFieldToType(TDataSetField(dataSet.Fields[idx]));
              nestedDataSet := TDataSetField(dataSet.Fields[idx]).NestedDataSet;
              case dft of
                dfJSONObject:
                  Result.AddPair(key, DataSetToJSONObject(nestedDataSet));
                dfJSONArray:
                  Result.AddPair(key, DataSetToJSONArray(nestedDataSet));
              end;
            end;
          TFieldType.ftGraphic, TFieldType.ftBlob, TFieldType.ftStream:
            begin
              ms := TMemoryStream.Create;
              try
                TBlobField(dataSet.Fields[idx]).SaveToStream(ms);
                ms.Position := 0;
                ss := TStringStream.Create;
                try
                  TNetEncoding.Base64.Encode(ms, ss);
                  Result.AddPair(key, TJSONString.Create(ss.DataString));
                finally
                  ss.Free;
                end;
              finally
                ms.Free;
              end;
            end;
        else
          raise EDataSetConverterException.CreateFmt('Cannot find type for field "%s"', [key]);
        end;
      end;
    end;
  end;

end;




function TDataSetConverter.AsDeltaJSONArray: TJSONArray;
begin
  Result := DataSetToDeltaJSONArray(GetDataSet);
end;

destructor TDataSetConverter.Destroy;
begin
  ClearDataSet;
  inherited Destroy;
end;

procedure TDataSetConverter.ClearDataSet;
begin
  if fOwns then
    if Assigned(fDataSet) then
      fDataSet.Free;
  fDataSet := nil;
end;

function TDataSetConverter.GetDataSet: TDataSet;
begin
  if (fDataSet = nil) then
    raise EDataSetConverterException.Create('DataSet Uninformed.');
  Result := fDataSet;
end;

class function TDataSetConverter.New: IDataSetConverter;
begin
  Result := TDataSetConverter.Create;
end;

function TDataSetConverter.Source(dataSet: TDataSet; const owns: Boolean): IDataSetConverter;
begin
  ClearDataSet;
  fDataSet := dataSet;
  fOwns := owns;
  Result := Self;
end;

function TDataSetConverter.AsJSONStructure: TJSONArray;
begin
  Result := StructureToJSON(GetDataSet);
end;

function TDataSetConverter.StructureToJSON(dataSet: TDataSet): TJSONArray;
var
  i: Integer;
  jo: TJSONObject;
begin
  Result := nil;
  if Assigned(dataSet) and (dataSet.FieldCount > 0) then
  begin
    Result := TJSONArray.Create;
    for i := 0 to Pred(dataSet.FieldCount) do
    begin
      jo := TJSONObject.Create;
      jo.AddPair('FieldName', TJSONString.Create(dataSet.Fields[i].FieldName));
      jo.AddPair('DataType', TJSONString.Create(GetEnumName(TypeInfo(TFieldType), Integer(dataSet.Fields[i].DataType))));
      jo.AddPair('Size', TJSONNumber.Create(dataSet.Fields[i].Size));
      Result.AddElement(jo);
    end;
  end;
end;

function TDataSetConverter.Source(dataSet: TDataSet): IDataSetConverter;
begin
  Result := Source(dataSet, False);
end;

{ TJSONConverter }

constructor TJSONConverter.Create;
begin
  inherited Create;
  fJSONObject := nil;
  fJSONArray := nil;
  fOwns := False;
  fIsRecord := False;
end;

destructor TJSONConverter.Destroy;
begin
  ClearJSONs;
  inherited Destroy;
end;

procedure TJSONConverter.ClearJSONs;
begin
  if fOwns then
  begin
    if Assigned(fJSONObject) then
      fJSONObject.Free;
    if Assigned(fJSONArray) then
      fJSONArray.Free;
  end;
  fJSONObject := nil;
  fJSONArray := nil;
end;

procedure TJSONConverter.JSONArrayToDataSet(json: TJSONArray; dataSet: TDataSet; const isRecord: Boolean);
var
  jv: TJSONValue;
  recNo: Integer;
begin
  if Assigned(json) and Assigned(dataSet) then
  begin
    recNo := 0;
    for jv in json do
    begin
      if not dataSet.IsEmpty then
        Inc(recNo);

      if (jv is TJSONArray) then
        JSONArrayToDataSet(jv as TJSONArray, dataSet, isRecord)
      else
        JSONObjectToDataSet(jv as TJSONObject, dataSet, recNo, isRecord);
    end;
  end;


end;

procedure TJSONConverter.JSONArrayToDeltaDataSet(json: TJSONArray; dataSet: TDataSet; const isRecord: Boolean);
var
  jv: TJSONValue;
  recNo: Integer;
  lJSONValue :TJSONValue;
  rowState :string;
begin
  if (not Assigned(json)) or (not Assigned(dataSet)) then Exit;

  if dataSet.IsEmpty then
    recNo := 0
  else
    begin
    dataSet.Last;
    recNo := dataSet.RecNo;
    end;


    for jv in json do
    begin
      if (jv is TJSONArray) then
        raise EDataSetConverterException.Create('Aninhamento não permitido em JSON Delta.');

        Inc(recNo);
        //Captura RowState
        if not  (jv as TJSONObject).TryGetValue('RowState', lJSONValue) then
          raise EDataSetConverterException.Create('Missing RowState in JSON Delta.');
        if (lJSONValue is TJSONNull) then
          raise EDataSetConverterException.Create('RowState must not be Null in JSON Delta.');
        rowState := lJSONValue.AsType<string>;
        //Captura Original Record
        if (rowState = 'Modified') or (rowState = 'Deleted') then
          begin
          if not  (jv as TJSONObject).TryGetValue('Original', lJSONValue) then
            raise EDataSetConverterException.Create('Missing Original Record in JSON Delta.');
          if not (lJSONValue is TJSONObject) then
            raise EDataSetConverterException.Create('Invalid Original Record in JSON Delta.');
          JSONObjectToDataSet(lJSONValue AS TJSONObject, dataSet, recNo, isRecord);

          if (dataSet.ClassName = 'TFDQuery') then    (dataSet AS TFDQuery).GetRow.AcceptChanges
          else
          if (dataSet.ClassName = 'TFDMemTable') then (dataSet AS TFDMemTable).GetRow.AcceptChanges
          else
          if (dataSet.ClassName = 'TFDDataSet') then  (dataSet AS TFDDataSet).GetRow.AcceptChanges;

          end;
        if (rowState = 'Modified') then
          begin
          if not  (jv as TJSONObject).TryGetValue('Current', lJSONValue) then
            raise EDataSetConverterException.Create('Missing Current Record in JSON Delta.');
          if not (lJSONValue is TJSONObject) then
            raise EDataSetConverterException.Create('Invalid Current Record in JSON Delta.');
          JSONObjectToDataSet(lJSONValue AS TJSONObject, dataSet, recNo, true);
          end
        else
        if (rowState = 'Deleted') then
          begin
          dataSet.RecNo := recNo;
          dataSet.Delete;
          end
        else
        if (rowState = 'Inserted') then
          begin
          if not  (jv as TJSONObject).TryGetValue('Current', lJSONValue) then
            raise EDataSetConverterException.Create('Missing Current Record in JSON Delta.');
          if not (lJSONValue is TJSONObject) then
            raise EDataSetConverterException.Create('Invalid Current Record in JSON Delta.');
          JSONObjectToDataSet(lJSONValue AS TJSONObject, dataSet, recNo, isRecord);
          end;

    end;


end;


procedure TJSONConverter.JSONObjectToDataSet(json: TJSONObject; dataSet: TDataSet; const recNo: Integer; const isRecord: Boolean);
var
  field: TField;
  jv: TJSONValue;
  dft: TDataSetFieldType;
  nestedDataSet: TDataSet;
  booleanValue: Boolean;
  ss: TStringStream;
  sm: TMemoryStream;
begin
  if not Assigned(json) then Exit;
  if not Assigned(dataSet) then Exit;

  if isRecord then
    begin
    if (recNo > 0) and (dataSet.RecordCount > 1) then
      dataSet.RecNo := recNo;
    dataSet.Edit;
    end
  else
    dataSet.Append;

    for field in dataSet.Fields do
    begin
      if Assigned(json.Get(field.FieldName)) then
        jv := json.Get(field.FieldName).JsonValue
      else
        Continue;
      if field.ReadOnly then
        Continue;
      case field.DataType of
        TFieldType.ftBoolean:
          begin
            if jv is TJSONNull then
              field.Clear
            else if jv.TryGetValue<Boolean>(booleanValue) then
              field.AsBoolean := booleanValue;
          end;
        TFieldType.ftInteger, TFieldType.ftSmallint, TFieldType.ftShortint, TFieldType.ftLongWord:
          begin
            if jv is TJSONNull then
              field.Clear
            else
              field.AsInteger := StrToIntDef(jv.Value, 0);
          end;
        TFieldType.ftLargeint, TFieldType.ftAutoInc:
          begin
            if jv is TJSONNull then
              field.Clear
            else
              field.AsLargeInt := StrToInt64Def(jv.Value, 0);
          end;
        TFieldType.ftCurrency:
          begin
            if jv is TJSONNull then
              field.Clear
            else
              field.AsCurrency := StrToCurr(jv.Value);
          end;
        TFieldType.ftFloat, TFieldType.ftFMTBcd, TFieldType.ftBCD, TFieldType.ftSingle:
          begin
            if jv is TJSONNull then
              field.Clear
            else
              field.AsFloat := StrToFloat(jv.Value);
          end;
        ftString, ftWideString, ftMemo, ftWideMemo:
          begin
            if jv is TJSONNull then
              field.Clear
            else
              field.AsString := jv.Value;
          end;
        TFieldType.ftDate:
          begin
            if jv is TJSONNull then
              field.Clear
            else
              field.AsDateTime := ISODateToDate(jv.Value);
          end;
        TFieldType.ftTimeStamp, TFieldType.ftDateTime:
          begin
            if jv is TJSONNull then
              field.Clear
            else
              field.AsDateTime := ISOTimeStampToDateTime(jv.Value);
          end;
        TFieldType.ftTime:
          begin
            if jv is TJSONNull then
              field.Clear
            else
              field.AsDateTime := ISOTimeToTime(jv.Value);
          end;
        TFieldType.ftDataSet:
          begin
            dft := DataSetFieldToType(TDataSetField(field));
            nestedDataSet := TDataSetField(field).NestedDataSet;
            case dft of
              dfJSONObject:
                JSONObjectToDataSet(jv as TJSONObject, nestedDataSet, 0, True);
              dfJSONArray:
                begin
                  nestedDataSet.First;
                  while not nestedDataSet.Eof do
                    nestedDataSet.Delete;
                  JSONArrayToDataSet(jv as TJSONArray, nestedDataSet, False);
                end;
            end;
          end;
        TFieldType.ftGraphic, TFieldType.ftBlob, TFieldType.ftStream:
          begin
            if jv is TJSONNull then
              field.Clear
            else
            begin
              ss := TStringStream.Create((Jv as TJSONString).Value);
              try
                ss.Position := 0;
                sm := TMemoryStream.Create;
                try
                  TNetEncoding.Base64.Decode(ss, sm);
                  TBlobField(Field).LoadFromStream(sm);
                finally
                  sm.Free;
                end;
              finally
                ss.Free;
              end;
            end;
          end;
      else
        raise EDataSetConverterException.CreateFmt('Cannot find type for field "%s"', [field.FieldName]);
      end;
    end;
    dataSet.Post;

end;

procedure TJSONConverter.JSONToStructure(json: TJSONArray; dataSet: TDataSet);
var
  jv: TJSONValue;
begin
  if Assigned(json) and Assigned(dataSet) then
  begin
    if dataSet.Active then
      raise EDataSetConverterException.Create('The DataSet can not be active.');

    if (dataSet.FieldCount > 0) then
      raise EDataSetConverterException.Create('The DataSet can not have predefined Fields.');

    for jv in json do
    begin
      NewDataSetField(dataSet, 
        TFieldType(GetEnumValue(TypeInfo(TFieldType), (jv as TJSONObject).GetValue('DataType').Value)), 
        (jv as TJSONObject).GetValue('FieldName').Value, 
        StrToIntDef((jv as TJSONObject).GetValue('Size').Value, 0)
        );
    end;
  end;
end;

class function TJSONConverter.New: IJSONConverter;
begin
  Result := TJSONConverter.Create;
end;

function TJSONConverter.Source(json: TJSONObject; const owns: Boolean): IJSONConverter;
begin
  ClearJSONs;
  fJSONObject := json;
  fOwns := owns;
  Result := Self;
end;

function TJSONConverter.Source(json: TJSONObject): IJSONConverter;
begin
  Result := Source(json, false);
end;

function TJSONConverter.Source(json: TJSONArray; const owns: Boolean): IJSONConverter;
begin
  ClearJSONs;
  fJSONArray := json;
  fOwns := owns;
  Result := Self;
end;

function TJSONConverter.Source(json: TJSONArray): IJSONConverter;
begin
  Result := Source(json, false);
end;

procedure TJSONConverter.ToDataSet(dataSet: TDataSet);
begin
  if Assigned(fJSONObject) then
    JSONObjectToDataSet(fJSONObject, dataSet, 0, fIsRecord)
  else if Assigned(fJSONArray) then
    JSONArrayToDataSet(fJSONArray, dataSet, fIsRecord)
  else
    raise EDataSetConverterException.Create('JSON Value Uninformed.');
end;

procedure TJSONConverter.ToDeltaDataSet(dataSet: TDataSet);
begin
  if (not Assigned(dataSet)) then
    raise EDataSetConverterException.Create('Missing DataSet.');

  if (not dataSet.Active) then
    raise EDataSetConverterException.Create('DataSet need to be Active.');

  //if (not dataSet.IsEmpty) then
  //  raise EDataSetConverterException.Create('Not Supported. DataSet need to be Empty.');

  //
  if (dataSet.ClassName <> 'TFDQuery') and (dataSet.ClassName <> 'TFDMemTable') and (dataSet.ClassName <> 'TFDDataSet') then
    raise EDataSetConverterException.Create('Kind of DataSet not Supported.');

  //
  if (dataSet.ClassName = 'TFDQuery') then
    if not (dataSet AS TFDQuery).CachedUpdates then
      raise EDataSetConverterException.Create('TFDQuery need CachedUpdates True to receive Delta.');

  if (dataSet.ClassName = 'TFDMemTable') then
    if not (dataSet AS TFDMemTable).CachedUpdates then
       raise EDataSetConverterException.Create('TFDMemTable need CachedUpdates True to receive Delta.');

  if (dataSet.ClassName = 'TFDDataSet') then
    if not (dataSet AS TFDDataSet).CachedUpdates then
       raise EDataSetConverterException.Create('TFDDataSet need CachedUpdates True to receive Delta.');

  //
  if Assigned(fJSONArray) then
    JSONArrayToDeltaDataSet(fJSONArray, dataSet, fIsRecord)
  else
    raise EDataSetConverterException.Create('JSON Value Uninformed.');
end;

procedure TJSONConverter.ToRecord(dataSet: TDataSet);
begin
  fIsRecord := True;
  try
    ToDataSet(dataSet);
  finally
    fIsRecord := False;
  end;
end;

procedure TJSONConverter.ToStructure(dataSet: TDataSet);
begin
  if Assigned(fJSONObject) then
    raise EDataSetConverterException.Create('To convert a structure only JSONArray is allowed.')
  else if Assigned(fJSONArray) then
    JSONToStructure(fJSONArray, dataSet)
  else
    raise EDataSetConverterException.Create('JSON Value Uninformed.');
end;

{ TConverter }

function TConverter.DataSet: IDataSetConverter;
begin
  Result := TDataSetConverter.New;
end;

function TConverter.DataSet(dataSet: TDataSet): IDataSetConverter;
begin
  Result := Self.DataSet.Source(dataSet);
end;

function TConverter.DataSet(dataSet: TDataSet; const owns: Boolean): IDataSetConverter;
begin
  Result := Self.DataSet.Source(dataSet, owns);
end;

function TConverter.Delta: IFDDeltaConverter;
begin
 Result := TFDDeltaConverter.New;
end;

function TConverter.Delta(delta: IFDDataSetReference): IFDDeltaConverter;
begin
 Result := Self.Delta.Source(delta);
end;

function TConverter.JSON(json: TJSONObject; const owns: Boolean): IJSONConverter;
begin
  Result := Self.JSON.Source(json, owns);
end;

function TConverter.JSON(json: TJSONObject): IJSONConverter;
begin
  Result := Self.JSON.Source(json);
end;

function TConverter.JSON: IJSONConverter;
begin
  Result := TJSONConverter.New;
end;

function TConverter.JSON(json: TJSONArray; const owns: Boolean): IJSONConverter;
begin
  Result := Self.JSON.Source(json, owns);
end;

function TConverter.JSON(json: TJSONArray): IJSONConverter;
begin
  Result := Self.JSON.Source(json);
end;

class function TConverter.New: IConverter;
begin
  Result := TConverter.Create;
end;

{ TDeltaConverter }

function TFDDeltaConverter.AsJSONArray: TJSONArray;
begin
  Result := DeltaToJSONArray(fDelta);
end;

function TFDDeltaConverter.AsJSONArray(const fieldList: array of string): TJSONArray;
var
  i :integer;
begin
  //
  if Length(fieldList) > 0 then
    begin
    SetLength(fFieldList, Length(fieldList));
    for i := 0 to (Length(fieldList)-1) do
      fFieldList[i] := fieldList[i];
    end;
  //
  //Validação: Os Fields que representam PK devem estar presentes

  //
  Result := DeltaToJSONArray(fDelta);
end;

constructor TFDDeltaConverter.Create;
begin
  inherited Create;
  fDelta := nil;
  SetLength(fFieldList, 0);
end;

function TFDDeltaConverter.CurrentRecordHasModifiedFieldToDelta(dataSet: TFDDataSet): Boolean;
var
  i :integer;
  f :TField;
begin
  //Apesar do registro ser usMofified, é possível que nenhum dos fields escolhidos para
  //retornarem como record Modified em um JSON, possui alteração, é possivel que o
  //registro esteja usModified por causa de um campo que não faz parte
  //dos campos que serão retornados, então não será considerado como Modified pata Conversão

  Result := false;
  if (dataSet.UpdateStatus <> usModified) then Exit;
  for i := 0 to Length(fFieldList)-1 do
    begin
    f := dataSet.FindField(fFieldList[i]);
    if f <> nil then
    if f.OldValue <> f.Value then
      begin
        Result := True;
        Exit;
      end;
    end;

end;

function TFDDeltaConverter.DataSetToJSONObject(dataSet: TFDMemTable): TJSONObject;
var
  j: Integer;
  key: string;
  timeStamp: TSQLTimeStamp;
  //nestedDataSet: TDataSet;
  dft: TDataSetFieldType;
  bft: TBooleanFieldType;
  ms: TMemoryStream;
  ss: TStringStream;
  f :TField;
  idx :integer;
begin
  Result := nil;
  if Length(fFieldList) = 0 then
    begin //entao considerar todos os fields
    SetLength(fFieldList, dataSet.FieldCount);
    for j := 0 to Pred(dataSet.FieldCount) do
      fFieldList[j] := dataSet.Fields[j].FieldName;
    end;

  if Assigned(dataSet) and (not dataSet.IsEmpty) and (Length(fFieldList)>0) then
  begin
    Result := TJSONObject.Create;
    for j := 0 to Pred( Length(fFieldList) ) do
    begin
        key := fFieldList[j];
        f := dataset.FieldByName(key);
      if (f <> nil) then
      begin
        idx := f.Index;
        case dataSet.Fields[idx].DataType of
          TFieldType.ftBoolean:
            begin
              bft := BooleanFieldToType(TBooleanField(dataSet.Fields[idx]));
              case bft of
                bfUnknown, bfBoolean: Result.AddPair(key, BooleanToJSON(dataSet.Fields[idx].AsBoolean));
                bfInteger: Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[idx].AsInteger));
              end;
            end;
          TFieldType.ftInteger, TFieldType.ftSmallint, TFieldType.ftShortint:
            Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[idx].AsInteger));
          TFieldType.ftLongWord, TFieldType.ftAutoInc:
            begin
              if not dataSet.Fields[idx].IsNull then
                Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[idx].AsWideString))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftLargeint:
            Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[idx].AsLargeInt));
          TFieldType.ftSingle, TFieldType.ftFloat:
            Result.AddPair(key, TJSONNumber.Create(dataSet.Fields[idx].AsFloat));
          ftString, ftWideString, ftMemo, ftWideMemo:
            begin
              if not dataSet.Fields[idx].IsNull then
                Result.AddPair(key, TJSONString.Create(dataSet.Fields[idx].AsWideString))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftDate:
            begin
              if not dataSet.Fields[idx].IsNull then
                Result.AddPair(key, TJSONString.Create(DateToISODate(dataSet.Fields[idx].AsDateTime)))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftTimeStamp, TFieldType.ftDateTime:
            begin
              if not dataSet.Fields[idx].IsNull then
                Result.AddPair(key, TJSONString.Create(DateTimeToISOTimeStamp(dataSet.Fields[idx].AsDateTime)))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftTime:
            begin
              if not dataSet.Fields[idx].IsNull then
              begin
                timeStamp := dataSet.Fields[idx].AsSQLTimeStamp;
                Result.AddPair(key, TJSONString.Create(SQLTimeStampToStr('hh:nn:ss', timeStamp)));
              end
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftCurrency:
            begin
              if not dataSet.Fields[idx].IsNull then
                Result.AddPair(key, TJSONString.Create(FormatCurr('0.00##', dataSet.Fields[idx].AsCurrency)))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftFMTBcd, TFieldType.ftBCD:
            begin
              if not dataSet.Fields[idx].IsNull then
                Result.AddPair(key, TJSONNumber.Create(BcdToDouble(dataSet.Fields[idx].AsBcd)))
              else
                Result.AddPair(key, TJSONNull.Create);
            end;
          TFieldType.ftDataSet:
            begin //nao pegar , a principio é field que já vai através do key value, não vai lookups no delta
              ; //pular, são dados apenas de visualização
              //dft := DataSetFieldToType(TDataSetField(dataSet.Fields[idx]));
              //nestedDataSet := TDataSetField(dataSet.Fields[idx]).NestedDataSet;
              //case dft of
              //  dfJSONObject:
              //    Result.AddPair(key, DataSetToJSONObject(nestedDataSet));
              //  dfJSONArray:
              //    Result.AddPair(key, DataSetToJSONArray(nestedDataSet));
              //end;
            end;
          TFieldType.ftGraphic, TFieldType.ftBlob, TFieldType.ftStream:
            begin
              ms := TMemoryStream.Create;
              try
                TBlobField(dataSet.Fields[idx]).SaveToStream(ms);
                ms.Position := 0;
                ss := TStringStream.Create;
                try
                  TNetEncoding.Base64.Encode(ms, ss);
                  Result.AddPair(key, TJSONString.Create(ss.DataString));
                finally
                  ss.Free;
                end;
              finally
                ms.Free;
              end;
            end;
        else
          raise EDataSetConverterException.CreateFmt('Cannot find type for field "%s"', [key]);
        end;
      end;
    end;
  end;

end;

function TFDDeltaConverter.DeltaToJSONArray(delta: IFDDataSetReference): TJSONArray;
var
  deltaDataSet :TFDMemTable;
  JSONObj :TJSONObject;
begin
  Result := nil;
  if (not Assigned(delta)) then Exit;

  try
    deltaDataSet := TFDMemTable.Create(nil);
    deltaDataSet.FilterChanges := [rtUnmodified, rtModified, rtInserted, rtDeleted];
    deltaDataSet.Data := delta;

    Result := TJSONArray.Create;
    deltaDataSet.First;
    while not deltaDataSet.Eof do
      begin
      if (deltaDataSet.UpdateStatus <> usUnModified) then
        begin
        JSONObj := DeltaToJSONObject(deltaDataSet);
        if JSONObj <> nil then
          Result.AddElement(JSONObj);
        end;
      deltaDataSet.Next;
      end;
  finally

      deltaDataSet.Free;
  end;


end;

function TFDDeltaConverter.DeltaToJSONObject(deltaDataSet: TFDMemTable): TJSONObject;
var
  i: Integer;
  key: string;
  timeStamp: TSQLTimeStamp;
  nestedDataSet: TDataSet;
  dft: TDataSetFieldType;
  bft: TBooleanFieldType;
  ms: TMemoryStream;
  ss: TStringStream;

begin
  Result := nil;
  if (not Assigned(deltaDataSet)) or (deltaDataSet.IsEmpty) then  Exit;
  if deltaDataSet.UpdateStatus = usUnmodified then  Exit;

  //Validação: Para ser considerado Modified, pelo menos um dos campos selecionados precisa ser diferente do Original
  if deltaDataSet.UpdateStatus = usModified then
  if not CurrentRecordHasModifiedFieldToDelta(deltaDataSet) then  Exit;

  //
  Result := TJSONObject.Create;
  if deltaDataSet.UpdateStatus = usModified then
    begin
    Result.AddPair('RecNo', TJSONNumber.Create(deltaDataSet.RecNo) );
    Result.AddPair('RowState', 'Modified');
    //Result.AddPair('Original', DataSetToJSONObjectOldValue(dataSet));
    Result.AddPair('Current', DataSetToJSONObject(deltaDataSet));
    deltaDataSet.RevertRecord;
    Result.AddPair('Original', DataSetToJSONObject(deltaDataSet));
    end
  else
  if deltaDataSet.UpdateStatus = usInserted then
    begin
    Result.AddPair('RecNo', TJSONNumber.Create(deltaDataSet.RecNo) );
    Result.AddPair('RowState', 'Inserted');
    Result.AddPair('Current', DataSetToJSONObject(deltaDataSet));
    end
  else
  if deltaDataSet.UpdateStatus = usDeleted then
    begin
    Result.AddPair('RecNo', TJSONNumber.Create(deltaDataSet.RecNo) );
    Result.AddPair('RowState', 'Deleted');
    Result.AddPair('Original', DataSetToJSONObject(deltaDataSet));
    end;


end;

destructor TFDDeltaConverter.Destroy;
begin
  fDelta := nil;
  SetLength(fFieldList, 0);
  inherited Destroy;
end;

class function TFDDeltaConverter.New: IFDDeltaConverter;
begin
  Result := TFDDeltaConverter.Create;
end;

function TFDDeltaConverter.Source(delta: IFDDataSetReference): IFDDeltaConverter;
begin
  fDelta := delta;
  Result := Self;
end;

end.