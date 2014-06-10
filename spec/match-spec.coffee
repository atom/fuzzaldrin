{match} = require '../src/fuzzaldrin'

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
    expect(match('X/Y', 'X/Y')).toEqual [0..2]
    expect(match('X/X-x', 'X')).toEqual [0, 2]
    expect(match('X/Y', 'XY')).toEqual [0, 2]
    expect(match('-/X', 'X')).toEqual [2]
    expect(match('X-/-', 'X/')).toEqual [0, 2]

  it "double matches characters in the path and the base", ->

    expect(match('XY/XY', 'XY')).toEqual [0, 1, 3, 4]
    expect(match('--X-Y-/-X--Y', 'XY')).toEqual [2, 4, 8, 11]
