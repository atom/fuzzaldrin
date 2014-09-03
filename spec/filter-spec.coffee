{filter} = require '../src/fuzzaldrin'

bestMatch = (candidates, query) ->
  filter(candidates, query, maxResults: 1)[0]

describe "filtering", ->
  it "returns an array of the most accurate results", ->
    candidates = ['Gruntfile','filter', 'bile', null, '', undefined]
    expect(filter(candidates, 'file')).toEqual ['filter', 'Gruntfile']

  describe "when the maxResults option is set", ->
    it "limits the results to the result size", ->
      candidates = ['Gruntfile', 'filter', 'bile']
      expect(bestMatch(candidates, 'file')).toBe 'filter'

  describe "when the entries contains slashes", ->
    it "weighs basename matches higher", ->
      candidates = ['/bar/foo', '/foo/bar']
      expect(bestMatch(candidates, 'bar')).toBe '/foo/bar'

      candidates = ['/bar/foo', '/foo/bar/////////']
      expect(bestMatch(candidates, 'bar')).toBe '/foo/bar/////////'

      candidates = ['/bar/foo', '/foo/bar', 'bar']
      expect(bestMatch(candidates, 'bar')).toEqual 'bar'

      candidates = ['/bar/foo', '/foo/bar', '/bar']
      expect(bestMatch(candidates, 'bar')).toBe '/bar'

      candidates = ['/bar/foo', 'bar/////////']
      expect(bestMatch(candidates, 'bar')).toBe 'bar/////////'

      expect(bestMatch(['f/o/1_a_z', 'f/o/a_z'], 'az')).toBe 'f/o/a_z'
      expect(bestMatch(['f/1_a_z', 'f/o/a_z'], 'az')).toBe 'f/o/a_z'

  describe "when the candidate is all slashes", ->
    it "does not throw an exception", ->
      candidates = ['/']
      expect(filter(candidates, 'bar', maxResults: 1)).toEqual []

  describe "when the entries contains spaces", ->
    it "treats spaces as slashes", ->
      candidates = ['/bar/foo', '/foo/bar']
      expect(bestMatch(candidates, 'br f')).toBe '/bar/foo'

    it "weighs basename matches higher", ->
      candidates = ['/bar/foo', '/foo/bar foo']
      expect(bestMatch(candidates, 'br f')).toBe '/foo/bar foo'

      candidates = ['/barfoo/foo', '/foo/barfoo']
      expect(bestMatch(candidates, 'br f')).toBe '/foo/barfoo'

      candidates = ['lib/exportable.rb', 'app/models/table.rb']
      expect(bestMatch(candidates, 'table')).toBe 'app/models/table.rb'

  describe "when the entries contains mixed case", ->
    it "weighs exact case matches higher", ->
      candidates = ['statusurl', 'StatusUrl']
      expect(bestMatch(candidates, 'Status')).toBe 'StatusUrl'
      expect(bestMatch(candidates, 'SU')).toBe 'StatusUrl'
      expect(bestMatch(candidates, 'status')).toBe 'statusurl'
      expect(bestMatch(candidates, 'su')).toBe 'statusurl'
      expect(bestMatch(candidates, 'statusurl')).toBe 'statusurl'
      expect(bestMatch(candidates, 'StatusUrl')).toBe 'StatusUrl'

  it "weighs abbreviation matches after spaces, underscores, and dashes the same", ->
    expect(bestMatch(['sub-zero', 'sub zero', 'sub_zero'], 'sz')).toBe 'sub-zero'
    expect(bestMatch(['sub zero', 'sub_zero', 'sub-zero'], 'sz')).toBe 'sub zero'
    expect(bestMatch(['sub_zero', 'sub-zero', 'sub zero'], 'sz')).toBe 'sub_zero'

  it "weighs matches at the start of the string or base name higher", ->
    expect(bestMatch(['a_b_c', 'a_b'], 'ab')).toBe 'a_b'
    expect(bestMatch(['z_a_b', 'a_b'], 'ab')).toBe 'a_b'
    expect(bestMatch(['a_b_c', 'c_a_b'], 'ab')).toBe 'a_b_c'

  describe "when the entries are of differing directory depths", ->
    it "places exact matches first, even if they're deeper", ->
      candidates = ['app/models/automotive/car.rb', 'spec/factories/cars.rb']
      expect(bestMatch(candidates, 'car.rb')).toBe 'app/models/automotive/car.rb'
