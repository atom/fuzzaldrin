filter = require '../src/filter'

describe "filtering", ->
  it "returns an array of the most accurate results", ->
    candidates = ['Gruntfile','filter', 'bile', null, '', undefined]
    expect(filter(candidates, 'file')).toEqual ['filter', 'Gruntfile']

  describe "when the maxResults option is set", ->
    it "limits the results to the result size", ->
      candidates = ['Gruntfile','filter', 'bile']
      expect(filter(candidates, 'file', maxResults: 1)).toEqual ['filter']

  describe "when the entries contains slashes", ->
    it "weighs basename matches higher", ->
      candidates = ['/bar/foo', '/foo/bar']
      expect(filter(candidates, 'bar', maxResults: 1)).toEqual ['/foo/bar']

      candidates = ['/bar/foo', '/foo/bar/////////']
      expect(filter(candidates, 'bar', maxResults: 1)).toEqual ['/foo/bar/////////']

      candidates = ['/bar/foo', '/foo/bar', 'bar']
      expect(filter(candidates, 'bar', maxResults: 1)).toEqual ['bar']

      candidates = ['/bar/foo', '/foo/bar', '/bar']
      expect(filter(candidates, 'bar', maxResults: 1)).toEqual ['/bar']

      candidates = ['/bar/foo', 'bar/////////']
      expect(filter(candidates, 'bar', maxResults: 1)).toEqual ['bar/////////']

  describe "when the candidate is all slashes", ->
    it "does not throw an exception", ->
      candidates = ['/']
      expect(filter(candidates, 'bar', maxResults: 1)).toEqual []

  describe "when the entries contains spaces", ->
    it "treats spaces as slashes", ->
      candidates = ['/bar/foo', '/foo/bar']
      expect(filter(candidates, 'br f', maxResults: 1)).toEqual ['/bar/foo']

    it "weighs basename matches higher", ->
      candidates = ['/bar/foo', '/foo/bar foo']
      expect(filter(candidates, 'br f', maxResults: 1)).toEqual ['/foo/bar foo']

      candidates = ['/barfoo/foo', '/foo/barfoo']
      expect(filter(candidates, 'br f', maxResults: 1)).toEqual ['/foo/barfoo']

      candidates = ['lib/exportable.rb', 'app/models/table.rb']
      expect(filter(candidates, 'table', maxResults: 1)[0]).toBe 'app/models/table.rb'

  describe "when the entries contains mixed case", ->
    it "weighs exact case matches higher", ->
      candidates = ['status_url', 'StatusUrl']
      expect(filter(candidates, 'Status', maxResults: 1)).toEqual ['StatusUrl']
      expect(filter(candidates, 'status', maxResults: 1)).toEqual ['status_url']
      expect(filter(candidates, 'status_url', maxResults: 1)).toEqual ['status_url']
