(*
  Copyright 2025, MARS-Curiosity library

  Home: https://github.com/andrea-magni/MARS
*)
unit MARS.Core.Utils;

{$I MARS.inc}

interface

uses
  SysUtils, Classes, RTTI, SyncObjs, Math, Generics.Collections
, REST.JSON
, System.JSON
, MARS.Core.JSON
, MARS.Core.RequestAndResponse.Interfaces
;

type
  TStringCompareFunc = reference to function (const AString1, AString2: string): Boolean;
  TStringArrayHelper = record helper for TArray<string>
    function RemoveDuplicates: TArray<string>;
    function StartsWith(const AArray: TArray<string>; const AIgnoreCase: Boolean): Boolean; overload;
    function StartsWith(const AArray: TArray<string>; const ACompareFunc: TStringCompareFunc): Boolean; overload;
    function SubArray(const AStartIndex: Integer): TArray<string>; overload;
    function SubArray(const AStartIndex: Integer; const ACount: Integer): TArray<string>; overload;
    function Contains(const AString: string): Boolean;
  end;

  TFormParamFile = record
    FieldName: string;
    FileName: string;
    Bytes: TBytes;
    ContentType: string;
    procedure Clear;
    constructor CreateFromRequest(const ARequest: IMARSRequest; const AFieldName: string); overload;
    constructor CreateFromRequest(const ARequest: IMARSRequest; const AFileIndex: Integer); overload;
    constructor Create(const AFieldName: string; const AFileName: string; const ABytes: TBytes; const AContentType: string);
    function ToString: string;
  end;

  TFormParam = record
    FieldName: string;
    Value: TValue;
    function IsFile: Boolean;
    function AsFile: TFormParamFile;
    procedure Clear;
    constructor CreateFromRequest(const ARequest: IMARSRequest; const AFieldName: string); overload;
    constructor CreateFromRequest(const ARequest: IMARSRequest; const AFileIndex: Integer); overload;
    constructor Create(const AFieldName: string; const AValue: TValue);
    constructor CreateFile(const AFieldName: string; const AFileName: string; const ABytes: TBytes = nil; const AContentType: string = '');
    function ToString: string;
  end;

  TDump = class
  public
    class procedure Request(const ARequest: IMARSRequest; const AFileName: string); overload; virtual;
  end;


  function CreateCompactGuidStr: string;

  function BooleanToTJSON(AValue: Boolean): TJSONValue;

  function SmartConcat(const AArgs: array of string; const ADelimiter: string = ',';
    const AAvoidDuplicateDelimiter: Boolean = True; const ATrim: Boolean = True;
    const ACaseInsensitive: Boolean = True): string;

  function StringFallback(const AStrings: TArray<string>; const ADefault: string = ''): string;

  function EnsurePrefix(const AString, APrefix: string; const AIgnoreCase: Boolean = True): string;
  function EnsureSuffix(const AString, ASuffix: string; const AIgnoreCase: Boolean = True): string;

  function StringArrayToString(const AArray: TArray<string>; const ADelimiter: string = ','): string;

  function StreamToJSONValue(const AStream: TStream; const AEncoding: TEncoding = nil): TJSONValue;
  procedure JSONValueToStream(const AValue: TJSONValue; const ADestStream: TStream; const AEncoding: TEncoding = nil);
  function StreamToString(const AStream: TStream; const AEncoding: TEncoding = nil): string;
  procedure StringToStream(const AStream: TStream; const AString: string; const AEncoding: TEncoding = nil);
  procedure CopyStream(ASourceStream, ADestStream: TStream;
    AOverWriteDest: Boolean = True; AThenResetDestPosition: Boolean = True);

{$ifndef DelphiXE6_UP}
  function DateToISO8601(const ADate: TDateTime; AInputIsUTC: Boolean = False): string;
  function ISO8601ToDate(const AISODate: string; AReturnUTC: Boolean = False): TDateTime;
{$endif}

{$ifndef DelphiXE8_UP}
  // https://github.com/andrea-magni/MARS/issues/76#issuecomment-589954750
  function TryISO8601ToDate(const AISODate: string; out Value: TDateTime; AReturnUTC: Boolean = True): Boolean;
{$endif}

  function DateToJSON(const ADate: TDateTime): string; overload;
  function DateToJSON(const ADate: TDateTime; const AOptions: TMARSJSONSerializationOptions): string; overload;

  function JSONToDate(const ADate: string; const ADefault: TDateTime = 0.0): TDateTime; overload;
  function JSONToDate(const ADate: string; const AOptions: TMARSJSONSerializationOptions; const ADefault: TDateTime = 0.0): TDateTime; overload;

  function IsMask(const AString: string): Boolean;
  function MatchesMask(const AString, AMask: string): Boolean;

  function GuessTValueFromString(const AString: string): TValue; overload;
  function GuessTValueFromString(const AString: string; const AOptions: TMARSJSONSerializationOptions): TValue; overload;
  function TValueToString(const AValue: TValue; const ARecursion: Integer = 0): string;

  procedure ZipStream(const ASource: TStream; const ADest: TStream; const WindowBits: Integer = 15);
  procedure UnzipStream(const ASource: TStream; const ADest: TStream; const WindowBits: Integer = 15);
  function StreamToBase64(const AStream: TStream): string;
  procedure Base64ToStream(const ABase64: string; const ADestStream: TStream);

  function StreamToBytes(const ASource: TStream): TBytes;

  function GetEncodingName(const AEncoding: TEncoding): string;

implementation

uses
  TypInfo
{$ifndef DelphiXE6_UP}
  , XSBuiltIns
{$endif}
  , StrUtils, DateUtils, Masks
{$IFDEF MARS_ZLIB}, ZLib {$ENDIF}
{$IFDEF MARS_ZIP}, Zip {$ENDIF}
  , NetEncoding
;

function StringFallback(const AStrings: TArray<string>; const ADefault: string = ''): string;
var
  LIndex: Integer;
begin
  Result := '';

  for LIndex := 0 to Length(AStrings)-1 do
  begin
    Result := AStrings[LIndex];
    if Result <> '' then
      Break;
  end;

  if Result = '' then
    Result := ADefault;
end;

function GetEncodingName(const AEncoding: TEncoding): string;
begin
  Result := '';

  if AEncoding = TEncoding.ANSI then Result := 'ANSI'
  else if AEncoding = TEncoding.ASCII then Result := 'ASCII'
  else if AEncoding = TEncoding.BigEndianUnicode then Result :='BigEndianUnicode'
  else if AEncoding = TEncoding.Unicode then Result :='Unicode'
  else if AEncoding = TEncoding.UTF7 then Result :='UTF7'
  else if AEncoding = TEncoding.UTF8 then Result :='UTF8'
  else if AEncoding = TEncoding.Default then Result :='Default';
end;


function StreamToBytes(const ASource: TStream): TBytes;
begin
  SetLength(Result, ASource.Size);
  ASource.Position := 0;
  if ASource.Read(Result, ASource.Size) <> ASource.Size then
    raise Exception.Create('Unable to copy all content to TBytes');
end;


procedure ZipStream(const ASource: TStream; const ADest: TStream; const WindowBits: Integer = 15);
{$IFDEF MARS_ZLIB}
var
  LZipStream: TZCompressionStream;
{$ENDIF}
begin
{$IFDEF MARS_ZLIB}
  Assert(Assigned(ASource));
  Assert(Assigned(ADest));

  LZipStream := TZCompressionStream.Create(ADest, TZCompressionLevel.zcDefault, WindowBits);
  try
    ASource.Position := 0;
    LZipStream.CopyFrom(ASource, ASource.Size);
  finally
    LZipStream.Free;
  end;
{$ENDIF}
end;

procedure UnzipStream(const ASource: TStream; const ADest: TStream; const WindowBits: Integer = 15);
{$IFDEF MARS_ZLIB}
var
  LZipStream: TZDecompressionStream;
{$ENDIF}
begin
{$IFDEF MARS_ZLIB}
  Assert(Assigned(ASource));
  Assert(Assigned(ADest));

  LZipStream := TZDecompressionStream.Create(ASource, WindowBits);
  try
    ASource.Position := 0;
    ADest.CopyFrom(LZipStream, LZipStream.Size);
  finally
    LZipStream.Free;
  end;
{$ENDIF}
end;


function StreamToBase64(const AStream: TStream): string;
var
  LBase64Stream: TStringStream;
begin
  Assert(Assigned(AStream));

  LBase64Stream := TStringStream.Create;
  try
    AStream.Position := 0;
    TNetEncoding.Base64.Encode(AStream, LBase64Stream);
    Result := LBase64Stream.DataString;
  finally
    LBase64Stream.Free;
  end;
end;

procedure Base64ToStream(const ABase64: string; const ADestStream: TStream);
var
  LBase64Stream: TStringStream;
begin
  Assert(Assigned(ADestStream));

  LBase64Stream := TStringStream.Create(ABase64);
  try
    LBase64Stream.Position := 0;
    ADestStream.Size := 0;
    TNetEncoding.Base64.Decode(LBase64Stream, ADestStream);
  finally
    LBase64Stream.Free;
  end;
end;

function GuessTValueFromString(const AString: string): TValue;
begin
  Result := GuessTValueFromString(AString, DefaultMARSJSONSerializationOptions);
end;

function GuessTValueFromString(const AString: string; const AOptions: TMARSJSONSerializationOptions): TValue;
var
  LValueInteger, LDummy: Integer;
  LValueDouble: Double;
  LValueBool: Boolean;
  LValueInt64: Int64;
  LValueDateTime: TDateTime;
begin
  if AString = '' then
    Result := TValue.Empty
  else begin
    if Integer.TryParse(AString, LValueInteger)then
      Result := LValueInteger
    else if TryStrToInt64(AString, LValueInt64) then
      Result := LValueInt64
    else if TryStrToFloat(AString, LValueDouble) then
      Result := LValueDouble
    else if TryStrToFloat(AString, LValueDouble, TFormatSettings.Create('en')) then
      Result := LValueDouble
    else if TryStrToBool(AString, LValueBool) then
      Result := LValueBool
    else if (AString.CountChar('-') >= 2) and Integer.TryParse(AString.SubString(0, 4), LDummy)
{$IFDEF MARS_JSON_LEGACY}
      and TryISO8601ToDate(AString.DeQuotedString('"'), LValueDateTime, joDateIsUTC in AOptions)
{$ELSE}
      and TryISO8601ToDate(AString.DeQuotedString('"'), LValueDateTime, AOptions.DateIsUTC)
{$ENDIF}

    then
      Result := TValue.From<TDateTime>(LValueDateTime)
    else
      Result := AString;
  end;
end;

function TValueToString(const AValue: TValue; const ARecursion: Integer = 0): string;
var
  LIndex: Integer;
  LElement: TValue;
  LRecordType: TRttiRecordType;
  LField: TRttiField;
begin
  Result := '';

  if AValue.IsArray then
  begin
    Result := '';
    for LIndex := 0 to AValue.GetArrayLength-1 do
    begin
      LElement := AValue.GetArrayElement(LIndex);
      if Result <> '' then
        Result := Result + ', ';
      Result := Result  + TValueToString(LElement, ARecursion);
    end;
    Result := '[' + Result + ']';
  end
  else if AValue.Kind in [tkRecord{$ifdef Delphi11Alexandria_UP}, tkMRecord{$endif}] then
  begin
    LRecordType := TRttiContext.Create.GetType(AValue.TypeInfo) as TRttiRecordType;

    Result := '';
    for LField in LRecordType.GetFields do
    begin
      if Result <> '' then
        Result := Result +  ', ';
      Result := Result + LField.Name + ': ' + TValueToString( LField.GetValue(AValue.GetReferenceToRawData), ARecursion + 1 );
    end;
    Result := '(' + Result + ')';
  end
  else if (AValue.Kind in [tkString, tkUString, tkChar, {$ifdef DelphiXE7_UP}tkWideChar,{$endif} tkLString, tkWString]) then
    Result := AValue.AsString
  else if (AValue.IsType<Boolean>) then
    Result := BoolToStr(AValue.AsType<Boolean>, True)
  else if AValue.TypeInfo = TypeInfo(TDateTime) then
    Result := DateToJSON(AValue.AsType<TDateTime>)
  else if AValue.TypeInfo = TypeInfo(TDate) then
    Result := DateToJSON(AValue.AsType<TDate>)
  else if AValue.TypeInfo = TypeInfo(TTime) then
    Result := DateToJSON(AValue.AsType<TTime>)

  else if (AValue.Kind in [tkInt64]) then
    Result := IntToStr(AValue.AsType<Int64>)
  else if (AValue.Kind in [tkInteger]) then
    Result := IntToStr(AValue.AsType<Integer>)

  else if (AValue.Kind in [tkFloat]) then
    Result := FormatFloat('0.00000000', AValue.AsType<Double>)
  else
    Result := AValue.ToString;
end;

function StreamToString(const AStream: TStream; const AEncoding: TEncoding = nil): string;
var
  LBytes: TBytes;
  LEncoding: TEncoding;
begin
  Result := '';
  if not Assigned(AStream) then
    Exit;
  LEncoding := AEncoding;
  if not Assigned(LEncoding) then
    LEncoding := TEncoding.UTF8;

  AStream.Position := 0;
  SetLength(LBytes, AStream.Size);
  AStream.Read(LBytes, AStream.Size);
  Result := LEncoding.GetString(LBytes);
end;

procedure StringToStream(const AStream: TStream; const AString: string; const AEncoding: TEncoding = nil);
var
  LEncoding: TEncoding;
  LBytes: TBytes;
begin
  if not Assigned(AStream) then
    Exit;

  LEncoding := AEncoding;
  if not Assigned(LEncoding) then
    LEncoding := TEncoding.UTF8;

  LBytes := LEncoding.GetBytes(AString);
  AStream.Size := 0;
  AStream.Write(LBytes, Length(LBytes));
end;

function IsMask(const AString: string): Boolean;
begin

  Result := ContainsStr(AString, '*') // wildcard
    or ContainsStr(AString, '?') // jolly
    or (ContainsStr(AString, '[') and ContainsStr(AString, ']')); // range
end;

function MatchesMask(const AString, AMask: string): Boolean;
begin
  Result := Masks.MatchesMask(AString, AMask);
end;


function DateToJSON(const ADate: TDateTime): string;
begin
  Result := DateToJSON(ADate, DefaultMARSJSONSerializationOptions);
end;

function DateToJSON(const ADate: TDateTime; const AOptions: TMARSJSONSerializationOptions): string;
begin
  Result := '';
  if ADate <> 0 then
{$IFDEF MARS_JSON_LEGACY}
    Result := DateToISO8601(ADate, joDateIsUTC in AOptions);
{$ELSE}
    Result := DateToISO8601(ADate, AOptions.DateIsUTC);
{$ENDIF}
end;

function JSONToDate(const ADate: string; const ADefault: TDateTime = 0.0): TDateTime;
begin
  Result := JSONToDate(ADate, DefaultMARSJSONSerializationOptions, ADefault);
end;

function JSONToDate(const ADate: string; const AOptions: TMARSJSONSerializationOptions; const ADefault: TDateTime = 0.0): TDateTime;
begin
  Result := ADefault;
  if ADate<>'' then
{$IFDEF MARS_JSON_LEGACY}
    Result := ISO8601ToDate(ADate, joDateIsUTC in AOptions);
{$ELSE}
    Result := ISO8601ToDate(ADate, AOptions.DateIsUTC);
{$ENDIF}

end;

{$ifndef DelphiXE6_UP}
function DateToISO8601(const ADate: TDateTime; AInputIsUTC: Boolean = False): string;
begin
  Result := DateTimeToXMLTime(ADate, not AInputIsUTC);
end;

function ISO8601ToDate(const AISODate: string; AReturnUTC: Boolean = False): TDateTime;
begin
  Result := XMLTimeToDateTime(AISODate, AReturnUTC);
end;
{$endif}

{$ifndef DelphiXE8_UP}
// https://github.com/andrea-magni/MARS/issues/76#issuecomment-589954750
function TryISO8601ToDate(const AISODate: string; out Value: TDateTime; AReturnUTC: Boolean = True): Boolean;
begin
  Result := False;
  try
    Value := ISO8601ToDate(AISODate, AReturnUTC);
    Result := True
  except

  end;
end;
{$endif}

procedure CopyStream(ASourceStream, ADestStream: TStream;
  AOverWriteDest: Boolean = True; AThenResetDestPosition: Boolean = True);
begin
  if AOverWriteDest then
    ADestStream.Size := 0;
  ADestStream.CopyFrom(ASourceStream, 0);
  if AThenResetDestPosition then
    ADestStream.Position := 0;
end;


function StreamToJSONValue(const AStream: TStream; const AEncoding: TEncoding): TJSONValue;
var
  LEncoding: TEncoding;
  LJSONString: string;
begin
  LEncoding := AEncoding;
  if not Assigned(LEncoding) then
    LEncoding := TEncoding.UTF8;

  LJSONString := LEncoding.GetString(StreamToBytes(AStream));
  Result := TJSONObject.ParseJSONValue(LJSONString);
end;

procedure JSONValueToStream(const AValue: TJSONValue; const ADestStream: TStream; const AEncoding: TEncoding);
var
  LEncoding: TEncoding;
  LBytes: TBytes;
begin
  if not (Assigned(AValue) and Assigned(ADestStream)) then
    Exit;

  LEncoding := AEncoding;
  if not Assigned(LEncoding) then
    LEncoding := TEncoding.UTF8;

  LBytes := LEncoding.GetBytes(AValue.ToJSON);
  ADestStream.Write(LBytes, Length(LBytes));
end;

function StringArrayToString(const AArray: TArray<string>; const ADelimiter: string = ','): string;
begin
  Result := SmartConcat(AArray, ADelimiter);
end;

function EnsurePrefix(const AString, APrefix: string; const AIgnoreCase: Boolean = True): string;
begin
  Result := AString;
  if Result <> '' then
  begin
    if (AIgnoreCase and not StartsText(APrefix, Result))
      or not StartsStr(APrefix, Result) then
      Result := APrefix + Result;
  end;
end;

function EnsureSuffix(const AString, ASuffix: string; const AIgnoreCase: Boolean = True): string;
begin
  Result := AString;
  if Result <> '' then
  begin
    if (AIgnoreCase and not EndsText(ASuffix, Result))
      or not EndsStr(ASuffix, Result) then
      Result := Result + ASuffix;
  end;
end;

function StripPrefix(const APrefix, AString: string): string;
begin
  Result := AString;
  if APrefix <> '' then
    while StartsStr(APrefix, Result) do
      Result := RightStr(Result, Length(Result) - Length(APrefix));
end;

function StripSuffix(const ASuffix, AString: string): string;
begin
  Result := AString;
  if ASuffix <> '' then
    while EndsStr(ASuffix, Result) do
      Result := LeftStr(Result, Length(Result) - Length(ASuffix));
end;

function SmartConcat(const AArgs: array of string; const ADelimiter: string = ',';
  const AAvoidDuplicateDelimiter: Boolean = True; const ATrim: Boolean = True;
  const ACaseInsensitive: Boolean = True): string;
var
  LIndex: Integer;
  LValue: string;
begin
  Result := '';
  for LIndex := 0 to Length(AArgs) - 1 do
  begin
    LValue := AArgs[LIndex];
    if ATrim then
      LValue := Trim(LValue);
    if AAvoidDuplicateDelimiter then
      LValue := StripPrefix(ADelimiter, StripSuffix(ADelimiter, LValue));

    if (Result <> '') and (LValue <> '') then
      Result := Result + ADelimiter;

    Result := Result + LValue;
  end;
end;

function BooleanToTJSON(AValue: Boolean): TJSONValue;
begin
  if AValue then
    Result := TJSONTrue.Create
  else
    Result := TJSONFalse.Create;
end;

function CreateCompactGuidStr: string;
var
  LIndex: Integer;
  LBytes: TBytes;
begin
  Result := '';
  LBytes := TGUID.NewGuid.ToByteArray();
  for LIndex := 0 to Length(LBytes)-1 do
    Result := Result + IntToHex(LBytes[LIndex], 2);
end;

{ TFormParamFile }

procedure TFormParamFile.Clear;
begin
  FieldName := '';
  FileName := '';
  Bytes := [];
  ContentType := '';
end;

constructor TFormParamFile.CreateFromRequest(const ARequest: IMARSRequest; const AFieldName: string);
begin
  CreateFromRequest(ARequest, ARequest.GetFormFileParamIndex(AFieldName));
end;

constructor TFormParamFile.Create(const AFieldName, AFileName: string;
  const ABytes: TBytes; const AContentType: string);
begin
  FieldName := AFieldName;
  FileName := AFileName;
  Bytes := ABytes;
  ContentType := AContentType;
end;

constructor TFormParamFile.CreateFromRequest(const ARequest: IMARSRequest;
  const AFileIndex: Integer);
var
  LFieldName, LFileName, LContentType: string;
  LBytes: TBytes;
begin
  if ARequest.GetFormFileParam(AFileIndex, LFieldName, LFileName, LBytes, LContentType) then
    Create(LFieldName, LFileName, LBytes, LContentType)
  else
    raise Exception.CreateFmt('Unable to extract data for file form param index %d', [AFileIndex]);
end;

function TFormParamFile.ToString: string;
begin
  Result := FieldName + '=' + SmartConcat([FileName, ContentType, Length(Bytes).ToString + ' bytes']);
end;

{ TFormParam }

function TFormParam.AsFile: TFormParamFile;
begin
  Result := Value.AsType<TFormParamFile>;
end;

procedure TFormParam.Clear;
begin
  FieldName := '';
  Value := TValue.Empty;
end;

constructor TFormParam.Create(const AFieldName: string; const AValue: TValue);
begin
  Clear;
  FieldName := AFieldName;
  Value := AValue;
end;

constructor TFormParam.CreateFile(const AFieldName, AFileName: string;
  const ABytes: TBytes; const AContentType: string);
begin
  Create(AFieldName
  , TValue.From<TFormParamFile>(
      TFormParamFile.Create(AFieldName, AFileName, ABytes, AContentType)
    )
  );
end;

constructor TFormParam.CreateFromRequest(const ARequest: IMARSRequest;
  const AFileIndex: Integer);
var
  LValue: TFormParamFile;
begin
  Clear;
  LValue := TFormParamFile.CreateFromRequest(ARequest, AFileIndex);
  Value := TValue.From<TFormParamFile>(LValue);
  FieldName := LValue.FieldName;
end;

constructor TFormParam.CreateFromRequest(const ARequest: IMARSRequest;
  const AFieldName: string);
var
  LIndex: Integer;
begin
  Clear;
  LIndex := ARequest.GetFormParamIndex(AFieldName);
  if LIndex <> -1 then
  begin
    FieldName := AFieldName;
    Value := ARequest.GetFormParamValue(LIndex);
  end
  else
  begin
    FieldName := AFieldName;
    Value := TValue.From<TFormParamFile>(
      TFormParamFile.CreateFromRequest(ARequest, AFieldName)
    );
  end;
end;

function TFormParam.IsFile: Boolean;
begin
  Result := Value.IsType<TFormParamFile>;
end;

function TFormParam.ToString: string;
begin
  if IsFile then
    Result := AsFile.ToString
  else
    Result := FieldName + '=' + Value.ToString;
end;

{ TDump }

class procedure TDump.Request(const ARequest: IMARSRequest;
  const AFileName: string);
var
  LSS: TStringStream;
  LHeaders: string;
  LRawString: string;
  {$ifdef Delphi10Berlin_UP}
  LBytesStream: TBytesStream;
  {$endif}
begin
  try
    try
      LRawString := 'Content: ' + ARequest.Content;
    except
      {$IFDEF Delphi10Berlin_UP}
      try
        LRawString := TEncoding.UTF8.GetString(ARequest.RawContent);
      except
        try
          LBytesStream := TBytesStream.Create(ARequest.RawContent);
          try
            LRawString := StreamToString(LBytesStream);
          finally
            LBytesStream.Free;
          end;
        except
          LRawString := 'Unable to read content: ' + Length(ARequest.RawContent).ToString + ' bytes';
        end;
      end;
      {$ELSE}
      LRawString := ARequest.RawContent;
      {$ENDIF}
    end;

    LHeaders := string.join(sLineBreak, [
      'RawPath: ' + ARequest.RawPath
    , 'Method: ' + ARequest.Method
    , 'Authorization: ' + ARequest.Authorization
    , 'Accept: ' + ARequest.Accept

//    , 'ContentFields: ' + ARequest.ContentFields.CommaText
//    , 'CookieFields: ' + ARequest.CookieFields.CommaText
//    , 'QueryFields: ' + ARequest.QueryFields.CommaText

//    , 'ContentType: ' + ARequest.ContentType
//    , 'ContentEncoding: ' + ARequest.ContentEncoding
//    , 'ContentLength: ' + ARequest.ContentLength.ToString
//    , 'ContentVersion: ' + ARequest.ContentVersion

//    , 'RemoteAddr: ' + ARequest.RemoteAddr
//    , 'RemoteHost: ' + ARequest.RemoteHost
//    , 'RemoteIP: ' + ARequest.RemoteIP
    ]);

    LSS := TStringStream.Create(LHeaders + sLineBreak + sLineBreak + LRawString);
    try
      LSS.SaveToFile(AFileName);
    finally
      LSS.Free;
    end;
  except on E:Exception do
    begin
      LSS := TStringStream.Create('Error: ' + E.ToString);
      try
        LSS.SaveToFile(AFileName);
      finally
        LSS.Free;
      end;
    end;
    // no exceptions allowed outside here
  end;
end;

{ TStringArrayHelper }

function TStringArrayHelper.RemoveDuplicates: TArray<string>;
var
  LStringList: TStringList;
begin
  LStringList := TStringList.Create;
  try
    LStringList.Sorted := True;
    LStringList.Duplicates := dupIgnore;
    LStringList.AddStrings(Self);
    Result := LStringList.ToStringArray;
  finally
    LStringList.Free;
  end;
end;

function TStringArrayHelper.StartsWith(const AArray: TArray<string>; const AIgnoreCase: Boolean): Boolean;
var
  LCompareFunc: TStringCompareFunc;
begin
  if Length(Self) < Length(AArray) then
    Exit(False);

  LCompareFunc := nil;
  if AIgnoreCase then
    LCompareFunc := function (const AString1, AString2: string): Boolean
    begin
      Result := SameText(AString1, AString2); // case insensitive
    end
  else
    LCompareFunc := function (const AString1, AString2: string): Boolean
    begin
      Result := AString1 = AString2; // case sensitive
    end;

  Result := StartsWith(AArray, LCompareFunc);
end;

function TStringArrayHelper.StartsWith(const AArray: TArray<string>;
  const ACompareFunc: TStringCompareFunc): Boolean;
var
  LCommonLength, LIndex: Integer;
begin
  Result := True;

  if Length(Self) < Length(AArray) then
  begin
    Result := False;
    Exit;
  end;

  LCommonLength := Min(Length(Self), Length(AArray));
  for LIndex := 0 to LCommonLength-1 do
  begin
    if not ACompareFunc(Self[LIndex], AArray[LIndex]) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function TStringArrayHelper.SubArray(const AStartIndex: Integer): TArray<string>;
begin
  Result := Copy(Self, AStartIndex, MAXINT);
end;

function TStringArrayHelper.SubArray(const AStartIndex: Integer; const ACount: Integer): TArray<string>;
begin
  Result := Copy(Self, AStartIndex, ACount);
end;

function TStringArrayHelper.Contains(const AString: string): Boolean;
{$ifndef Delphi12Athens_UP}
var
  LIndex: Integer;
{$endif}
begin
  {$ifdef Delphi12Athens_UP}
  Result := TArray.Contains<string>(Self, AString);
  {$else}
  for LIndex := Low(Self) to High(Self) do
    if AString = Self[LIndex] then
      Exit(True);
  Result := False;
  {$endif}
end;

end.
