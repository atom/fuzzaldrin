{match} = require '../src/fuzzaldrin'
path = require 'path'

describe "match(string, query)", ->

  it "returns an array of matched and unmatched strings", ->
    expect(match('Hello World', 'he')).toEqual [0, 1]
    expect(match()).toEqual []
    expect(match('Hello World', 'wor')).toEqual [6..8]

    expect(match('Hello World', 'd')).toEqual [10]
    expect(match('Hello World', 'elwor')).toEqual [1, 2, 6, 7, 8]
    expect(match('Hello World', 'er')).toEqual [1, 8]
    expect(match('Hello World', '')).toEqual []
    expect(match(null, 'he')).toEqual []
    expect(match('', '')).toEqual []
    expect(match('', 'abc')).toEqual []

  it "matches paths with slashes", ->
    expect(match(path.join('X', 'Y'), path.join('X', 'Y'))).toEqual [0..2]
    expect(match(path.join('X', 'X-x'), 'X')).toEqual [0, 2]
    expect(match(path.join('X', 'Y'), 'XY')).toEqual [0, 2]
    expect(match(path.join('-', 'X'), 'X')).toEqual [2]
    expect(match(path.join('X-', '-'), "X#{path.sep}")).toEqual [0, 2]

  it "double matches characters in the path and the base", ->
    expect(match(path.join('XY', 'XY'), 'XY')).toEqual [0, 1, 3, 4]
    expect(match(path.join('--X-Y-', '-X--Y'), 'XY')).toEqual [2, 4, 8, 11]

  it "prefer whole word to scattered letters", ->
    expect(match('fiddle gruntfile filler', 'file')).toEqual [ 12, 13, 14,15]
    expect(match('fiddle file', 'file')).toEqual [ 7, 8, 9, 10]
    expect(match('find le file', 'file')).toEqual [ 8, 9, 10, 11]

  it "prefer whole word to scattered letters, even without exact matches", ->
    expect(match('fiddle gruntfile xfiller', 'filex')).toEqual [ 12, 13, 14,15, 17]
    expect(match('fiddle file xfiller', 'filex')).toEqual [ 7, 8, 9, 10, 12]
    expect(match('find le file xfiller', 'filex')).toEqual [ 8, 9, 10, 11, 13]

  it "prefer exact match", ->
    expect(match('filter gruntfile filler', 'file')).toEqual [ 12, 13, 14, 15]

  it "prefer case sensitive exact match", ->
    expect(match('ccc CCC cCc CcC CCc', 'ccc')).toEqual [ 0, 1, 2]
    expect(match('ccc CCC cCc CcC CCc', 'CCC')).toEqual [ 4, 5, 6]
    expect(match('ccc CCC cCc CcC CCc', 'cCc')).toEqual [ 8, 9, 10]
    expect(match('ccc CCC cCc CcC CCc', 'CcC')).toEqual [ 12, 13, 14]
    expect(match('ccc CCC cCc CcC CCc', 'CCc')).toEqual [ 16, 17, 18]

  it "prefer camelCase to scattered letters", ->
    expect(match('ImportanceTableCtrl', 'itc')).toEqual [0,10,15]

  it "prefer acronym to scattered letters", ->
    expect(match('action_config', 'acon')).toEqual [ 0, 7, 8, 9]
    expect(match('application_control', 'acon')).toEqual [ 0, 12, 13, 14]

  it "account for case in selecting camelCase vs consecutive", ->
    expect(match('0xACACAC: CamelControlClass.accc', 'CCC')).toEqual [ 10, 15, 22]
    expect(match('0xACACAC: CamelControlClass.accc', 'ccc')).toEqual [ 29, 30, 31]
    expect(match('0xACACAC: CamelControlClass.accc xfiller', 'cccx')).toEqual [ 29, 30, 31, 33]

    expect(match('0xACACAC: CamelControlClass', 'ccc')).toEqual [ 10, 15, 22]
    expect(match('0xACACAC: CamelControlClass', 'CCC')).toEqual [ 10, 15, 22]






