{score} = require '../src/fuzzaldrin'

describe "score(string, query)", ->
  it "returns a score", ->
    expect(score('Hello World', 'he')).toBeLessThan(score('Hello World', 'Hello'))
    expect(score('Hello World', 'Hello World')).toBe 1
    expect(score('Hello World', '')).toBe 0
    expect(score('Hello World', null)).toBe 0
    expect(score('Hello World')).toBe 0
    expect(score()).toBe 0
    expect(score(null, 'he')).toBe 0
    expect(score('', '')).toBe 0
    expect(score('', 'abc')).toBe 0
