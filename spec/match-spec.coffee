{match} = require '../src/fuzzaldrin'

describe "match(string, query)", ->
  it "returns an array of matched and unmatched strings", ->
    expect(match('Hello World', 'he')).toEqual ['', 'He', 'llo World']
    expect(match()).toEqual ['']
    expect(match('Hello World', 'wor')).toEqual ['Hello ', 'Wor', 'ld']

    expect(match('Hello World', 'd')).toEqual ['Hello Worl', 'd', '']
    expect(match('Hello World', 'elwor')).toEqual ['H', 'el', 'lo ', 'Wor', 'ld']
    expect(match('Hello World', '')).toEqual ['Hello World']
    expect(match(null, 'he')).toEqual ['']
    expect(match('', '')).toEqual ['']
    expect(match('', 'abc')).toEqual ['']
