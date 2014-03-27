filter = require '../src/filter'

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
      candidates = ['status_url', 'StatusUrl']
      expect(bestMatch(candidates, 'Status')).toBe 'StatusUrl'
      expect(bestMatch(candidates, 'status')).toBe 'status_url'
      expect(bestMatch(candidates, 'status_url')).toBe 'status_url'
