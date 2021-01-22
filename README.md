DataSet Converter For Delphi
=================================

The DataSetConverter4D it is an API to convert JSON objects for DataSet's and also doing  reverse process, ie, converting DataSet's in JSON.

Works with the TDataSet, and TJSONObject TJSONArray classes.

To use this API you must add the "DataSetConverter4D\src" Path in your Delphi or on your project.

Supported TFieldTypes
========================

	ftBoolean
	ftInteger, ftSmallint, ftShortint, ftLargeint
	ftLongWord, ftAutoInc
	ftSingle, ftFloat
	ftString, ftWideString, ftMemo, ftWideMemo
	ftDate, ftTimeStamp, ftDateTime, ftTime
	ftCurrency
	ftFMTBcd, TFieldType.ftBCD
	ftGraphic, ftBlob, ftStream (bytes are inside JSON as plain text formated Base64)
	

Convert DataSet to JSON
========================

First you must have your DataSet and its Fields created.

    uses 
      DataSetConverter4D, 
      DataSetConverter4D.Impl;    

	var
	  ja: TJSONArray;
	  jo: TJSONObject;
	begin
	  fCdsCustomers.DataSetField := nil;
	  fCdsCustomers.CreateDataSet;
	
	  fCdsCustomers.Append;
	  fCdsCustomers.FieldByName('Id').AsInteger := 1;
	  fCdsCustomers.FieldByName('Name').AsString := 'Customers 1';
	  fCdsCustomers.FieldByName('Birth').AsDateTime := StrToDateTime('22/01/2014 14:05:03');
	  fCdsCustomers.Post;
	
	  fCdsCustomers.Append;
	  fCdsCustomers.FieldByName('Id').AsInteger := 2;
	  fCdsCustomers.FieldByName('Name').AsString := 'Customers 2';
	  fCdsCustomers.FieldByName('Birth').AsDateTime := StrToDateTime('22/01/2014 14:05:03');
	  fCdsCustomers.Post;

      //Convert all records	
	  ja := TConverter.New.DataSet(fCdsCustomers).AsJSONArray;
	  
      //Convert current record
      jo := TConverter.New.DataSet.Source(fCdsCustomers).AsJSONObject;
	
	  ja.Free;
	  jo.Free;
	end;
    
How to choose the fields from DataSet to convert to JSON
========================================================

Fields with Visible property false, aren't converted and
If informed array of string with field names, only these are converted.

	var
	  listFields :array of string;
	  ja: TJSONArray;
	  jo: TJSONObject;
	begin
	  SetLength(listFields, 2);
      listFields[0] := 'Id';
      listFields[1] := 'Name';

      //Convert all records	
	  ja := TConverter.New.DataSet(fMemTableCustomers).AsJSONArray(listFields);
	  
      //Convert current record
      jo := TConverter.New.DataSet.Source(fMemTableCustomers).AsJSONObject(listFields);
	  
	  ja.Free;
	  jo.Free;
	end;

Convert DataSet.Delta to JSON
=============================

At the moment, supported only FDDMemTable or TFDQuery.
Only Modified, Inserted ou Deleted records are converted.

	var
	  listFields :array of string;
	  jaDelta: TJSONArray;
	begin
	  SetLength(listFields, 3);
      listFields[0] := 'Id';
      listFields[1] := 'Name';
	  listFields[2] := 'Birth'	  
	  
      //Convert all records from Delta	
	  jaDelta := TConverter.New.Delta(fMemTableCustomers.Delta).AsJSONArray(listFields);	  
  
	  jaDelta.Free;
	end;
	
	
Convert JSON to DataSet
=======================

First you must have your DataSet and its Fields created.
    
	uses 
      DataSetConverter4D, 
      DataSetConverter4D.Impl;  

	JSON_ARRAY =
			[{
				"Id": 1,
				"Name": "Customers 1",
				"Birth": "2014-01-22 14:05:03"
			}, {
				"Id": 2,
				"Name": "Customers 2",
				"Birth": "2014-01-22 14:05:03"
			}]      
				  
    JSON_OBJECT =
			{
				"Id": 2,
				"Name": "Customers 2",
				"Birth": "2014-01-22 14:05:03"
			}
	var
	  ja: TJSONArray;
	  jo: TJSONObject;
	begin
	
	  ja := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(JSON_ARRAY), 0) as TJSONArray;
	  jo := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(JSON_OBJECT), 0) as TJSONObject;
	
	  //Convert one record
      TConverter.New.JSON(jo).ToDataSet(fMemTableCustomers);
	
	  fCdsCustomers.EmptyDataSet;
	
      //Convert all records
	  TConverter.New.JSON.Source(ja).ToDataSet(fMemTableCustomers);
	
	  ja.Free;
	  jo.Free;
	end;
	
Convert JSON Delta to DataSet
=============================

At the moment supported TFDQuery, TFDMemTable, TFDDataSet.
First you must have your DataSet and its Fields created.

This is the Default Delta Layout for DataSetConverter4D

	JSON_ARRAY =
			[{  "RowState": "Modified",
			    "Current": { 
				"Id": 1,
				"Name": "Customer Modified",
				"Birth": "2015-05-21 14:05:03"
				},
			    "Original": { 
				"Id": 1,
				"Name": "Customer 1",
				"Birth": "2015-05-21 14:05:03"
				}
			}, 
			{   "RowState": "Inserted",
			    "Current": { 
				"Id": 2,
				"Name": "Customers 2",
				"Birth": "2014-01-22 14:05:03"
				}
			},
			{   "RowState": "Deleted",
			    "Original": { 
				"Id": 3,
				"Name": "Customer 3",
				"Birth": "2014-01-22 14:05:03"
				}

			}]      
			
	var
	  jaDelta: TJSONArray;
	begin
	
	  jaDelta := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(JSON_ARRAY), 0) as TJSONArray;
	
      TConverter.New.JSON(jaDelta).ToDeltaDataSet(fMemTableCustomers);
	  	
	  jaDelta.Free;
	  
	end;	
	
	

Using DataSetConverter4D
============================

Using this library will is very simple, you simply add the Search Path of your IDE or your project the following directories:

- DataSetConverter4Delphi\src\

Analyze the unit tests they will assist you.