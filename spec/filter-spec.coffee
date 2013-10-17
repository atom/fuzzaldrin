filter = require '../src/filter'

describe "filtering", ->
  it "returns an array of the most accurate results", ->
    candidates = ['Gruntfile','filter', 'bile']
    expect(filter(candidates, 'file')).toEqual ['filter', 'Gruntfile']

  describe "when the maxResults option is set", ->
    it "limits the results to the result size", ->
      candidates = ['Gruntfile','filter', 'bile']
      expect(filter(candidates, 'file', maxResults: 1)).toEqual ['filter']
