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
    expect(match(path.join('X', 'Y'), path.join('X', 'Y')).toEqual [0..2]
    expect(match(path.join('X', 'X-x'), 'X')).toEqual [0, 2]
    expect(match(path.join('X', 'Y'), 'XY')).toEqual [0, 2]
    expect(match(path.join('-', 'X'), 'X')).toEqual [2]
    expect(match(path.join('X-', '-'), "X#{path.sep}")).toEqual [0, 2]

  it "double matches characters in the path and the base", ->
    expect(match(path.join('XY', 'XY'), 'XY')).toEqual [0, 1, 3, 4]
    expect(match(path.join('--X-Y-', '-X--Y'), 'XY')).toEqual [2, 4, 8, 11]
